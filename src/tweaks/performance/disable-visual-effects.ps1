# TWEAK: disable-visual-effects
# CATEGORY: performance
# DESCRIPTION: Disables Windows visual effects (animations, shadows, font smoothing) for faster UI
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableVisualEffects {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    $prop = "VisualFXSetting"

    $current = Get-ItemProperty -Path $path -Name $prop -ErrorAction SilentlyContinue

    if ($whatIf) {
        Write-Host "  [disable-visual-effects] Would set: VisualFXSetting = 2 (Best performance)"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Visual Effects", "Set to Best Performance")) {
        Write-Host "  [disable-visual-effects] Skipped."
        return
    }

    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }

    Set-ItemProperty -Path $path -Name $prop -Value 2 -Type DWord
    Write-Host "  [disable-visual-effects] Disabled: visual effects set to Best Performance"
}
