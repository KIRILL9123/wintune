function Invoke-TweaksEngine {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfileName,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Snapshot,

        [Parameter()]
        [switch]$WhatIf,

        [Parameter()]
        [switch]$Confirm,

        [Parameter()]
        [switch]$Dangerous,

        [Parameter()]
        [switch]$StopOnError
    )

    # Load profile
    $profile = Get-Profile -Name $ProfileName
    $tweakIds = $profile.Tweaks

    Write-Progress -Activity "WinTune" -Status "Resolved profile: $($profile.Name) — $($tweakIds.Count) tweaks" -PercentComplete 5

    if ($profile.Dangerous -and -not $Dangerous) {
        Write-Warning "Profile '$ProfileName' contains dangerous tweaks. Use -Dangerous to enable."
        Write-Warning "Skipping dangerous tweaks."
    }

    $changes = @()
    $pendingTweaks = @()

    # Phase 1: Compare snapshot against profile (find what's still present)
    Write-Progress -Activity "WinTune" -Status "Comparing snapshot against profile..." -PercentComplete 20

    $bloatDb = Join-Path (Split-Path $PSScriptRoot -Parent) "data" "bloat-database.json"
    $db = Get-Content $bloatDb -Raw | ConvertFrom-Json

    # Build lookup from bloat database
    $dbPackages = @{}
    foreach ($p in $db.packages) { $dbPackages[$p.id] = $p }
    $dbServices = @{}
    foreach ($s in $db.services) { $dbServices[$s.id] = $s }
    $dbTasks = @{}
    foreach ($t in $db.tasks) { $dbTasks[$t.id] = $t }
    $dbRegistry = @{}
    foreach ($r in $db.registry) { $dbRegistry[$r.id] = $r }

    foreach ($tweakId in $tweakIds) {
        $detected = $false
        $tweakType = $null
        $tweakName = $null
        $entry = $null

        if ($dbPackages.ContainsKey($tweakId)) {
            $entry = $dbPackages[$tweakId]
            $tweakType = 'package'
            $tweakName = $entry.name
            $detected = ($Snapshot.Packages | Where-Object { $_.Name -like $entry.name }).Count -gt 0
        } elseif ($dbServices.ContainsKey($tweakId)) {
            $entry = $dbServices[$tweakId]
            $tweakType = 'service'
            $tweakName = $entry.name
            $detected = ($Snapshot.Services | Where-Object { $_.Name -eq $entry.name }).Count -gt 0
        } elseif ($dbTasks.ContainsKey($tweakId)) {
            $entry = $dbTasks[$tweakId]
            $tweakType = 'task'
            $tweakName = $entry.name
            $detected = ($Snapshot.Tasks | Where-Object { "$($_.TaskPath)$($_.TaskName)" -like "*$($entry.name)*" }).Count -gt 0
        } elseif ($dbRegistry.ContainsKey($tweakId)) {
            $entry = $dbRegistry[$tweakId]
            $tweakType = 'registry'
            $tweakName = $entry.name
            $detected = $Snapshot.Registry.PSObject.Properties.Name -contains $tweakId -and $null -ne $Snapshot.Registry.$tweakId
        }

        if ($detected) {
            $pendingTweaks += [PSCustomObject]@{
                TweakId = $tweakId
                Type    = $tweakType
                Name    = $tweakName
                Entry   = $entry
            }
        }
    }

    # Phase 2: Apply or preview
    Write-Progress -Activity "WinTune" -Status "Processing $($pendingTweaks.Count) applicable tweaks..." -PercentComplete 40

    if ($WhatIf) {
        Write-Host "`n[WhatIf] Preview for profile '$ProfileName':"
        Write-Host "  $($pendingTweaks.Count) items will be changed."
        foreach ($t in $pendingTweaks) {
            Write-Host "  Would $($t.Type): $($t.Name)"
        }
        return $changes
    }

    $tweakScriptsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "tweaks"
    $tweakCategories = @('privacy', 'performance', 'ui', 'debloat')

    foreach ($tweak in $pendingTweaks) {
        # Find the tweak script
        $tweakScript = $null
        foreach ($cat in $tweakCategories) {
            $candidate = Join-Path $tweakScriptsDir $cat "$($tweak.TweakId).ps1"
            if (Test-Path $candidate) {
                $tweakScript = $candidate
                break
            }
        }

        $change = [PSCustomObject]@{
            TweakId       = $tweak.TweakId
            Type          = $tweak.Type
            Name          = $tweak.Name
            OriginalValue = $null
            NewValue      = $null
            Timestamp     = (Get-Date).ToString('o')
            Success       = $false
            Error         = $null
        }

        try {
            if ($tweakScript) {
                # Dot-source and call the tweak function
                . $tweakScript
                $functionName = "Invoke-$($tweak.TweakId -replace '-','')"
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    & $functionName -WhatIf:$WhatIf -Confirm:$Confirm
                } else {
                    # Fallback: generic apply
                    Invoke-TweakGeneric -Tweak $tweak -Snapshot $Snapshot -WhatIf:$WhatIf -Confirm:$Confirm
                }
            } else {
                # No tweak script yet — use generic handler
                Invoke-TweakGeneric -Tweak $tweak -Snapshot $Snapshot -WhatIf:$WhatIf -Confirm:$Confirm
            }
            $change.Success = $true
            $change.NewValue = 'removed'  # simplified
        } catch {
            $change.Error = $_.Exception.Message
            if ($StopOnError) {
                throw
            }
            Write-Warning "Tweak '$($tweak.TweakId)' failed: $($_.Exception.Message)"
        }

        $changes += $change
    }

    # Phase 3: Backup
    if (-not $WhatIf -and $changes.Count -gt 0) {
        Write-Progress -Activity "WinTune" -Status "Creating backup..." -PercentComplete 85
        $backup = New-Backup -ProfileName $ProfileName -Changes $changes
        return [PSCustomObject]@{
            Changes     = $changes
            Backup      = $backup
            Score       = $null  # calculated by Reporter
        }
    }

    return [PSCustomObject]@{
        Changes = $changes
        Backup  = $null
        Score   = $null
    }
}

