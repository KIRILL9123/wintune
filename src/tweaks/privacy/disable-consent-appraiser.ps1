# TWEAK: disable-consent-appraiser
# CATEGORY: privacy
# DESCRIPTION: Disables Microsoft Compatibility Appraiser scheduled task
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableConsentAppraiser {
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $task = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Application Experience\' -TaskName 'Microsoft Compatibility Appraiser' -ErrorAction SilentlyContinue
    if (-not $task) { Write-Host "  [disable-consent-appraiser] Task not found — skipping."; return }

    if ($WhatIf) { Write-Host "  [WhatIf] Would disable: Microsoft Compatibility Appraiser task"; return }
    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Microsoft Compatibility Appraiser task", "Disable scheduled task")) { Write-Host "  [disable-consent-appraiser] Skipped."; return }

    Disable-ScheduledTask -TaskName $task.TaskName -ErrorAction Stop
    Write-Host "  [disable-consent-appraiser] Disabled: Microsoft Compatibility Appraiser"
}
