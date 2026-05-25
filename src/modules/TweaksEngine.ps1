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
        [switch]$StopOnError,

        [Parameter()]
        [string]$BackupPathOverride
    )

    $profile = Get-Profile -Name $ProfileName
    $tweakIds = $profile.Tweaks

    Write-Progress -Activity "WinTune" -Status "Resolved profile: $($profile.Name) - $($tweakIds.Count) tweaks" -PercentComplete 5

    if ($profile.Dangerous -and -not $Dangerous) {
        Write-Warning "Profile '$ProfileName' contains dangerous tweaks. Use -Dangerous to enable."
        Write-Warning "Skipping dangerous tweaks."
    }

    $changes = @()
    $pendingTweaks = @()

    Write-Progress -Activity "WinTune" -Status "Comparing snapshot against profile..." -PercentComplete 20

    $bloatDb = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "data") "bloat-database.json"
    $db = Get-Content $bloatDb -Raw | ConvertFrom-Json

    $dbPackages = @{}
    foreach ($p in $db.packages) { $dbPackages[$p.id] = $p }
    $dbServices = @{}
    foreach ($s in $db.services) { $dbServices[$s.id] = $s }
    $dbTasks = @{}
    foreach ($t in $db.tasks) { $dbTasks[$t.id] = $t }
    $dbRegistry = @{}
    foreach ($r in $db.registry) { $dbRegistry[$r.id] = $r }
    $dbCommands = @{}
    foreach ($c in $db.commands) { $dbCommands[$c.id] = $c }

    foreach ($tweakId in $tweakIds) {
        $detected = $false
        $tweakType = $null
        $tweakName = $null
        $entry = $null

        if ($dbPackages.ContainsKey($tweakId)) {
            $entry = $dbPackages[$tweakId]
            $tweakType = 'package'
            $tweakName = $entry.name
            $detected = $false
            foreach ($pkg in $Snapshot.Packages) {
                if ($pkg.Name -like $entry.name) { $detected = $true; break }
            }
        } elseif ($dbServices.ContainsKey($tweakId)) {
            $entry = $dbServices[$tweakId]
            $tweakType = 'service'
            $tweakName = $entry.name
            $detected = $false
            foreach ($svc in $Snapshot.Services) {
                if ($svc.Name -eq $entry.name) { $detected = $true; break }
            }
        } elseif ($dbTasks.ContainsKey($tweakId)) {
            $entry = $dbTasks[$tweakId]
            $tweakType = 'task'
            $tweakName = $entry.name
            $detected = $false
            foreach ($task in $Snapshot.Tasks) {
                if ("$($task.TaskPath)$($task.TaskName)" -like "*$($entry.name)*") { $detected = $true; break }
            }
        } elseif ($dbRegistry.ContainsKey($tweakId)) {
            $entry = $dbRegistry[$tweakId]
            $tweakType = 'registry'
            $tweakName = $entry.name
            $detected = $Snapshot.Registry.PSObject.Properties.Name -contains $tweakId -and $null -ne $Snapshot.Registry.$tweakId
        } elseif ($dbCommands.ContainsKey($tweakId)) {
            $entry = $dbCommands[$tweakId]
            $tweakType = 'command'
            $tweakName = $entry.name
            $detected = Test-CommandDetected -TweakId $tweakId
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

    Write-Progress -Activity "WinTune" -Status "Processing $($pendingTweaks.Count) applicable tweaks..." -PercentComplete 40

    if ($WhatIf) {
        Write-Host ""
        Write-Host "[WhatIf] Preview for profile '$ProfileName':"
        Write-Host "  $($pendingTweaks.Count) items will be changed."
        foreach ($t in $pendingTweaks) {
            Write-Host "  Would $($t.Type): $($t.Name)"
        }

        return [PSCustomObject]@{
            Changes = @()
            Backup  = $null
            Score   = $null
        }
    }

    Write-Progress -Activity "WinTune" -Status "Capturing original state..." -PercentComplete 45
    $pendingItems = foreach ($tweak in $pendingTweaks) {
        $origValue = Read-OriginalValue -Tweak $tweak -Snapshot $Snapshot
        [PSCustomObject]@{
            Tweak         = $tweak
            OriginalValue = $origValue
        }
    }

    if ($pendingItems.Count -gt 0) {
        Write-Progress -Activity "WinTune" -Status "Creating backup before changes..." -PercentComplete 50
        $preChanges = $pendingItems | ForEach-Object {
            [PSCustomObject]@{
                TweakId       = $_.Tweak.TweakId
                Type          = $_.Tweak.Type
                Name          = $_.Tweak.Name
                OriginalValue = $_.OriginalValue
                NewValue      = $null
                Timestamp     = (Get-Date).ToString('o')
                Success       = $false
                Error         = $null
            }
        }
        $backup = New-Backup -ProfileName $ProfileName -Changes $preChanges -BackupPathOverride $BackupPathOverride
    }

    $tweakScriptsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "tweaks"
    $tweakCategories = @('privacy', 'performance', 'ui', 'debloat')

    $seq = 0
    foreach ($item in $pendingItems) {
        $seq++
        $tweak = $item.Tweak
        $tweakScript = $null
        foreach ($cat in $tweakCategories) {
            $candidate = Join-Path (Join-Path $tweakScriptsDir $cat) "$($tweak.TweakId).ps1"
            if (Test-Path $candidate) {
                $tweakScript = $candidate
                break
            }
        }

        $change = [PSCustomObject]@{
            TweakId         = $tweak.TweakId
            Type            = $tweak.Type
            Name            = $tweak.Name
            OriginalValue   = $item.OriginalValue
            NewValue        = $null
            Timestamp       = (Get-Date).ToString('o')
            Success         = $false
            Error           = $null
            SequenceNumber  = $seq
        }

        try {
            if ($tweakScript) {
                . $tweakScript
                $functionName = "Invoke-$($tweak.TweakId -replace '-', '')"
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    & $functionName -WhatIf:$WhatIf -Confirm:$Confirm
                } else {
                    Invoke-TweakGeneric -Tweak $tweak -Snapshot $Snapshot -WhatIf:$WhatIf -Confirm:$Confirm
                }
            } else {
                Invoke-TweakGeneric -Tweak $tweak -Snapshot $Snapshot -WhatIf:$WhatIf -Confirm:$Confirm
            }

            $change.Success = $true
            $change.NewValue = if ($tweak.Type -eq 'registry') { 0 } else { 'removed' }
        } catch {
            $change.Error = $_.Exception.Message
            if ($StopOnError) {
                throw
            }
            Write-Warning "Tweak '$($tweak.TweakId)' failed: $($_.Exception.Message)"
        }

        $changes += $change
    }

    if ($backup -and $changes.Count -gt 0) {
        $manifest = Get-Content $backup.ManifestPath -Raw | ConvertFrom-Json
        $manifest.Changes = $changes | ForEach-Object -Begin { $seq = 0 } -Process {
            $seq++
            [PSCustomObject]@{
                SequenceNumber  = $seq
                TweakId         = $_.TweakId
                Type            = $_.Type
                Name            = $_.Name
                OriginalValue   = $_.OriginalValue
                NewValue        = $_.NewValue
                Timestamp       = $_.Timestamp
                Success         = $_.Success
                Error           = $_.Error
            }
        }
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $backup.ManifestPath -Encoding UTF8
    }

    return [PSCustomObject]@{
        Changes = $changes
        Backup  = $backup
        Score   = $null
    }
}

