<#
.SYNOPSIS
    WinTune — Modular Windows 11 tuning engine.
.DESCRIPTION
    Audit, apply, and revert Windows 11 optimization profiles.
    See docs/cli-spec.md for full parameter documentation.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Audit', 'Apply', 'Revert', 'List')]
    [string]$Action,

    [Parameter()]
    [string]$Profile,

    [Parameter()]
    [switch]$WhatIf,

    [Parameter()]
    [switch]$Confirm,

    [Parameter()]
    [switch]$Dangerous,

    [Parameter()]
    [switch]$StopOnError,

    [Parameter()]
    [string]$Session,

    [Parameter()]
    [string]$BackupPath,

    [Parameter()]
    [string]$OutputDir,

    [Parameter()]
    [switch]$OutputJson
)

# -- Module loading (dot-source) --
$script:ModuleRoot = Join-Path $PSScriptRoot "modules"
if (Test-Path $ModuleRoot) {
    Get-ChildItem "$ModuleRoot/*.ps1" -ErrorAction SilentlyContinue |
        ForEach-Object { . $_.FullName }
}

# -- Defaults --
if (-not $BackupPath) {
    $BackupPath = if ($env:WINTUNE_BACKUP_PATH) {
        $env:WINTUNE_BACKUP_PATH
    } else {
        Join-Path $env:LOCALAPPDATA "WinTune" "backups"
    }
}

if (-not $OutputDir) {
    $OutputDir = if ($env:WINTUNE_OUTPUT_DIR) {
        $env:WINTUNE_OUTPUT_DIR
    } else {
        Join-Path (Get-Location) "reports"
    }
}

# -- Pre-flight checks --

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ExecutionPolicy {
    $current = Get-ExecutionPolicy -Scope CurrentUser
    $restrictedPolicies = @('Restricted', 'AllSigned')
    if ($current -in $restrictedPolicies) {
        Write-Warning "ExecutionPolicy is '$current' — some scripts may not run."
        Write-Warning "Recommended: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
        return $false
    }
    return $true
}

function Get-WindowsBuild {
    [Environment]::OSVersion.Version.Build
}

if (-not (Test-Admin)) {
    $msg = "Administrator rights required. Please run PowerShell as Administrator."
    if ($OutputJson) {
        Write-Output (ConvertTo-Json @{ success=$false; error=$msg })
    } else {
        Write-Error $msg
    }
    exit 1
}

$null = Test-ExecutionPolicy
$script:WindowsBuild = Get-WindowsBuild

# -- Helper: shared audit logic --

function Get-AuditData {
    param([string]$ProfileName)

    Write-Progress -Activity "WinTune" -Status "Loading profile..." -PercentComplete 5
    $profile = Get-Profile -Name $ProfileName

    Write-Progress -Activity "WinTune" -Status "Scanning system..." -PercentComplete 20
    $snapshot = Invoke-Scanner

    $bloatDbPath = Join-Path $PSScriptRoot "data" "bloat-database.json"
    $bloatDb = Get-Content $bloatDbPath -Raw | ConvertFrom-Json

    Write-Progress -Activity "WinTune" -Status "Calculating score..." -PercentComplete 80
    $score = Get-Score -Snapshot $snapshot -TweakIds $profile.Tweaks -BloatDatabase $bloatDb

    Write-Progress -Activity "WinTune" -Status "Done" -PercentComplete 100 -Completed

    return @{
        Profile  = $profile
        Snapshot = $snapshot
        Score    = $score
        BloatDb  = $bloatDb
    }
}

# -- Action dispatch --

