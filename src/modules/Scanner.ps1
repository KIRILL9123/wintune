function Invoke-Scanner {
    param()

    $timestamp = (Get-Date).ToString('o')

    # Packages
    Write-Progress -Activity "Scanning" -Status "Enumerating UWP packages..." -PercentComplete 10
    $packages = @()
    $allPackages = Get-AppxPackage -ErrorAction SilentlyContinue
    foreach ($pkg in $allPackages) {
        $packages += [PSCustomObject]@{
            Name              = $pkg.Name
            PackageFullName   = $pkg.PackageFullName
            Publisher         = $pkg.Publisher
            InstallLocation   = $pkg.InstallLocation
        }
    }

    # Services
    Write-Progress -Activity "Scanning" -Status "Enumerating services..." -PercentComplete 30
    $services = @()
    $allServices = Get-Service -ErrorAction SilentlyContinue
    foreach ($svc in $allServices) {
        $services += [PSCustomObject]@{
            Name      = $svc.Name
            DisplayName = $svc.DisplayName
            StartType = $svc.StartType.ToString()
            Status    = $svc.Status.ToString()
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
        foreach ($t in $found) {
            $tasks += [PSCustomObject]@{
                TaskPath = $t.TaskPath
                TaskName = $t.TaskName
                State    = $t.State.ToString()
            }
        }
    }

    # Registry keys (from bloat-database)
    Write-Progress -Activity "Scanning" -Status "Reading registry keys..." -PercentComplete 70
    $registry = @{}
    $bloatDb = Join-Path (Split-Path $PSScriptRoot -Parent) "data" "bloat-database.json"
    if (Test-Path $bloatDb) {
        $db = Get-Content $bloatDb -Raw | ConvertFrom-Json
        foreach ($entry in $db.registry) {
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
    }

    # Metrics
    Write-Progress -Activity "Scanning" -Status "Measuring system metrics..." -PercentComplete 85
    $processCount = (Get-Process -ErrorAction SilentlyContinue).Count
    $idleRamMB = 0
    $totalRam = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory
    if ($totalRam) {
        $idleRamMB = [math]::Round(($totalRam - (Get-Process -ErrorAction SilentlyContinue | Measure-Object -Property WorkingSet64 -Sum).Sum) / 1MB)
    }

    Write-Progress -Activity "Scanning" -Status "Done" -PercentComplete 100 -Completed

    return [PSCustomObject]@{
        Timestamp     = $timestamp
        WindowsBuild  = [Environment]::OSVersion.Version.Build
        Packages      = $packages
        Services      = $services
        Tasks         = $tasks
        Registry      = $registry
        Metrics       = [PSCustomObject]@{
            IdleRamMB      = $idleRamMB
            ProcessCount   = $processCount
            BootTimeSeconds = $null
        }
    }
}
