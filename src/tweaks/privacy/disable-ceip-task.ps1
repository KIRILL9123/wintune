# TWEAK: disable-ceip-task
# CATEGORY: privacy
# DESCRIPTION: Disables Customer Experience Improvement Program scheduled task
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableCeipTask {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $task = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Customer Experience Improvement Program\' -TaskName 'Consolidator' -ErrorAction SilentlyContinue
    if (-not $task) { Write-Host "  [disable-ceip-task] Task not found — skipping."; return }

    if ($WhatIf) { Write-Host "  [WhatIf] Would disable: CEIP Consolidator task"; return }
    if ($Confirm -and -not $PSCmdlet.ShouldProcess("CEIP Consolidator task", "Disable scheduled task")) { Write-Host "  [disable-ceip-task] Skipped."; return }

    Disable-ScheduledTask -TaskName $task.TaskName -ErrorAction Stop
    Write-Host "  [disable-ceip-task] Disabled: CEIP Consolidator"
}