function Read-OriginalValue {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Tweak,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Snapshot
    )

    switch ($Tweak.Type) {
        'package' {
            $pkg = $Snapshot.Packages | Where-Object { $_.Name -like $Tweak.Name } | Select-Object -First 1
            if ($pkg) { return $pkg.PackageFullName }
        }
        'service' {
            $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($Tweak.Name)'" -ErrorAction SilentlyContinue
            if ($svc) { return @{ StartType = $svc.StartMode; Status = $svc.Status } }
        }
        'task' {
            $task = Get-ScheduledTask -ErrorAction SilentlyContinue |
                Where-Object { "$($_.TaskPath)$($_.TaskName)" -like "*$($Tweak.Name)*" } |
                Select-Object -First 1
            if ($task) { return $task.State.ToString() }
        }
        'registry' {
            $keyParts = $Tweak.Name -split '\\'
            $valueName = $keyParts[-1]
            $keyPath = $keyParts[0..($keyParts.Length - 2)] -join '\'
            $psPath = $keyPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
            try {
                return (Get-ItemProperty -Path $psPath -Name $valueName -ErrorAction Stop).$valueName
            } catch {
                return $null
            }
        }
        'command' {
            if (Test-CommandDetected -TweakId $Tweak.TweakId) { return 'enabled' }
            return 'disabled'
        }
    }

    return $null
}

