# TWEAK: disable-lockscreen-suggestions
# CATEGORY: ui
# DESCRIPTION: Disables fun facts, tips, and suggestions on the lock screen
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableLockscreenSuggestions {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    $prop = "DisableSoftLanding"

    $current = Get-ItemProperty -Path $path -Name $prop -ErrorAction SilentlyContinue

    if ($WhatIf) {
        Write-Host "  [disable-lockscreen-suggestions] Would set: DisableSoftLanding = 1"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Lock Screen Suggestions", "Disable")) {
        Write-Host "  [disable-lockscreen-suggestions] Skipped."
        return
    }

    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }

    Set-ItemProperty -Path $path -Name $prop -Value 1 -Type DWord
    Write-Host "  [disable-lockscreen-suggestions] Disabled: lock screen tips"
}
