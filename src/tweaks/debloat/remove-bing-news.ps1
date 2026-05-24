# TWEAK: remove-bing-news
# CATEGORY: debloat
# DESCRIPTION: Removes Microsoft Bing News (bundled UWP app)
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-RemoveBingNews {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $pkg = Get-AppxPackage -Name Microsoft.BingNews -ErrorAction SilentlyContinue

    if (-not $pkg) {
        Write-Host "  [remove-bing-news] Not installed — skipping."
        return
    }

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would remove: Microsoft.BingNews ($($pkg.PackageFullName))"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Microsoft.BingNews", "Remove package")) {
        Write-Host "  [remove-bing-news] Skipped."
        return
    }

    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    Write-Host "  [remove-bing-news] Removed: Microsoft.BingNews"
}
