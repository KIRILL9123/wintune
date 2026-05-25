# Requires: TweaksEngine.ps1 (Test-CommandDetected is defined there, used by Get-Score for 'command' type tweaks)
function Get-Score {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Snapshot,

        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [array]$TweakIds,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BloatDatabase
    )

    $tweakIds = @($TweakIds)
    if ($tweakIds.Count -eq 0) {
        return [PSCustomObject]@{ Total = 0; Present = 0; Removed = 0; Score = 100 }
    }

    $windowsBuild = $Snapshot.WindowsBuild
    if (-not $windowsBuild) { $windowsBuild = 0 }

    $dbPackages = @{}
    foreach ($p in @($BloatDatabase.packages)) { if ($p.id) { $dbPackages[$p.id] = $p } }
    $dbServices = @{}
    foreach ($s in @($BloatDatabase.services)) { if ($s.id) { $dbServices[$s.id] = $s } }
    $dbTasks = @{}
    foreach ($t in @($BloatDatabase.tasks)) { if ($t.id) { $dbTasks[$t.id] = $t } }
    $dbRegistry = @{}
    foreach ($r in @($BloatDatabase.registry)) { if ($r.id) { $dbRegistry[$r.id] = $r } }
    $dbCommands = @{}
    foreach ($c in @($BloatDatabase.commands)) { if ($c.id) { $dbCommands[$c.id] = $c } }

    $snapshotPackages = @($Snapshot.Packages)
    $snapshotServices = @($Snapshot.Services)
    $snapshotTasks    = @($Snapshot.Tasks)
    $snapshotRegistry = $Snapshot.Registry
    if (-not $snapshotRegistry) { $snapshotRegistry = @{} }

    $total = 0
    $present = 0

    foreach ($id in $tweakIds) {
        if (-not $id) { continue }
        $detected = $false
        $entry = $null

        if ($dbPackages.ContainsKey($id)) {
            $entry = $dbPackages[$id]
        } elseif ($dbServices.ContainsKey($id)) {
            $entry = $dbServices[$id]
        } elseif ($dbTasks.ContainsKey($id)) {
            $entry = $dbTasks[$id]
        } elseif ($dbRegistry.ContainsKey($id)) {
            $entry = $dbRegistry[$id]
        } elseif ($dbCommands.ContainsKey($id)) {
            $entry = $dbCommands[$id]
        }

        if (-not $entry) { continue }

        if (($entry.buildMin -gt 0 -and $windowsBuild -lt $entry.buildMin) -or
            ($entry.buildMax -gt 0 -and $windowsBuild -gt $entry.buildMax)) {
            continue
        }

        $total++

        switch ($entry.type) {
            'package' {
                $detected = @($snapshotPackages | Where-Object { $_.Name -like $entry.name }).Count -gt 0
            }
            'service' {
                $detected = @($snapshotServices | Where-Object { $_.Name -eq $entry.name }).Count -gt 0
            }
            'task' {
                $detected = @($snapshotTasks | Where-Object { "$($_.TaskPath)$($_.TaskName)" -like "*$($entry.name)*" }).Count -gt 0
            }
            'registry' {
                $detected = $null -ne $snapshotRegistry.$id
            }
            'command' {
                $detected = Test-CommandDetected -TweakId $id
            }
        }

        if ($detected) { $present++ }
    }

    $removed = $total - $present
    $score = if ($total -gt 0) { [math]::Round(($removed / $total) * 100) } else { 100 }

    return [PSCustomObject]@{
        Total   = $total
        Present = $present
        Removed = $removed
        Score   = $score
    }
}

