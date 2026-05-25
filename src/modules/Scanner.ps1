function Invoke-Scanner {
    param()

    $timestamp = (Get-Date).ToString('o')

    # Service start modes (can fail without admin)
    $wmiToServiceMap = @{ 'Auto' = 'Automatic'; 'Manual' = 'Manual'; 'Disabled' = 'Disabled' }
    $serviceStartModes = @{}
    $serviceConfig = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue
    if ($serviceConfig) {
        foreach ($svcConfig in $serviceConfig) {
            $rawMode = $svcConfig.StartMode
            $serviceStartModes[$svcConfig.Name] = if ($wmiToServiceMap.ContainsKey($rawMode)) { $wmiToServiceMap[$rawMode] } else { $rawMode }
        }
    }

    # Packages
    Write-Progress -Activity "Scanning" -Status "Enumerating UWP packages..." -PercentComplete 10
    $packages = @()
    $allPackages = Get-AppxPackage -ErrorAction SilentlyContinue
    if ($allPackages) {
        foreach ($pkg in $allPackages) {
            $packages += [PSCustomObject]@{
                Name              = $pkg.Name
                PackageFullName   = $pkg.PackageFullName
                Publisher         = $pkg.Publisher
                InstallLocation   = $pkg.InstallLocation
            }
        }
    }

    # Services
    Write-Progress -Activity "Scanning" -Status "Enumerating services..." -PercentComplete 30
    $services = @()
    $allServices = Get-Service -ErrorAction SilentlyContinue
    if ($allServices) {
        foreach ($svc in $allServices) {
            $services += [PSCustomObject]@{
                Name      = $svc.Name
                DisplayName = $svc.DisplayName
                StartType = if ($serviceStartModes.ContainsKey($svc.Name)) { $serviceStartModes[$svc.Name] } else { $null }
                Status    = $svc.Status.ToString()
            }
        }
    }

    # Scheduled tasks (common paths)
    Write-Progress -Activity "Scanning" -Status "Enumerating scheduled tasks..." -PercentComplete 50
    $tasks = @()
    $taskPaths = @(
        '\Microsoft\Windows\Application Experience\',
        '\Microsoft\Windows\Customer Experience Improvement Program\',
        '\Microsoft\Windows\DiskDiagnostic\',
        '\Microsoft\Office\'
    )
    foreach ($path in $taskPaths) {
        $found = Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue
        if ($found) {
            foreach ($t in $found) {
                $tasks += [PSCustomObject]@{
                    TaskPath = $t.TaskPath
                    TaskName = $t.TaskName
                    State    = $t.State.ToString()
                }
            }
        }
    }

    # Registry keys (from bloat-database)
    Write-Progress -Activity "Scanning" -Status "Reading registry keys..." -PercentComplete 70
    $registry = @{}
    $bloatDbPath = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "data") "bloat-database.json"
    if (Test-Path $bloatDbPath) {
        try {
            $db = Get-Content $bloatDbPath -Raw -ErrorAction Stop | ConvertFrom-Json
            $entries = @($db.registry)
            foreach ($entry in $entries) {
                if (-not $entry -or -not $entry.name -or -not $entry.id) { continue }
                $path = $entry.name
                $keyParts = $path -split '\\'
                $valueName = $keyParts[-1]
                $keyPath = $keyParts[0..($keyParts.Length-2)] -join '\\'
                $psPath = $keyPath -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
                try {
                    $val = Get-ItemProperty -Path $psPath -Name $valueName -ErrorAction Stop
                    $registry[$entry.id] = $val.$valueName
                } catch {
                    $registry[$entry.id] = $null
                }
            }
        } catch {
            Write-Warning "Failed to load bloat-database.json: $_"
        }
    }

    # Metrics
    Write-Progress -Activity "Scanning" -Status "Measuring system metrics..." -PercentComplete 85
    $processCount = @(Get-Process -ErrorAction SilentlyContinue).Count
    $idleRamMB = 0
    $totalRam = $null
    try {
        $totalRam = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
    } catch {
        Write-Warning "Failed to read system memory info: $_"
    }
    if ($totalRam) {
        $workingSet = @(Get-Process -ErrorAction SilentlyContinue | Measure-Object -Property WorkingSet64 -Sum).Sum
        if ($workingSet) {
            $idleRamMB = [math]::Round(($totalRam - $workingSet) / 1MB)
        }
    }

    Write-Progress -Activity "Scanning" -Status "Done" -PercentComplete 100 -Completed

    return [PSCustomObject]@{
        Timestamp     = $timestamp
        WindowsBuild  = [Environment]::OSVersion.Version.Build
        Packages      = @($packages)
        Services      = @($services)
        Tasks         = @($tasks)
        Registry      = $registry
        Metrics       = [PSCustomObject]@{
            IdleRamMB        = $idleRamMB
            ProcessCount     = $processCount
            BootTimeSeconds  = $null
        }
    }
}
