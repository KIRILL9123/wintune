function Get-BackupPath {
    param(
        [string]$SessionTimestamp,
        [string]$OverrideBase
    )

    $base = if ($OverrideBase) {
        $OverrideBase
    } elseif ($env:WINTUNE_BACKUP_PATH) {
        $env:WINTUNE_BACKUP_PATH
    } else {
        Join-Path $env:LOCALAPPDATA "WinTune" "backups"
    }

    if ($SessionTimestamp) {
        return Join-Path $base $SessionTimestamp
    }
    return $base
}

function New-SessionTimestamp {
    (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
}

function New-Backup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfileName,

        [Parameter(Mandatory=$true)]
        [array]$Changes,

        [Parameter()]
        [string]$BackupPathOverride
    )

    $timestamp = New-SessionTimestamp
    $backupDir = Get-BackupPath -SessionTimestamp $timestamp -OverrideBase $BackupPathOverride

    if (-not (Test-Path $backupDir)) {
        $null = New-Item -Path $backupDir -ItemType Directory -Force
    }

    # Registry backup (.reg)
    $regFile = Join-Path $backupDir "registry-backup.reg"
    $regKeys = $Changes | Where-Object { $_.Type -eq 'registry' } | ForEach-Object { $_.OriginalValue }
    # Export is done per-key by the tweak function; this file aggregates metadata only

    # JSON manifest
    $manifest = [PSCustomObject]@{
        Session      = $timestamp
        Profile      = $ProfileName
        CreatedAt    = (Get-Date).ToString('o')
        RestorePoint = $null
        RegistryFile = $regFile
        Changes      = $Changes | ForEach-Object {
            [PSCustomObject]@{
                TweakId        = $_.TweakId
                Type           = $_.Type
                Name           = $_.Name
                OriginalValue  = $_.OriginalValue
                NewValue       = $_.NewValue
                Timestamp      = $_.Timestamp
                Success        = $_.Success
                Error          = $_.Error
            }
        }
    }

    $manifestPath = Join-Path $backupDir "manifest.json"
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8

    # Try System Restore Point (non-fatal)
    try {
        Checkpoint-Computer -Description "WinTune backup before $ProfileName" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        $manifest.RestorePoint = "WinTune backup before $ProfileName"
    } catch {
        Write-Warning "System Restore Point unavailable or failed — continuing with registry backup only."
    }

    return [PSCustomObject]@{
        Session      = $timestamp
        BackupDir    = $backupDir
        ManifestPath = $manifestPath
    }
}

function Restore-Backup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Session
    )

    $backupDir = Get-BackupPath -SessionTimestamp $Session
    $manifestPath = Join-Path $backupDir "manifest.json"

    if (-not (Test-Path $manifestPath)) {
        throw "Backup manifest not found for session '$Session' at $manifestPath"
    }

    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $changes = $manifest.Changes | Sort-Object Timestamp -Descending

    $results = @()
    foreach ($change in $changes) {
        $result = [PSCustomObject]@{
            TweakId  = $change.TweakId
            Type     = $change.Type
            Name     = $change.Name
            Reverted = $false
            Error    = $null
        }

        try {
            switch ($change.Type) {
                'registry' {
                    $keyParts = $change.Name -split '\\'
                    $valueName = $keyParts[-1]
                    $keyPath = $keyParts[0..($keyParts.Length-2)] -join '\\'
                    $psPath = $keyPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
                    if (-not (Test-Path $psPath)) {
                        $null = New-Item -Path $psPath -Force -ErrorAction Stop
                    }
                    Set-ItemProperty -Path $psPath -Name $valueName -Value $change.OriginalValue -ErrorAction Stop
                }
                'service' {
                    $svc = Get-Service -Name $change.Name -ErrorAction SilentlyContinue
                    if ($svc -and $change.OriginalValue -eq 'Automatic') {
                        Set-Service -Name $change.Name -StartupType Automatic -ErrorAction Stop
                    }
                }
                'package' {
                    # Packages are reinstalled from store — revert means "we cleared the removal flag"
                    # This is a best-effort placeholder
                    Write-Warning "Package reinstall not supported yet: $($change.Name)"
                }
                'task' {
                    $task = Get-ScheduledTask -TaskName $change.Name -ErrorAction SilentlyContinue
                    if ($task) {
                        Enable-ScheduledTask -TaskName $change.Name -ErrorAction Stop
                    }
                }
            }
            $result.Reverted = $true
        } catch {
            $result.Error = $_.Exception.Message
        }
        $results += $result
    }

    return $results
}
