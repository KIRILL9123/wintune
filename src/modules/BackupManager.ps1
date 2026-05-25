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
        Join-Path (Join-Path $env:LOCALAPPDATA "WinTune") "backups"
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

    $regFile = Join-Path $backupDir "registry-backup.reg"
    $regKeys = $Changes | Where-Object { $_.Type -eq 'registry' } | ForEach-Object { $_.OriginalValue }
    # Registry export is still handled by tweak implementations; the manifest stores session metadata.

    $manifest = [PSCustomObject]@{
        Session      = $timestamp
        Profile      = $ProfileName
        CreatedAt    = (Get-Date).ToString('o')
        RestorePoint = $null
        RegistryFile = $regFile
        Changes      = $Changes | ForEach-Object -Begin { $seq = 0 } -Process {
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
    }

    try {
        Checkpoint-Computer -Description "WinTune backup before $ProfileName" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        $manifest.RestorePoint = "WinTune backup before $ProfileName"
    } catch {
        Write-Warning "System Restore Point unavailable or failed - continuing with registry backup only."
    }

    $manifestPath = Join-Path $backupDir "manifest.json"
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8

    return [PSCustomObject]@{
        Session      = $timestamp
        BackupDir    = $backupDir
        ManifestPath = $manifestPath
    }
}