switch ($Action) {
    'List' {
        $profiles = Get-AvailableProfiles
        if ($OutputJson) {
            Write-Output ($profiles | ConvertTo-Json)
        } elseif ($profiles) {
            $profiles | Format-Table -AutoSize
        }
        exit 0
    }

    'Audit' {
        if (-not $Profile) { Write-Error "-Profile is required."; exit 1 }

        $data = Get-AuditData -ProfileName $Profile

        if ($OutputJson) {
            $result = [PSCustomObject]@{
                Action   = 'Audit'
                Profile  = $data.Profile
                Snapshot = $data.Snapshot
                Score    = $data.Score
            }
            Write-Output ($result | ConvertTo-Json -Depth 10)
        } else {
            Out-ConsoleReport -Score $data.Score -Snapshot $data.Snapshot -Profile $data.Profile
        }

        # Save report
        if ($OutputDir) {
            if (-not (Test-Path $OutputDir)) { $null = New-Item $OutputDir -ItemType Directory -Force }
            $htmlPath = Join-Path $OutputDir "audit-$Profile-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            $null = Out-HtmlReport -Score $data.Score -Snapshot $data.Snapshot -Profile $data.Profile -OutputPath $htmlPath
        }

        exit 0
    }

    'Apply' {
        if (-not $Profile) { Write-Error "-Profile is required."; exit 1 }

        if ($OutputJson) {
            $WhatIf = $false
            $Confirm = $false
        }

        $data = Get-AuditData -ProfileName $Profile

        if ($WhatIf) {
            if ($OutputJson) {
                $result = [PSCustomObject]@{
                    Action   = 'WhatIf'
                    Profile  = $data.Profile
                    Score    = $data.Score
                }
                Write-Output ($result | ConvertTo-Json -Depth 10)
            } else {
                Write-Host "`n[WhatIf] Profile '$Profile' would clean $($data.Score.Present) remaining items."
                Write-Host "[WhatIf] Score would improve from $($data.Score.Score)% to 100%."
            }
            exit 0
        }

        Write-Progress -Activity "WinTune" -Status "Applying tweaks..." -PercentComplete 50
        $engineResult = Invoke-TweaksEngine -ProfileName $Profile -Snapshot $data.Snapshot `
            -WhatIf:$WhatIf -Confirm:$Confirm -Dangerous:$Dangerous -StopOnError:$StopOnError `
            -BackupPathOverride $BackupPath

        # Recalculate score after changes
        Write-Progress -Activity "WinTune" -Status "Finalizing..." -PercentComplete 90
        $finalSnapshot = Invoke-Scanner
        $finalScore = Get-Score -Snapshot $finalSnapshot -TweakIds $data.Profile.Tweaks -BloatDatabase $data.BloatDb

        if ($OutputJson) {
            $result = [PSCustomObject]@{
                Action   = 'Apply'
                Profile  = $data.Profile
                Score    = $finalScore
                Changes  = $engineResult.Changes
                Backup   = $engineResult.Backup
            }
            Write-Output ($result | ConvertTo-Json -Depth 10)
        } else {
            Out-ConsoleReport -Score $finalScore -Snapshot $finalSnapshot -Profile $data.Profile -Changes $engineResult.Changes
            if ($engineResult.Backup) {
                Write-Host "Backup saved to: $($engineResult.Backup.BackupDir)"
            }
        }

        # Save report
        if ($OutputDir) {
            if (-not (Test-Path $OutputDir)) { $null = New-Item $OutputDir -ItemType Directory -Force }
            $htmlPath = Join-Path $OutputDir "apply-$Profile-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            $null = Out-HtmlReport -Score $finalScore -Snapshot $finalSnapshot -Profile $data.Profile `
                -Changes $engineResult.Changes -OutputPath $htmlPath
        }

        exit 0
    }

    'Revert' {
        if (-not $Session) { Write-Error "-Session is required for Revert action."; exit 1 }

        if ($OutputJson) {
            $Confirm = $false
        }

        if (-not $Confirm -and -not $OutputJson) {
            Write-Host "Revert session '$Session'? This will undo all changes from that session."
            $reply = Read-Host "Type 'yes' to confirm"
            if ($reply -ne 'yes') { Write-Host "Canceled."; exit 0 }
        }

        $results = Restore-Backup -Session $Session -BackupPathOverride $BackupPath

        if ($OutputJson) {
            Write-Output (ConvertTo-Json @{ Action='Revert'; Session=$Session; Results=$results })
        } else {
            $ok = ($results | Where-Object { $_.Reverted }).Count
            $fail = ($results | Where-Object { -not $_.Reverted }).Count
            Write-Host "Revert complete: $ok succeeded, $fail failed."
            foreach ($r in $results) {
                $icon = if ($r.Reverted) { "✓" } else { "✗" }
                Write-Host "  $icon $($r.Name)"
                if ($r.Error) { Write-Host "     Error: $($r.Error)" }
            }
        }

        exit 0
    }
}
