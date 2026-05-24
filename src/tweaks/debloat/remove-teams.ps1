# TWEAK: remove-teams
# CATEGORY: debloat
# DESCRIPTION: Removes Microsoft Teams (personal edition bundled with Windows 11)
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-RemoveTeams {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $pkg = Get-AppxPackage -Name Microsoft.Teams* -ErrorAction SilentlyContinue
    if (-not $pkg) { Write-Host "  [remove-teams] Not installed — skipping."; return }

    if ($WhatIf) { Write-Host "  [WhatIf] Would remove: Microsoft.Teams"; return }
    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Microsoft.Teams", "Remove package")) { Write-Host "  [remove-teams] Skipped."; return }

    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
    Write-Host "  [remove-teams] Removed: Microsoft.Teams"
}