function Out-ConsoleReport {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Score,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Snapshot,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Profile,

        [Parameter()]
        [AllowNull()]
        [array]$Changes
    )

    $profileName   = if ($Profile.Name) { $Profile.Name } else { "Unknown" }
    $build         = if ($Snapshot.WindowsBuild) { $Snapshot.WindowsBuild } else { "N/A" }
    $scoreVal      = if ($null -ne $Score.Score) { $Score.Score } else { 0 }
    $removedVal    = if ($null -ne $Score.Removed) { $Score.Removed } else { 0 }
    $totalVal      = if ($null -ne $Score.Total) { $Score.Total } else { 0 }

    $snapshotPkgs  = @($Snapshot.Packages)
    $snapshotSvcs  = @($Snapshot.Services)
    $snapshotTasks = @($Snapshot.Tasks)
    $metrics       = $Snapshot.Metrics
    if (-not $metrics) { $metrics = [PSCustomObject]@{ IdleRamMB = 0; ProcessCount = 0 } }

    Write-Host "`n==========================================="
    Write-Host "  WinTune Report"
    Write-Host "  Profile: $profileName"
    Write-Host "  Build: $build"
    Write-Host "==========================================="

    $barWidth = 30
    $filled = [math]::Round(($scoreVal / 100) * $barWidth)
    $empty = $barWidth - $filled
    $bar = "[" + ("#" * $filled) + ("-" * $empty) + "]"
    Write-Host "`n  Debloat Completion:  $scoreVal%  $bar"
    Write-Host "  $removedVal of $totalVal items removed"

    Write-Host "`n  Summary:"
    Write-Host "    Packages installed: $($snapshotPkgs.Count)"
    $runningCount = @($snapshotSvcs | Where-Object { $_.Status -eq 'Running' }).Count
    Write-Host "    Services running: $runningCount / $($snapshotSvcs.Count)"
    Write-Host "    Tasks found: $($snapshotTasks.Count)"
    Write-Host "    Idle RAM: $($metrics.IdleRamMB) MB"
    Write-Host "    Process count: $($metrics.ProcessCount)"

    $changes = @($Changes)
    if ($changes.Count -gt 0) {
        Write-Host "`n  Changes applied:"
        $successCount = @($changes | Where-Object { $_.Success }).Count
        $failCount = @($changes | Where-Object { -not $_.Success }).Count
        Write-Host "    Succeeded: $successCount  Failed: $failCount"

        foreach ($ch in $changes) {
            $icon = if ($ch.Success) { "[OK]" } else { "[X]" }
            Write-Host "    $icon $($ch.TweakId) ($($ch.Type))"
            if ($ch.Error) {
                Write-Host "       Error: $($ch.Error)"
            }
        }
    }

    Write-Host "`n===========================================`n"
}

function Out-HtmlReport {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Score,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Snapshot,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Profile,

        [Parameter()]
        [AllowNull()]
        [array]$Changes,

        [Parameter()]
        [string]$OutputPath
    )

    $timestamp  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $profileName = if ($Profile.Name) { $Profile.Name } else { "Unknown" }
    $build       = if ($Snapshot.WindowsBuild) { $Snapshot.WindowsBuild } else { "N/A" }
    $scoreVal    = if ($null -ne $Score.Score) { $Score.Score } else { 0 }
    $removedVal  = if ($null -ne $Score.Removed) { $Score.Removed } else { 0 }
    $totalVal    = if ($null -ne $Score.Total) { $Score.Total } else { 0 }

    $snapshotPkgs  = @($Snapshot.Packages)
    $snapshotSvcs  = @($Snapshot.Services)
    $snapshotTasks = @($Snapshot.Tasks)
    $metrics = $Snapshot.Metrics
    if (-not $metrics) { $metrics = [PSCustomObject]@{ IdleRamMB = 0; ProcessCount = 0; BootTimeSeconds = $null } }

    $runningCount = @($snapshotSvcs | Where-Object { $_.Status -eq 'Running' }).Count

    $changeRows = ""
    $changes = @($Changes)
    foreach ($ch in $changes) {
        $status = if ($ch.Success) { "Succeeded" } else { "Failed: $($ch.Error)" }
        $changeRows += @"
            <tr>
                <td>$($ch.TweakId)</td>
                <td>$($ch.Type)</td>
                <td>$($ch.Name)</td>
                <td>$status</td>
            </tr>
"@
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>WinTune Report - $profileName</title>
    <style>
        body { font-family: -apple-system, Segoe UI, sans-serif; background: #0d1117; color: #c9d1d9; padding: 2em; }
        h1 { color: #00f0ff; }
        .score { font-size: 3em; font-weight: bold; color: #00f0ff; }
        table { border-collapse: collapse; width: 100%; margin-top: 1em; }
        th, td { padding: 0.5em 1em; text-align: left; border-bottom: 1px solid #30363d; }
        th { color: #8b949e; }
    </style>
</head>
<body>
    <h1>WinTune Report</h1>
    <p>Profile: <strong>$profileName</strong> | Build: $build | $timestamp</p>
    <div class="score">$scoreVal%</div>
    <p>Debloat Completion Rate - $removedVal of $totalVal items removed</p>

    <h2>Changes</h2>
    <table>
        <tr><th>Tweak</th><th>Type</th><th>Name</th><th>Status</th></tr>
        $changeRows
    </table>

    <h2>System Info</h2>
    <table>
        <tr><td>Packages</td><td>$($snapshotPkgs.Count)</td></tr>
        <tr><td>Services (total)</td><td>$($snapshotSvcs.Count)</td></tr>
        <tr><td>Services (running)</td><td>$runningCount</td></tr>
        <tr><td>Tasks</td><td>$($snapshotTasks.Count)</td></tr>
        <tr><td>Idle RAM</td><td>$($metrics.IdleRamMB) MB</td></tr>
        <tr><td>Processes</td><td>$($metrics.ProcessCount)</td></tr>
    </table>
</body>
</html>
"@

    if ($OutputPath) {
        $html | Set-Content $OutputPath -Encoding UTF8
        Write-Host "HTML report saved to: $OutputPath"
    }

    return $html
}
