<#
.SYNOPSIS
    WinTune - Modular Windows 11 tuning engine.
.DESCRIPTION
    Audit, apply, and revert Windows 11 optimization profiles.
    See docs/cli-spec.md for full parameter documentation.
#>

[CmdletBinding()]
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

$script:ModuleRoot = Join-Path $PSScriptRoot "modules"
if (Test-Path $script:ModuleRoot) {
    Get-ChildItem "$script:ModuleRoot\*.ps1" -ErrorAction SilentlyContinue |
        ForEach-Object { . $_.FullName }
}

if (-not $BackupPath) {
    $BackupPath = if ($env:WINTUNE_BACKUP_PATH) {
        $env:WINTUNE_BACKUP_PATH
    } else {
        Join-Path (Join-Path $env:LOCALAPPDATA "WinTune") "backups"
    }
}

if (-not $OutputDir) {
    $OutputDir = if ($env:WINTUNE_OUTPUT_DIR) {
        $env:WINTUNE_OUTPUT_DIR
    } else {
        Join-Path (Get-Location) "reports"
    }
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ExecutionPolicy {
    $current = Get-ExecutionPolicy -Scope CurrentUser
    $restrictedPolicies = @('Restricted', 'AllSigned')
    if ($current -in $restrictedPolicies) {
        Write-Warning "ExecutionPolicy is '$current' - some scripts may not run."
        Write-Warning "Recommended: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
        return $false
    }

    return $true
}

function Get-WindowsBuild {
    return [Environment]::OSVersion.Version.Build
}

$requiresAdmin = $Action -in @('Apply', 'Revert')
if ($requiresAdmin -and -not (Test-Admin)) {
    $msg = "Administrator rights required. Please run PowerShell as Administrator."
    if ($OutputJson) {
        Write-Output (ConvertTo-Json @{ success = $false; error = $msg })
    } else {
        Write-Error $msg
    }
    exit 1
}

$null = Test-ExecutionPolicy
$script:WindowsBuild = Get-WindowsBuild

function Get-AuditData {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfileName
    )

    Write-Progress -Activity "WinTune" -Status "Loading profile..." -PercentComplete 5
    $profileData = Get-Profile -Name $ProfileName

    Write-Progress -Activity "WinTune" -Status "Scanning system..." -PercentComplete 20
    $snapshot = Invoke-Scanner

    $bloatDbPath = Join-Path (Join-Path $PSScriptRoot "data") "bloat-database.json"
    $bloatDb = Get-Content $bloatDbPath -Raw | ConvertFrom-Json

    Write-Progress -Activity "WinTune" -Status "Calculating score..." -PercentComplete 80
    $score = Get-Score -Snapshot $snapshot -TweakIds $profileData.Tweaks -BloatDatabase $bloatDb

    Write-Progress -Activity "WinTune" -Status "Done" -PercentComplete 100 -Completed

    return @{
        Profile  = $profileData
        Snapshot = $snapshot
        Score    = $score
        BloatDb  = $bloatDb
    }
}

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
        if (-not $Profile) {
            Write-Error "-Profile is required."
            exit 1
        }

        $session = Initialize-LogSession -Action $Action
        Write-SessionEvent -SessionFile $session.SessionFile -Level Info -Message "Audit started for profile '$Profile'"

        $data = Get-AuditData -ProfileName $Profile

        Write-SessionEvent -SessionFile $session.SessionFile -Level Info -Message "Audit result: $($data.Score.Removed)/$($data.Score.Total) removed, score=$($data.Score.Score)%"

        if ($OutputJson) {
            $result = [PSCustomObject]@{
                Action    = 'Audit'
                Profile   = $data.Profile
                Snapshot  = $data.Snapshot
                Score     = $data.Score
                SessionId = $session.SessionId
            }
            Write-Output ($result | ConvertTo-Json -Depth 10)
        } else {
            Out-ConsoleReport -Score $data.Score -Snapshot $data.Snapshot -Profile $data.Profile
            Write-Host "Session log: $($session.SessionDir)"
        }

        if ($OutputDir) {
            if (-not (Test-Path $OutputDir)) {
                $null = New-Item -Path $OutputDir -ItemType Directory -Force
            }
            $htmlPath = Join-Path $OutputDir "audit-$Profile-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            $null = Out-HtmlReport -Score $data.Score -Snapshot $data.Snapshot -Profile $data.Profile -OutputPath $htmlPath
        }

        exit 0
    }

    'Apply' {
        if (-not $Profile) {
            Write-Error "-Profile is required."
            exit 1
        }

        $session = Initialize-LogSession -Action $Action
        Write-SessionEvent -SessionFile $session.SessionFile -Level Info -Message "Apply started for profile '$Profile'"

        if ($OutputJson) {
            $Confirm = $false
        }

        $data = Get-AuditData -ProfileName $Profile

        if ($data.Profile.Dangerous -and -not $Dangerous) {
            $msg = "Profile '$Profile' is marked as dangerous. Use -Dangerous to confirm."
            Write-SessionEvent -SessionFile $session.SessionFile -Level Error -Message $msg
            if ($OutputJson) {
                Write-Output (ConvertTo-Json @{ success = $false; error = $msg })
            } else {
                Write-Error $msg
            }
            exit 1
        }

        if ($WhatIf) {
            if ($OutputJson) {
                $result = [PSCustomObject]@{
                    Action       = 'WhatIf'
                    Profile      = $data.Profile
                    Score        = $data.Score
                    PendingItems = $data.Score.Present
                    SessionId    = $session.SessionId
                }
                Write-Output ($result | ConvertTo-Json -Depth 10)
            } else {
                Write-Host ""
                Write-Host "[WhatIf] Profile '$Profile' would clean $($data.Score.Present) remaining items."
                Write-Host "[WhatIf] Score would improve from $($data.Score.Score)% to 100%."
                Write-Host "Session log: $($session.SessionDir)"
            }
            Write-SessionEvent -SessionFile $session.SessionFile -Level Info -Message "WhatIf: $($data.Score.Present) items would be cleaned"
            exit 0
        }

        $progressFile = Join-Path $env:TEMP "wintune-apply-$($session.SessionId).jsonl"

        Write-Progress -Activity "WinTune" -Status "Applying tweaks..." -PercentComplete 50
        try {
            $engineResult = Invoke-TweaksEngine -ProfileName $Profile `
                -Snapshot $data.Snapshot `
                -WhatIf:$WhatIf `
                -Confirm:$Confirm `
                -Dangerous:$Dangerous `
                -StopOnError:$StopOnError `
                -BackupPathOverride $BackupPath `
                -SessionFile $session.SessionFile `
                -ProgressFile $progressFile
        } catch {
            Write-SessionEvent -SessionFile $session.SessionFile -Level Error -Message "Apply failed: $_"
            if ($OutputJson) {
                Write-Output (ConvertTo-Json @{ success = $false; error = "$_" })
            } else {
                Write-Error "Apply failed: $_"
            }
            exit 1
        }

        Write-Progress -Activity "WinTune" -Status "Finalizing..." -PercentComplete 90
        $finalSnapshot = Invoke-Scanner
        $finalScore = Get-Score -Snapshot $finalSnapshot -TweakIds $data.Profile.Tweaks -BloatDatabase $data.BloatDb

        Write-SessionEvent -SessionFile $session.SessionFile -Level Info -Message "Apply completed: score $($finalScore.Score)%, $($engineResult.Changes.Count) changes"

        if ($OutputJson) {
            $result = [PSCustomObject]@{
                Action       = 'Apply'
                Profile      = $data.Profile
                Score        = $finalScore
                Changes      = $engineResult.Changes
                Backup       = $engineResult.Backup
                SessionId    = $session.SessionId
                ProgressFile = $progressFile
            }
            Write-Output ($result | ConvertTo-Json -Depth 10)
        } else {
            Out-ConsoleReport -Score $finalScore -Snapshot $finalSnapshot -Profile $data.Profile -Changes $engineResult.Changes
            if ($engineResult.Backup) {
                Write-Host "Backup saved to: $($engineResult.Backup.BackupDir)"
            }
            Write-Host "Session log: $($session.SessionDir)"
        }

        if ($OutputDir) {
            if (-not (Test-Path $OutputDir)) {
                $null = New-Item -Path $OutputDir -ItemType Directory -Force
            }
            $htmlPath = Join-Path $OutputDir "apply-$Profile-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            $null = Out-HtmlReport -Score $finalScore -Snapshot $finalSnapshot -Profile $data.Profile -Changes $engineResult.Changes -OutputPath $htmlPath
        }

        $failedCount = @($engineResult.Changes | Where-Object { -not $_.Success }).Count
        if ($failedCount -gt 0 -and -not $StopOnError) {
            exit 2
        }

        exit 0
    }

    'Revert' {
        if (-not $Session) {
            Write-Error "-Session is required for Revert action."
            exit 1
        }

        $session = Initialize-LogSession -Action $Action
        Write-SessionEvent -SessionFile $session.SessionFile -Level Info -Message "Revert started for session '$Session'"

        if ($OutputJson) {
            $Confirm = $false
        }

        if (-not $Confirm -and -not $OutputJson) {
            Write-Host "Revert session '$Session'? This will undo all changes from that session."
            $reply = Read-Host "Type 'yes' to confirm"
            if ($reply -ne 'yes') {
                Write-SessionEvent -SessionFile $session.SessionFile -Level Warn -Message "Revert canceled by user"
                Write-Host "Canceled."
                exit 0
            }
        }

        Write-Progress -Activity "WinTune" -Status "Restoring backup..." -PercentComplete 50
        try {
            $results = Restore-Backup -Session $Session -BackupPathOverride $BackupPath
        } catch {
            Write-SessionEvent -SessionFile $session.SessionFile -Level Error -Message "Revert failed: $_"
            if ($OutputJson) {
                Write-Output (ConvertTo-Json @{ success = $false; error = "$_" })
            } else {
                Write-Error "Revert failed: $_"
            }
            exit 1
        }
        Write-Progress -Activity "WinTune" -Status "Done" -PercentComplete 100 -Completed

        $okCount = @($results | Where-Object { $_.Reverted }).Count
        $failCount = @($results | Where-Object { -not $_.Reverted }).Count
        Write-SessionEvent -SessionFile $session.SessionFile -Level Info -Message "Revert completed: $okCount succeeded, $failCount failed"

        if ($OutputJson) {
            $payload = [PSCustomObject]@{
                Action    = 'Revert'
                Session   = $Session
                Results   = @($results)
                SessionId = $session.SessionId
            }
            Write-Output ($payload | ConvertTo-Json -Depth 10)
        } else {
            Write-Host "Revert complete: $okCount succeeded, $failCount failed."
            foreach ($item in @($results)) {
                $icon = if ($item.Reverted) { "[OK]" } else { "[X]" }
                Write-Host "  $icon $($item.Name)"
                if ($item.Error) {
                    Write-Host "     Error: $($item.Error)"
                }
            }
            Write-Host "Session log: $($session.SessionDir)"
        }

        if ($OutputDir) {
            if (-not (Test-Path $OutputDir)) {
                $null = New-Item -Path $OutputDir -ItemType Directory -Force
            }
            $htmlPath = Join-Path $OutputDir "revert-$Session-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            $null = Out-HtmlReport -Score ([PSCustomObject]@{ Total=0; Present=0; Removed=0; Score=100 }) -Snapshot ([PSCustomObject]@{ Packages=@(); Services=@(); Tasks=@(); Registry=@{}; WindowsBuild=[Environment]::OSVersion.Version.Build; Metrics=[PSCustomObject]@{ IdleRamMB=0; ProcessCount=0 } }) -Profile ([PSCustomObject]@{ Name="Revert-$Session" }) -Changes $results -OutputPath $htmlPath
        }

        exit 0
    }
}
