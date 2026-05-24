# TWEAK: disable-telemetry
# CATEGORY: privacy
# DESCRIPTION: Disables Connected User Experiences and Telemetry (DiagTrack) service
# BUILD_MIN: 22000
# BUILD_MAX: 0
# DANGEROUS: false

function Invoke-DisableTelemetry {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )

    $svc = Get-Service -Name DiagTrack -ErrorAction SilentlyContinue

    if (-not $svc) {
        Write-Host "  [disable-telemetry] Service not found — skipping."
        return
    }

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would stop and disable: DiagTrack (currently $($svc.Status))"
        return
    }

    if ($Confirm -and -not $PSCmdlet.ShouldProcess("DiagTrack", "Stop and disable service")) {
        Write-Host "  [disable-telemetry] Skipped."
        return
    }

    if ($svc.Status -eq 'Running') {
        Stop-Service -Name DiagTrack -Force -ErrorAction Stop
    }
    Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction Stop
    Write-Host "  [disable-telemetry] Disabled: DiagTrack"
}
