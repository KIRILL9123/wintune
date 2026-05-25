Describe 'Scanner module' {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
        Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }
    }

    Context 'Invoke-Scanner structure' {
        It 'returns a snapshot with all required top-level properties' {
            $snap = Invoke-Scanner
            $snap.Timestamp     | Should Not BeNullOrEmpty
            $snap.WindowsBuild  | Should BeGreaterThan 0
            $snap.Packages      | Should Not Be $null
            $snap.Services      | Should Not Be $null
            $snap.Tasks         | Should Not Be $null
            $snap.Registry      | Should Not Be $null
            $snap.Metrics       | Should Not Be $null
        }

        It 'Packages, Services, Tasks are always arrays' {
            $snap = Invoke-Scanner
            $snap.Packages -is [array] | Should Be $true
            $snap.Services -is [array] | Should Be $true
            $snap.Tasks -is [array]    | Should Be $true
        }

        It 'Metrics has IdleRamMB, ProcessCount, BootTimeSeconds' {
            $snap = Invoke-Scanner
            $snap.Metrics.IdleRamMB        | Should Not Be $null
            $snap.Metrics.ProcessCount     | Should BeGreaterThan 0
            $snap.Metrics.BootTimeSeconds  | Should Be $null
        }

        It 'each package has Name, PackageFullName, Publisher, InstallLocation' {
            $snap = Invoke-Scanner
            foreach ($pkg in $snap.Packages) {
                $pkg.Name            | Should Not BeNullOrEmpty
                $pkg.PackageFullName | Should Not BeNullOrEmpty
                $pkg.Publisher       | Should Not BeNullOrEmpty
                $pkg.InstallLocation | Should Not BeNullOrEmpty
            }
        }

        It 'each service has Name, DisplayName, StartType, Status' {
            $snap = Invoke-Scanner
            foreach ($svc in $snap.Services) {
                $svc.Name        | Should Not BeNullOrEmpty
                $svc.DisplayName | Should Not BeNullOrEmpty
                ($svc.Status -eq 'Running' -or $svc.Status -eq 'Stopped') | Should Be $true
            }
        }

        It 'Timestamp is ISO 8601 parseable' {
            $snap = Invoke-Scanner
            { [datetime]::Parse($snap.Timestamp) } | Should Not Throw
        }
    }

    Context 'Invoke-Scanner edge cases' {
        It 'Registry is always a hashtable' {
            $snap = Invoke-Scanner
            $snap.Registry -is [hashtable] | Should Be $true
        }

        It 'WindowsBuild matches OS version' {
            $snap = Invoke-Scanner
            $snap.WindowsBuild | Should Be ([Environment]::OSVersion.Version.Build)
        }
    }
}
