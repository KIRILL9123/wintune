# TWEAK: remove-bing-weather
# CATEGORY: debloat
# DESCRIPTION: Removes Microsoft Bing Weather (bundled UWP app)
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-RemoveBingWeather {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $pkg = Get-AppxPackage -Name Microsoft.BingWeather -ErrorAction SilentlyContinue
    if (-not $pkg) { Write-Host "  [remove-bing-weather] Not installed — skipping."; return }

    if ($WhatIf) { Write-Host "  [WhatIf] Would remove: Microsoft.BingWeather"; return }
    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Microsoft.BingWeather", "Remove package")) { Write-Host "  [remove-bing-weather] Skipped."; return }

    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    Write-Host "  [remove-bing-weather] Removed: Microsoft.BingWeather"
}
