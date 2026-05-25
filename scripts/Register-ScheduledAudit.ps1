<#
.SYNOPSIS
    Registers a weekly scheduled task that runs WinTune Audit
    and writes results to a timestamped JSON file.

.DESCRIPTION
    Creates a Scheduled Task that executes every Monday at 3:00 AM.
    The task runs as SYSTEM (no user login required, always elevated).
    Audit results are written to $env:LOCALAPPDATA\WinTune\logs\audit\YYYY-MM-DD.json.

.PARAMETER Profile
    Profile name to audit (default: base).

.PARAMETER OutputPath
    Directory for audit output files (default: %LOCALAPPDATA%\WinTune\logs\audit).

.EXAMPLE
    .\scripts\Register-ScheduledAudit.ps1 -Profile gaming

.EXAMPLE
    .\scripts\Register-ScheduledAudit.ps1 -Profile base -OutputPath C:\WinTune\audit-logs
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Profile = "base",

    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$wintunePath = Join-Path $repoRoot "src\wintune.ps1"

if (-not (Test-Path $wintunePath)) {
    throw "WinTune entry point not found at: $wintunePath"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path (Join-Path $env:LOCALAPPDATA "WinTune") "logs\audit"
}

if (-not (Test-Path $OutputPath)) {
    $null = New-Item -Path $OutputPath -ItemType Directory -Force
}

$taskName = "WinTune Weekly Audit"
$taskDescription = "Weekly system audit using WinTune profile '$Profile'. Runs every Monday at 3:00 AM."

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy Bypass",
    "-File `"$wintunePath`"",
    "-Action Audit",
    "-Profile $Profile",
    "-OutputJson"
) -join " "

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 3am

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

try {
    Unregister-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue -Confirm:$false
} catch { }

$task = Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description $taskDescription `
    -Force

Write-Host "Scheduled task registered: '$taskName'"
Write-Host "  Profile:     $Profile"
Write-Host "  Schedule:    Weekly, Mondays at 03:00"
Write-Host "  Run as:      SYSTEM"
Write-Host "  Output:      $OutputPath"
Write-Host ""
Write-Host "To remove:     Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false"
Write-Host "To run now:    Start-ScheduledTask -TaskName '$taskName'"