function Invoke-TweakGeneric {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Tweak,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Snapshot
    )

    if ($WhatIfPreference) {
        Write-Host "  [WhatIf] Would $($Tweak.Type): $($Tweak.Name)"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Tweak.Name, "Apply tweak")) {
        Write-Host "  Skipped: $($Tweak.Name)"
        return
    }

    switch ($Tweak.Type) {
        'package' {
            $pkg = $Snapshot.Packages | Where-Object { $_.Name -like $Tweak.Name } | Select-Object -First 1
            if (-not $pkg) {
                Write-Host "  Already removed: $($Tweak.Name)"
                return
            }
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            Write-Host "  Removed package: $($pkg.Name)"
        }
        'service' {
            $svc = Get-Service -Name $Tweak.Name -ErrorAction SilentlyContinue
            if (-not $svc) {
                Write-Host "  Service not found: $($Tweak.Name)"
                return
            }
            if ($svc.StartType -eq 'Disabled') {
                Write-Host "  Already disabled: $($Tweak.Name)"
                return
            }
            if ($svc.Status -eq 'Running') {
                Stop-Service -Name $Tweak.Name -Force -ErrorAction Stop
            }
            Set-Service -Name $Tweak.Name -StartupType Disabled -ErrorAction Stop
            Write-Host "  Disabled service: $($Tweak.Name)"
        }
        'task' {
            $task = Get-ScheduledTask -ErrorAction SilentlyContinue |
                Where-Object { "$($_.TaskPath)$($_.TaskName)" -like "*$($Tweak.Name)*" } |
                Select-Object -First 1
            if (-not $task) {
                Write-Host "  Task not found: $($Tweak.Name)"
                return
            }
            if ($task.State -eq 'Disabled') {
                Write-Host "  Already disabled: $($Tweak.Name)"
                return
            }
            Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop
            Write-Host "  Disabled task: $($Tweak.Name)"
        }
        'registry' {
            $keyParts = $Tweak.Name -split '\\'
            $valueName = $keyParts[-1]
            $keyPath = $keyParts[0..($keyParts.Length - 2)] -join '\'
            $psPath = $keyPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
            try {
                $current = (Get-ItemProperty -Path $psPath -Name $valueName -ErrorAction Stop).$valueName
                if ($current -eq 0 -or $current -eq '0') {
                    Write-Host "  Already set: $($Tweak.Name) = 0"
                    return
                }
            } catch {
            }
            if (-not (Test-Path $psPath)) {
                $null = New-Item -Path $psPath -Force -ErrorAction Stop
            }
            Set-ItemProperty -Path $psPath -Name $valueName -Value 0 -ErrorAction Stop
            Write-Host "  Set registry: $($Tweak.Name) = 0"
        }
        'command' {
            if ($Tweak.TweakId -eq 'disable-hibernation') {
                $hiberStatus = powercfg /a 2>$null | Select-String -Pattern 'Hibernation' -SimpleMatch
                if (-not $hiberStatus) {
                    Write-Host "  Already disabled: Hibernation"
                    return
                }
                powercfg /h off *>$null
                Write-Host "  Disabled: Hibernation (powercfg /h off)"
            }
        }
    }
}

function Test-CommandDetected {
    param([string]$TweakId)

    switch ($TweakId) {
        'disable-hibernation' {
            return $null -ne (powercfg /a 2>$null | Select-String -Pattern 'Hibernation' -SimpleMatch)
        }
        default {
            return $false
        }
    }
}
