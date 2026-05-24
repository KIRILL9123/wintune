# TWEAK: disable-dmwappush
# CATEGORY: privacy
# DESCRIPTION: Disables Device Management WAP Push service (telemetry-related)
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableDmwappush {
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $svc = Get-Service -Name dmwappushservice -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Host "  [disable-dmwappush] Service not found — skipping."; return }

    if ($WhatIf) { Write-Host "  [WhatIf] Would disable: dmwappushservice (currently $($svc.Status))"; return }
    if ($Confirm -and -not $PSCmdlet.ShouldProcess("dmwappushservice", "Disable service")) { Write-Host "  [disable-dmwappush] Skipped."; return }

    if ($svc.Status -eq 'Running') { Stop-Service -Name dmwappushservice -Force -ErrorAction Stop }
    Set-Service -Name dmwappushservice -StartupType Disabled -ErrorAction Stop
    Write-Host "  [disable-dmwappush] Disabled: dmwappushservice"
}
