# TWEAK: disable-startup-delay
# CATEGORY: performance
# DESCRIPTION: Removes the 10-second startup app launch delay on login
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableStartupDelay {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
    $prop = "StartupDelayInMSec"

    $current = Get-ItemProperty -Path $path -Name $prop -ErrorAction SilentlyContinue

    if ($WhatIf) {
        Write-Host "  [disable-startup-delay] Would set: StartupDelayInMSec = 0"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Startup Delay", "Disable")) {
        Write-Host "  [disable-startup-delay] Skipped."
        return
    }

    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }

    Set-ItemProperty -Path $path -Name $prop -Value 0 -Type DWord
    Write-Host "  [disable-startup-delay] Disabled: startup app launch delay"
}