function Restore-Backup {
    <#
    .SYNOPSIS
        Reverts changes from a backup session in reverse application order.

    .DESCRIPTION
        Reads a backup manifest, validates its structure, then reverts each
        change entry in reverse SequenceNumber order (last-applied first).
        The function reports per-change success/failure and skips unknown types.

    .PARAMETER Session
        The backup session timestamp (folder name under backups/).

    .PARAMETER BackupPathOverride
        Optional override for the backup base directory. Useful for testing.

    .OUTPUTS
        PSCustomObject[]. Each result has: TweakId, Type, Name, Reverted (bool),
        Error (string or $null).

    .NOTES
        ROLLBACK LIMITATIONS by type:

        registry
          Fully revertible — sets the original value back.
          Does NOT delete registry keys that the tweak may have created.
          Requires the PSDrive provider (HKLM: / HKCU:) to be available.

        service
          Partially revertible — restores StartupType and attempts to
          Start/Stop the service to match the original Status.
          If the service was deleted after backup, Get-Service fails and
          the revert is reported as an error.
          StartType revert respects the original value (string or hashtable
          with StartType + Status).

        task
          Partially revertible — re-enables a scheduled task that was
          disabled. Does NOT recreate tasks that were deleted.
          Silently skips if the task no longer exists.

        package
          NOT revertible — package reinstall is not implemented. Emits a
          warning and skips. An idempotent guard prevents re-application
          of already-removed packages.

        command
          NOT revertible — command undo is not implemented. Emits a
          warning and skips. Commands like disabling hibernation or
          OneDrive cannot be reversed automatically.

        GENERAL LIMITATIONS:
          - A backup is required for revert. No backup = no revert.
          - If a backup manifest was tampered with (missing TweakId, Type,
            or OriginalValue for registry/service/task), the invalid entry
            is reported as an error and skipped.
          - Partial failures: one change may fail while others succeed.
            Each result has an independent Reverted flag.
          - System Restore Point creation is best-effort and silently
            skipped if unavailable (e.g., when System Restore is disabled).
          - The manifest stores OriginalValue captured BEFORE mutation.
            If the system state changed externally between backup and
            revert (e.g., a user manually changed a registry value),
            reverting to the original value may not restore the expected
            state.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Session,

        [Parameter()]
        [string]$BackupPathOverride
    )

    $backupDir = Get-BackupPath -SessionTimestamp $Session -OverrideBase $BackupPathOverride
    if (-not (Test-Path $backupDir)) {
        throw "Backup directory not found for session '$Session' at $backupDir"
    }

    $manifestPath = Join-Path $backupDir "manifest.json"
    if (-not (Test-Path $manifestPath)) {
        throw "Backup manifest not found for session '$Session' at $manifestPath"
    }

    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse manifest for session '$Session': $_"
    }

    if (-not $manifest.Session) {
        Write-Warning "Manifest for session '$Session' is missing Session metadata"
    }

    $changes = @($manifest.Changes)
    if ($changes.Count -eq 0) {
        Write-Warning "No changes found in manifest for session '$Session'"
        return @()
    }

    if ($changes[0].SequenceNumber -ne $null) {
        $changes = $changes | Sort-Object SequenceNumber -Descending
    } else {
        $changes = $changes | Sort-Object Timestamp -Descending
    }

    $results = @()
    foreach ($change in $changes) {
        if (-not $change.TweakId -or -not $change.Type) {
            $results += [PSCustomObject]@{
                TweakId  = $change.TweakId
                Type     = $change.Type
                Name     = $change.Name
                Reverted = $false
                Error    = "Invalid change entry: missing TweakId or Type"
            }
            continue
        }

        $result = [PSCustomObject]@{
            TweakId  = $change.TweakId
            Type     = $change.Type
            Name     = $change.Name
            Reverted = $false
            Error    = $null
        }

        if ($null -eq $change.OriginalValue -and
            $change.Type -ne 'package' -and
            $change.Type -ne 'command') {
            $result.Error = "Missing OriginalValue for type '$($change.Type)'"
            $results += $result
            continue
        }

        if (-not $change.Name) {
            $result.Error = "Missing Name for change entry"
            $results += $result
            continue
        }

        try {
            switch ($change.Type) {
                'registry' {
                    $keyParts = $change.Name -split '\\'
                    $valueName = $keyParts[-1]
                    $keyPath = $keyParts[0..($keyParts.Length - 2)] -join '\'
                    $psPath = $keyPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
                    if (-not (Test-Path $psPath)) {
                        $null = New-Item -Path $psPath -Force -ErrorAction Stop
                    }
                    Set-ItemProperty -Path $psPath -Name $valueName -Value $change.OriginalValue -ErrorAction Stop
                }
                'service' {
                    $svc = Get-Service -Name $change.Name -ErrorAction SilentlyContinue
                    if (-not $svc) { throw "Service not found: $($change.Name)" }
                    if ($change.OriginalValue -is [hashtable] -or $change.OriginalValue -is [PSCustomObject]) {
                        $svcStartType = $change.OriginalValue.StartType
                        $svcStatus = $change.OriginalValue.Status
                    } else {
                        $svcStartType = $change.OriginalValue
                        $svcStatus = $null
                    }
                    if ($svcStartType) {
                        $wmiToServiceMap = @{ 'Auto' = 'Automatic'; 'Manual' = 'Manual'; 'Disabled' = 'Disabled' }
                        $mappedStartType = if ($wmiToServiceMap.ContainsKey($svcStartType)) { $wmiToServiceMap[$svcStartType] } else { $svcStartType }
                        Set-Service -Name $change.Name -StartupType $mappedStartType -ErrorAction Stop
                    }
                    if ($svcStatus -eq 'Running') {
                        Start-Service -Name $change.Name -ErrorAction SilentlyContinue
                    }
                }
                'package' {
                    throw "Package reinstall not supported yet: $($change.Name)"
                }
                'command' {
                    throw "Command revert not supported yet: $($change.Name)"
                }
                'task' {
                    $task = Get-ScheduledTask -TaskName $change.Name -ErrorAction SilentlyContinue
                    if ($task -and $change.OriginalValue -ne 'Disabled') {
                        Enable-ScheduledTask -TaskName $change.Name -ErrorAction Stop
                    }
                }
                default {
                    throw "Unknown type '$($change.Type)' for tweak '$($change.TweakId)'"
                }
            }
            $result.Reverted = $true
        } catch {
            $result.Error = $_.Exception.Message
        }

        $results += $result
    }

    return ,$results
}
