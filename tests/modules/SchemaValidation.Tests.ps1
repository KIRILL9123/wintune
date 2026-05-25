Describe "Schema validation" {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
        Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }
    }

    It "validates bloat database schema via external script" {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        $scriptPath = Join-Path $repoRoot "scripts\Validate-Schemas.ps1"

        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1
        $LASTEXITCODE | Should Be 0
        ($output -join "`n") | Should Match "Schema validation passed"
    }

    Context 'Test-BloatDatabaseSchema' {
        It 'passes for a valid minimal database' {
            $db = [PSCustomObject]@{
                version = 1; updated = '2026-01-01'
                packages = @([PSCustomObject]@{ id = 'pkg-a'; type = 'package'; name = 'TestPkg'; detect = 'Get-AppxPackage TestPkg'; buildMin = 22000; buildMax = 0 })
                services = @()
                tasks = @()
                registry = @()
                commands = @()
            }
            { Test-BloatDatabaseSchema -Database $db } | Should Not Throw
        }

        It 'passes for a full database matching the real one' {
            $db = [PSCustomObject]@{
                version = 2; updated = '2026-05-24'
                packages = @(
                    [PSCustomObject]@{ id = 'remove-bing-news'; type = 'package'; name = 'Microsoft.BingNews'; detect = 'Get-AppxPackage -Name Microsoft.BingNews'; buildMin = 22000; buildMax = 0 }
                    [PSCustomObject]@{ id = 'remove-bing-weather'; type = 'package'; name = 'Microsoft.BingWeather'; detect = 'Get-AppxPackage -Name Microsoft.BingWeather'; buildMin = 22000; buildMax = 0 }
                )
                services = @(
                    [PSCustomObject]@{ id = 'disable-telemetry'; type = 'service'; name = 'DiagTrack'; detect = 'Get-Service -Name DiagTrack'; buildMin = 22000; buildMax = 0 }
                )
                tasks = @(
                    [PSCustomObject]@{ id = 'disable-ceip-task'; type = 'task'; name = 'Consolidator'; detect = 'Get-ScheduledTask'; buildMin = 22000; buildMax = 0 }
                )
                registry = @(
                    [PSCustomObject]@{ id = 'disable-ads-id'; type = 'registry'; name = 'HKCU\Test'; detect = 'Get-ItemProperty'; buildMin = 22000; buildMax = 0 }
                )
                commands = @(
                    [PSCustomObject]@{ id = 'disable-hibernation'; type = 'command'; name = 'Hibernation'; detect = 'powercfg'; buildMin = 22000; buildMax = 0 }
                )
            }
            { Test-BloatDatabaseSchema -Database $db } | Should Not Throw
        }

        It 'throws on null database' {
            { Test-BloatDatabaseSchema -Database $null } | Should Throw
        }

        It 'throws on missing version' {
            $db = [PSCustomObject]@{ updated = '2026-01-01'; packages = @(); services = @(); tasks = @(); registry = @(); commands = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }

        It 'throws on missing required section' {
            $db = [PSCustomObject]@{ version = 1; updated = '2026-01-01'; packages = @(); services = @(); tasks = @(); registry = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }

        It 'throws on version < 1' {
            $db = [PSCustomObject]@{ version = 0; updated = '2026-01-01'; packages = @(); services = @(); tasks = @(); registry = @(); commands = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }

        It 'throws on non-integer version' {
            $db = [PSCustomObject]@{ version = 'two'; updated = '2026-01-01'; packages = @(); services = @(); tasks = @(); registry = @(); commands = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }

        It 'throws on missing entry id' {
            $db = [PSCustomObject]@{ version = 1; updated = '2026-01-01'; packages = @([PSCustomObject]@{ type = 'package'; name = 'Test'; detect = 'x'; buildMin = 0; buildMax = 0 }); services = @(); tasks = @(); registry = @(); commands = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }

        It 'throws on missing entry buildMin' {
            $db = [PSCustomObject]@{ version = 1; updated = '2026-01-01'; packages = @([PSCustomObject]@{ id = 'x'; type = 'package'; name = 'Test'; detect = 'x'; buildMax = 0 }); services = @(); tasks = @(); registry = @(); commands = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }

        It 'throws on entry type mismatch' {
            $db = [PSCustomObject]@{ version = 1; updated = '2026-01-01'; packages = @([PSCustomObject]@{ id = 'x'; type = 'service'; name = 'Test'; detect = 'x'; buildMin = 0; buildMax = 0 }); services = @(); tasks = @(); registry = @(); commands = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }

        It 'throws on duplicate id across sections' {
            $db = [PSCustomObject]@{ version = 1; updated = '2026-01-01'; packages = @([PSCustomObject]@{ id = 'dup'; type = 'package'; name = 'Test1'; detect = 'x'; buildMin = 0; buildMax = 0 }); services = @([PSCustomObject]@{ id = 'dup'; type = 'service'; name = 'Test2'; detect = 'x'; buildMin = 0; buildMax = 0 }); tasks = @(); registry = @(); commands = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }

        It 'throws on invalid type enum' {
            $db = [PSCustomObject]@{ version = 1; updated = '2026-01-01'; packages = @([PSCustomObject]@{ id = 'x'; type = 'widget'; name = 'Test'; detect = 'x'; buildMin = 0; buildMax = 0 }); services = @(); tasks = @(); registry = @(); commands = @() }
            { Test-BloatDatabaseSchema -Database $db } | Should Throw
        }
    }
}
