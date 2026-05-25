function Get-Score {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Snapshot,

        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$TweakIds,

        [Parameter(Mandatory=$true)]
        [PSCustomObject]$BloatDatabase
    )

    $total = $TweakIds.Count
    if ($total -eq 0) {
        return [PSCustomObject]@{ Total = 0; Present = 0; Removed = 0; Score = 100 }
    }

    $present = 0

    $dbPackages = @{}
    foreach ($p in $BloatDatabase.packages) { $dbPackages[$p.id] = $p }
    $dbServices = @{}
    foreach ($s in $BloatDatabase.services) { $dbServices[$s.id] = $s }
    $dbTasks = @{}
    foreach ($t in $BloatDatabase.tasks) { $dbTasks[$t.id] = $t }
    $dbRegistry = @{}
    foreach ($r in $BloatDatabase.registry) { $dbRegistry[$r.id] = $r }
    $dbCommands = @{}
    foreach ($c in $BloatDatabase.commands) { $dbCommands[$c.id] = $c }

    foreach ($id in $TweakIds) {
        $detected = $false

        if ($dbPackages.ContainsKey($id)) {
            $entry = $dbPackages[$id]
            $detected = @($Snapshot.Packages | Where-Object { $_.Name -like $entry.name }).Count -gt 0
        } elseif ($dbServices.ContainsKey($id)) {
            $entry = $dbServices[$id]
            $detected = @($Snapshot.Services | Where-Object { $_.Name -eq $entry.name }).Count -gt 0
        } elseif ($dbTasks.ContainsKey($id)) {
            $entry = $dbTasks[$id]
            $detected = @($Snapshot.Tasks | Where-Object { "$($_.TaskPath)$($_.TaskName)" -like "*$($entry.name)*" }).Count -gt 0
        } elseif ($dbRegistry.ContainsKey($id)) {
            $detected = $Snapshot.Registry.PSObject.Properties.Name -contains $id -and $null -ne $Snapshot.Registry.$id
        } elseif ($dbCommands.ContainsKey($id)) {
            $detected = Test-CommandDetected -TweakId $id
        }

        if ($detected) { $present++ }
    }

    $removed = $total - $present
    $score = [math]::Round(($removed / $total) * 100)

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
        [array]$Changes
    )

    Write-Host "`n==========================================="
    Write-Host "  WinTune Report"
    Write-Host "  Profile: $($Profile.Name)"
    Write-Host "  Build: $($Snapshot.WindowsBuild)"
    Write-Host "==========================================="

    $barWidth = 30
    $filled = [math]::Round(($Score.Score / 100) * $barWidth)
    $empty = $barWidth - $filled
    $bar = "[" + ("#" * $filled) + ("-" * $empty) + "]"
    Write-Host "`n  Debloat Completion:  $($Score.Score)%  $bar"
    Write-Host "  $($Score.Removed) of $($Score.Total) items removed"

    Write-Host "`n  Summary:"
    Write-Host "    Packages installed: $($Snapshot.Packages.Count)"
    Write-Host "    Services running: $($($Snapshot.Services | Where-Object { $_.Status -eq 'Running' }).Count) / $($Snapshot.Services.Count)"
    Write-Host "    Tasks found: $($Snapshot.Tasks.Count)"
    Write-Host "    Idle RAM: $($Snapshot.Metrics.IdleRamMB) MB"
    Write-Host "    Process count: $($Snapshot.Metrics.ProcessCount)"

    if ($Changes -and $Changes.Count -gt 0) {
        Write-Host "`n  Changes applied:"
        $successCount = ($Changes | Where-Object { $_.Success }).Count
        $failCount = ($Changes | Where-Object { -not $_.Success }).Count
        Write-Host "    Succeeded: $successCount  Failed: $failCount"

        foreach ($ch in $Changes) {
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
        [array]$Changes,

        [Parameter()]
        [string]$OutputPath
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    $changeRows = ""
    if ($Changes) {
        foreach ($ch in $Changes) {
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
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>WinTune Report - $($Profile.Name)</title>
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
    <p>Profile: <strong>$($Profile.Name)</strong> | Build: $($Snapshot.WindowsBuild) | $timestamp</p>
    <div class="score">$($Score.Score)%</div>
    <p>Debloat Completion Rate - $($Score.Removed) of $($Score.Total) items removed</p>

    <h2>Changes</h2>
    <table>
        <tr><th>Tweak</th><th>Type</th><th>Name</th><th>Status</th></tr>
        $changeRows
    </table>

    <h2>System Info</h2>
    <table>
        <tr><td>Packages</td><td>$($Snapshot.Packages.Count)</td></tr>
        <tr><td>Services (total)</td><td>$($Snapshot.Services.Count)</td></tr>
        <tr><td>Services (running)</td><td>$($($Snapshot.Services | Where-Object { $_.Status -eq 'Running' }).Count)</td></tr>
        <tr><td>Tasks</td><td>$($Snapshot.Tasks.Count)</td></tr>
        <tr><td>Idle RAM</td><td>$($Snapshot.Metrics.IdleRamMB) MB</td></tr>
        <tr><td>Processes</td><td>$($Snapshot.Metrics.ProcessCount)</td></tr>
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
