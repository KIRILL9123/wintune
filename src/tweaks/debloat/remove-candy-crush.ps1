# TWEAK: remove-candy-crush
# CATEGORY: debloat
# DESCRIPTION: Removes Candy Crush Saga (bundled with Windows 11)
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-RemoveCandyCrush {
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $pkg = Get-AppxPackage -Name *CandyCrushSaga* -ErrorAction SilentlyContinue

    if (-not $pkg) {
        Write-Host "  [remove-candy-crush] Not installed — skipping."
        return
    }

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would remove: $($pkg.Name) ($($pkg.PackageFullName))"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess($pkg.Name, "Remove package")) {
        Write-Host "  [remove-candy-crush] Skipped."
        return
    }

    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    Write-Host "  [remove-candy-crush] Removed: $($pkg.Name)"
}
