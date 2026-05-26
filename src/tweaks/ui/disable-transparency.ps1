# TWEAK: disable-transparency
# CATEGORY: ui
# DESCRIPTION: Disables acrylic transparency effects to improve performance on low-end GPUs
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableTransparency {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $prop = "EnableTransparency"

    $current = Get-ItemProperty -Path $path -Name $prop -ErrorAction SilentlyContinue

    if ($WhatIf) {
        Write-Host "  [disable-transparency] Would set: EnableTransparency = 0"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Transparency Effects", "Disable")) {
        Write-Host "  [disable-transparency] Skipped."
        return
    }

    Set-ItemProperty -Path $path -Name $prop -Value 0 -Type DWord
    Write-Host "  [disable-transparency] Disabled: transparency effects"
}