function Invoke-TweakGeneric {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Tweak,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Snapshot,

        [Parameter()]
        [switch]$WhatIf,

        [Parameter()]
        [switch]$Confirm
    )

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would $($Tweak.Type): $($Tweak.Name)"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess($Tweak.Name, "Apply tweak")) {
        Write-Host "  Skipped: $($Tweak.Name)"
        return
    }

    switch ($Tweak.Type) {
        'package' {
            $pkg = $Snapshot.Packages | Where-Object { $_.Name -like $Tweak.Name } | Select-Object -First 1
            if ($pkg) {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Host "  Removed package: $($pkg.Name)"
            }
        }
        'service' {
            $svc = Get-Service -Name $Tweak.Name -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq 'Running') {
                Stop-Service -Name $Tweak.Name -Force -ErrorAction Stop
                Set-Service -Name $Tweak.Name -StartupType Disabled -ErrorAction Stop
                Write-Host "  Disabled service: $($Tweak.Name)"
            }
        }
        'task' {
            $task = Get-ScheduledTask -TaskPath "*$($Tweak.Name)*" -ErrorAction SilentlyContinue
            if ($task) {
                Disable-ScheduledTask -TaskName $task.TaskName -ErrorAction Stop
                Write-Host "  Disabled task: $($Tweak.Name)"
            }
        }
        'registry' {
            $keyParts = $Tweak.Name -split '\\'
            $valueName = $keyParts[-1]
            $keyPath = $keyParts[0..($keyParts.Length-2)] -join '\\'
            $psPath = $keyPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
            if (-not (Test-Path $psPath)) {
                $null = New-Item -Path $psPath -Force -ErrorAction Stop
            }
            Set-ItemProperty -Path $psPath -Name $valueName -Value 0 -ErrorAction Stop
            Write-Host "  Set registry: $($Tweak.Name) = 0"
        }
    }
}
