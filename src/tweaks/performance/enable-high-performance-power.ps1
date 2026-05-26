# TWEAK: enable-high-performance-power
# CATEGORY: performance
# DESCRIPTION: Sets power plan to High Performance for maximum CPU/GPU throughput
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-EnableHighPerformancePower {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $plan = powercfg /l | Select-String -Pattern "High performance" -SimpleMatch
    if (-not $plan) {
        Write-Host "  [enable-high-performance-power] High Performance plan not found — skipping."
        return
    }

    $guid = ($plan -split '\s+')[3]

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would enable: High Performance power plan"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess("Power Plan", "Set to High Performance")) {
        Write-Host "  [enable-high-performance-power] Skipped."
        return
    }

    powercfg /setactive $guid
    Write-Host "  [enable-high-performance-power] Enabled: High Performance power plan"
}
