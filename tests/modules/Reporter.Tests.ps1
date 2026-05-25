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
    }
}
