Describe 'Reporter module' {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
        Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }

        $script:RealDbPath = Join-Path (Join-Path $PSScriptRoot "..\..\src\data") "bloat-database.json"
        $script:RealDb = Get-Content $script:RealDbPath -Raw | ConvertFrom-Json
    }

    Context 'Get-Score with real bloat-database IDs' {
        It 'all profile tweak IDs exist in bloat-database' {
            $profilesDir = Join-Path $PSScriptRoot "..\..\src\profiles"
            $profileFiles = Get-ChildItem "$profilesDir\*.json"

            $allTweakIds = @{}
            foreach ($f in $profileFiles) {
                $profile = Get-Content $f.FullName -Raw | ConvertFrom-Json
                if ($profile.tweaks) {
                    foreach ($id in $profile.tweaks) {
                        $allTweakIds[$id] = $true
                    }
                }
            }

            $dbIds = @{}
            foreach ($p in $script:RealDb.packages) { $dbIds[$p.id] = $true }
            foreach ($s in $script:RealDb.services) { $dbIds[$s.id] = $true }
            foreach ($t in $script:RealDb.tasks) { $dbIds[$t.id] = $true }
            foreach ($r in $script:RealDb.registry) { $dbIds[$r.id] = $true }
            foreach ($c in $script:RealDb.commands) { $dbIds[$c.id] = $true }

            $missing = $allTweakIds.Keys | Where-Object { -not $dbIds.ContainsKey($_) }
            $missing | Should BeNullOrEmpty
        }
    }

    Context 'Get-Score' {
        BeforeEach {
            $script:Snapshot = [PSCustomObject]@{
                Packages = @(
                    [PSCustomObject]@{ Name='Microsoft.BingNews'; PackageFullName='Microsoft.BingNews_8wekyb3d8bbwe'; Publisher='CN=Microsoft'; InstallLocation='C:\Program Files' }
                )
                Services = @(
                    [PSCustomObject]@{ Name='DiagTrack'; DisplayName='DiagTrack'; StartType='Automatic'; Status='Running' }
                )
                Tasks    = @()
                Registry = @{}
            }

            $script:TweakIds = @('remove-bing-news', 'disable-telemetry')
            $script:BloatDb = [PSCustomObject]@{
                packages = @(
                    [PSCustomObject]@{ id='remove-bing-news'; name='Microsoft.BingNews' }
                )
                services = @(
                    [PSCustomObject]@{ id='disable-telemetry'; name='DiagTrack' }
                )
                tasks    = @()
                registry = @()
                commands = @()
            }
        }

        It 'returns 100 when no profile items are present on system' {
            $emptySnapshot = [PSCustomObject]@{
                Packages = @()
                Services = @()
                Tasks    = @()
                Registry = @{}
            }

            $result = Get-Score -Snapshot $emptySnapshot -TweakIds $script:TweakIds -BloatDatabase $script:BloatDb
            $result.Score | Should Be 100
            $result.Present | Should Be 0
            $result.Removed | Should Be 2
        }

        It 'returns 0 when all profile items are still present' {
            $result = Get-Score -Snapshot $script:Snapshot -TweakIds $script:TweakIds -BloatDatabase $script:BloatDb
            $result.Score | Should Be 0
            $result.Present | Should Be 2
            $result.Removed | Should Be 0
        }

        It 'returns 50 when half of items are present' {
            $halfSnapshot = [PSCustomObject]@{
                Packages = @(
                    [PSCustomObject]@{ Name='Microsoft.BingNews'; PackageFullName='...'; Publisher='...'; InstallLocation='...' }
                )
                Services = @()
                Tasks    = @()
                Registry = @{}
            }

            $result = Get-Score -Snapshot $halfSnapshot -TweakIds $script:TweakIds -BloatDatabase $script:BloatDb
            $result.Score | Should Be 50
            $result.Present | Should Be 1
            $result.Removed | Should Be 1
        }

        It 'returns 100 for empty tweak list' {
            $result = Get-Score -Snapshot $script:Snapshot -TweakIds @() -BloatDatabase $script:BloatDb
            $result.Score | Should Be 100
        }

        It 'returns 100 for null tweak list' {
            $result = Get-Score -Snapshot $script:Snapshot -TweakIds $null -BloatDatabase $script:BloatDb
            $result.Score | Should Be 100
        }

        It 'handles null Packages in snapshot' {
            $nullPkgSnapshot = [PSCustomObject]@{
                Packages = $null
                Services = @(
                    [PSCustomObject]@{ Name='DiagTrack'; DisplayName='DiagTrack'; StartType='Automatic'; Status='Running' }
                )
                Tasks    = @()
                Registry = @{}
            }
            $result = Get-Score -Snapshot $nullPkgSnapshot -TweakIds $script:TweakIds -BloatDatabase $script:BloatDb
            $result.Score | Should Be 50
            $result.Present | Should Be 1
        }

        It 'handles null Services in snapshot' {
            $nullSvcSnapshot = [PSCustomObject]@{
                Packages = @(
                    [PSCustomObject]@{ Name='Microsoft.BingNews'; PackageFullName='...'; Publisher='...'; InstallLocation='...' }
                )
                Services = $null
                Tasks    = @()
                Registry = @{}
            }
            $result = Get-Score -Snapshot $nullSvcSnapshot -TweakIds $script:TweakIds -BloatDatabase $script:BloatDb
            $result.Score | Should Be 50
            $result.Present | Should Be 1
        }

        It 'handles null Tasks in snapshot' {
            $nullTaskSnapshot = [PSCustomObject]@{
                Packages = @()
                Services = @()
                Tasks    = $null
                Registry = @{}
            }
            $result = Get-Score -Snapshot $nullTaskSnapshot -TweakIds @() -BloatDatabase $script:BloatDb
            $result.Score | Should Be 100
        }

        It 'handles null Registry in snapshot' {
            $nullRegSnapshot = [PSCustomObject]@{
                Packages = @()
                Services = @()
                Tasks    = @()
                Registry = $null
            }
            $result = Get-Score -Snapshot $nullRegSnapshot -TweakIds @() -BloatDatabase $script:BloatDb
            $result.Score | Should Be 100
        }

        It 'handles missing sections in BloatDatabase' {
            $minimalDb = [PSCustomObject]@{ packages = @(); services = @(); tasks = @(); registry = @(); commands = @() }
            $result = Get-Score -Snapshot $script:Snapshot -TweakIds $script:TweakIds -BloatDatabase $minimalDb
            $result.Score | Should Be 100
            $result.Present | Should Be 0
        }

        It 'handles BloatDatabase with null sections' {
            $nullSectionDb = [PSCustomObject]@{ packages = $null; services = $null; tasks = $null; registry = $null; commands = $null }
            $result = Get-Score -Snapshot $script:Snapshot -TweakIds $script:TweakIds -BloatDatabase $nullSectionDb
            $result.Score | Should Be 100
            $result.Present | Should Be 0
        }

        It 'returns proper structure for all results' {
            $result = Get-Score -Snapshot $script:Snapshot -TweakIds $script:TweakIds -BloatDatabase $script:BloatDb
            $result.Total   | Should Be 2
            $result.Present | Should Be 2
            $result.Removed | Should Be 0
            $result.Score   | Should Be 0
        }

        It 'handles snapshot without Registry property' {
            $noRegSnapshot = [PSCustomObject]@{
                Packages = @()
                Services = @()
                Tasks    = @()
            }
            $result = Get-Score -Snapshot $noRegSnapshot -TweakIds @() -BloatDatabase $script:BloatDb
            $result.Score | Should Be 100
        }

        It 'handles snapshot without Tasks property' {
            $noTaskSnapshot = [PSCustomObject]@{
                Packages = @()
                Services = @()
                Registry = @{}
            }
            $result = Get-Score -Snapshot $noTaskSnapshot -TweakIds @() -BloatDatabase $script:BloatDb
            $result.Score | Should Be 100
        }
    }

    Context 'Out-ConsoleReport edge cases' {
        $baseSnap = [PSCustomObject]@{ Packages=@(); Services=@(); Tasks=@(); Registry=@{}; WindowsBuild=22621; Metrics=[PSCustomObject]@{ IdleRamMB=0; ProcessCount=0 } }
        $baseScore = [PSCustomObject]@{ Total=0; Present=0; Removed=0; Score=100 }
        $baseProfile = [PSCustomObject]@{ Name='test'; Description='test'; Tweaks=@() }

        It 'does not throw with null Metrics in snapshot' {
            $snap = [PSCustomObject]@{ Packages=@(); Services=@(); Tasks=@(); Registry=@{}; WindowsBuild=22621; Metrics=$null }
            { Out-ConsoleReport -Score $baseScore -Snapshot $snap -Profile $baseProfile -ErrorAction SilentlyContinue } | Should Not Throw
        }

        It 'does not throw with null Changes' {
            { Out-ConsoleReport -Score $baseScore -Snapshot $baseSnap -Profile $baseProfile -Changes $null } | Should Not Throw
        }

        It 'does not throw with empty Profile name' {
            $noNameProfile = [PSCustomObject]@{ Name=$null; Description=''; Tweaks=@() }
            { Out-ConsoleReport -Score $baseScore -Snapshot $baseSnap -Profile $noNameProfile } | Should Not Throw
        }

        It 'does not throw with null Score.Score and Score.Total' {
            $badScore = [PSCustomObject]@{ Total=$null; Present=$null; Removed=$null; Score=$null }
            { Out-ConsoleReport -Score $badScore -Snapshot $baseSnap -Profile $baseProfile -ErrorAction SilentlyContinue } | Should Not Throw
        }

        It 'does not throw with null Snapshot.Packages and Snapshot.Services' {
            $nullPropSnap = [PSCustomObject]@{ Packages=$null; Services=$null; Tasks=$null; Registry=$null; WindowsBuild=22621; Metrics=[PSCustomObject]@{ IdleRamMB=0; ProcessCount=0 } }
            { Out-ConsoleReport -Score $baseScore -Snapshot $nullPropSnap -Profile $baseProfile -ErrorAction SilentlyContinue } | Should Not Throw
        }
    }

    Context 'Out-HtmlReport edge cases' {
        $baseSnap = [PSCustomObject]@{ Packages=@(); Services=@(); Tasks=@(); Registry=@{}; WindowsBuild=22621; Metrics=[PSCustomObject]@{ IdleRamMB=0; ProcessCount=0 } }
        $baseScore = [PSCustomObject]@{ Total=0; Present=0; Removed=0; Score=100 }
        $baseProfile = [PSCustomObject]@{ Name='test'; Description='test'; Tweaks=@() }

        It 'does not throw with null Metrics in snapshot' {
            $snap = [PSCustomObject]@{ Packages=@(); Services=@(); Tasks=@(); Registry=@{}; WindowsBuild=22621; Metrics=$null }
            { Out-HtmlReport -Score $baseScore -Snapshot $snap -Profile $baseProfile } | Should Not Throw
        }

        It 'does not throw with null Changes' {
            { Out-HtmlReport -Score $baseScore -Snapshot $baseSnap -Profile $baseProfile -Changes $null } | Should Not Throw
        }

        It 'does not throw with empty Profile name' {
            $noNameProfile = [PSCustomObject]@{ Name=$null; Description=''; Tweaks=@() }
            { Out-HtmlReport -Score $baseScore -Snapshot $baseSnap -Profile $noNameProfile } | Should Not Throw
        }

        It 'does not throw with null Score.Score and Score.Total' {
            $badScore = [PSCustomObject]@{ Total=$null; Present=$null; Removed=$null; Score=$null }
            { Out-HtmlReport -Score $badScore -Snapshot $baseSnap -Profile $baseProfile } | Should Not Throw
        }

        It 'does not throw with null Snapshot.Packages and Snapshot.Services' {
            $nullPropSnap = [PSCustomObject]@{ Packages=$null; Services=$null; Tasks=$null; Registry=$null; WindowsBuild=22621; Metrics=[PSCustomObject]@{ IdleRamMB=0; ProcessCount=0 } }
            { Out-HtmlReport -Score $baseScore -Snapshot $nullPropSnap -Profile $baseProfile } | Should Not Throw
        }

        It 'returns valid HTML string' {
            $html = Out-HtmlReport -Score $baseScore -Snapshot $baseSnap -Profile $baseProfile
            $html | Should Match '<!DOCTYPE html>'
            $html | Should Match '</html>'
        }
    }
}
