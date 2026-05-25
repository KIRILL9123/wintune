function Initialize-LogSession {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,
        [Parameter()]
        [string]$OutputRoot
    )

    $root = if ($OutputRoot) { $OutputRoot } else { Join-Path (Get-Location) "logs" }
    if (-not (Test-Path $root)) {
        $null = New-Item -Path $root -ItemType Directory -Force
    }

    $sessionId = (Get-Date).ToString("yyyyMMdd-HHmmss")
    $sessionDir = Join-Path $root $sessionId
    if (-not (Test-Path $sessionDir)) {
        $null = New-Item -Path $sessionDir -ItemType Directory -Force
    }

    $sessionFile = Join-Path $sessionDir "session.json"
    $auditFile = Join-Path $sessionDir "audit.csv"
    $errorFile = Join-Path $sessionDir "error.log"

    if (-not (Test-Path $sessionFile)) {
        $payload = [PSCustomObject]@{
            SessionId = $sessionId
            Action = $Action
            StartedAt = (Get-Date).ToString("o")
            Events = @()
        }
        $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $sessionFile -Encoding UTF8
    }

    if (-not (Test-Path $auditFile)) {
        "Timestamp,Action,Level,Message" | Set-Content -Path $auditFile -Encoding UTF8
    }

    if (-not (Test-Path $errorFile)) {
        "" | Set-Content -Path $errorFile -Encoding UTF8
    }

    return [PSCustomObject]@{
        SessionId = $sessionId
        SessionDir = $sessionDir
        SessionFile = $sessionFile
        AuditFile = $auditFile
        ErrorFile = $errorFile
    }
}

function Write-SessionEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SessionFile,
        [Parameter(Mandatory=$true)]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $session = Get-Content -Path $SessionFile -Raw | ConvertFrom-Json
    $events = @($session.Events)
    $events += [PSCustomObject]@{
        Timestamp = (Get-Date).ToString("o")
        Level = $Level
        Message = $Message
    }
    $session.Events = $events
    $session | ConvertTo-Json -Depth 10 | Set-Content -Path $SessionFile -Encoding UTF8
}
