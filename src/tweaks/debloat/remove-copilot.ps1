# TWEAK: remove-copilot
# CATEGORY: debloat
# DESCRIPTION: Removes Microsoft Copilot (added in 23H2)
# BUILD_MIN: 22621
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-RemoveCopilot {
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $pkg = Get-AppxPackage -Name Microsoft.Copilot* -ErrorAction SilentlyContinue
    if (-not $pkg) { Write-Host "  [remove-copilot] Not installed — skipping."; return }

    if ($WhatIf) { Write-Host "  [WhatIf] Would remove: Microsoft.Copilot"; return }
    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Microsoft.Copilot", "Remove package")) { Write-Host "  [remove-copilot] Skipped."; return }

    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    Write-Host "  [remove-copilot] Removed: Microsoft.Copilot"
}
