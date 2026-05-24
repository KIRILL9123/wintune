# TWEAK: disable-ads-id
# CATEGORY: privacy
# DESCRIPTION: Disables advertising ID (opting out of tailored experiences)
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableAdsId {
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    $name = 'Enabled'

    if ($WhatIf) { Write-Host "  [WhatIf] Would set: $path\$name = 0"; return }
    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Advertising ID", "Disable")) { Write-Host "  [disable-ads-id] Skipped."; return }

    if (-not (Test-Path $path)) { $null = New-Item -Path $path -Force -ErrorAction Stop }
    Set-ItemProperty -Path $path -Name $name -Value 0 -ErrorAction Stop
    Write-Host "  [disable-ads-id] Disabled: advertising ID"
}
