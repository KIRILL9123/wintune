BeforeAll {
    $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
    Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }
}

Describe 'Get-Score' {
    It 'returns 100 when no items are present' {
        $snapshot = [PSCustomObject]@{
            Packages = @()
            Services = @()
            Tasks    = @()
            Registry = @{}
        }
        $tweakIds = @('remove-bing-news', 'disable-telemetry')
        $bloatDb = [PSCustomObject]@{
            packages = @(
                [PSCustomObject]@{ id='remove-bing-news'; name='Microsoft.BingNews' }
            )
            services = @(
                [PSCustomObject]@{ id='disable-telemetry'; name='DiagTrack' }
            )
            tasks    = @()
            registry = @()
        }

        $result = Get-Score -Snapshot $snapshot -TweakIds $tweakIds -BloatDatabase $bloatDb
        $result.Score | Should -Be 100
        $result.Present | Should -Be 0
        $result.Removed | Should -Be 2
    }

    It 'returns 0 when all items are present' {
        $snapshot = [PSCustomObject]@{
            Packages = @(
                [PSCustomObject]@{ Name='Microsoft.BingNews'; PackageFullName='...'; Publisher='...'; InstallLocation='...' }
            )
            Services = @(
                [PSCustomObject]@{ Name='DiagTrack'; DisplayName='DiagTrack'; StartType='Automatic'; Status='Running' }
            )
            Tasks    = @()
            Registry = @{}
        }
        $tweakIds = @('remove-bing-news', 'disable-telemetry')
        $bloatDb = [PSCustomObject]@{
            packages = @(
                [PSCustomObject]@{ id='remove-bing-news'; name='Microsoft.BingNews' }
            )
            services = @(
                [PSCustomObject]@{ id='disable-telemetry'; name='DiagTrack' }
            )
            tasks    = @()
            registry = @()
        }

        $result = Get-Score -Snapshot $snapshot -TweakIds $tweakIds -BloatDatabase $bloatDb
        $result.Score | Should -Be 0
        $result.Present | Should -Be 2
        $result.Removed | Should -Be 0
    }

    It 'handles partial results' {
        $snapshot = [PSCustomObject]@{
            Packages = @(
                [PSCustomObject]@{ Name='Microsoft.BingNews'; PackageFullName='...'; Publisher='...'; InstallLocation='...' }
            )
            Services = @()
            Tasks    = @()
            Registry = @{}
        }
        $tweakIds = @('remove-bing-news', 'disable-telemetry')
        $bloatDb = [PSCustomObject]@{
            packages = @(
                [PSCustomObject]@{ id='remove-bing-news'; name='Microsoft.BingNews' }
            )
            services = @(
                [PSCustomObject]@{ id='disable-telemetry'; name='DiagTrack' }
            )
            tasks    = @()
            registry = @()
        }

        $result = Get-Score -Snapshot $snapshot -TweakIds $tweakIds -BloatDatabase $bloatDb
        $result.Score | Should -Be 50
        $result.Present | Should -Be 1
        $result.Removed | Should -Be 1
    }

    It 'returns 100 for empty tweak list' {
        $snapshot = [PSCustomObject]@{
            Packages = @()
            Services = @()
            Tasks    = @()
            Registry = @{}
        }
        $result = Get-Score -Snapshot $snapshot -TweakIds @() -BloatDatabase ([PSCustomObject]@{ packages=@(); services=@(); tasks=@(); registry=@() })
        $result.Score | Should -Be 100
    }
}
