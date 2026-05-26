# TWEAK: disable-taskbar-news
# CATEGORY: ui
# DESCRIPTION: Disables News & Interests widget on the taskbar
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableTaskbarNews {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds"
    $prop = "ShellFeedsTaskbarViewMode"

    $current = Get-ItemProperty -Path $path -Name $prop -ErrorAction SilentlyContinue

    if ($WhatIf) {
        Write-Host "  [disable-taskbar-news] Would set: ShellFeedsTaskbarViewMode = 2"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Taskbar News", "Disable")) {
        Write-Host "  [disable-taskbar-news] Skipped."
        return
    }

    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }

    Set-ItemProperty -Path $path -Name $prop -Value 2 -Type DWord
    Write-Host "  [disable-taskbar-news] Disabled: taskbar news & interests"
}
