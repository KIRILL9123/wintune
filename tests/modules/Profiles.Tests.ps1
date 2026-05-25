Describe 'Profiles module' {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
        Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }
    }

    Context 'Get-ProfilePath' {
        It 'returns a valid directory path' {
            $path = Get-ProfilePath
            Test-Path $path | Should Be $true
        }
    }

    Context 'Get-Profile' {
        It 'loads base profile without inheritance' {
            $profile = Get-Profile -Name 'base'
            $profile.Name | Should Be 'base'
            $profile.Tweaks.Count | Should BeGreaterThan 0
        }

        It 'loads gaming profile inheriting from base' {
            $profile = Get-Profile -Name 'gaming'
            $profile.Name | Should Be 'gaming'
            $profile.Tweaks.Count | Should BeGreaterThan 2
        }

        It 'throws for non-existent profile' {
            { Get-Profile -Name 'nonexistent' } | Should Throw
        }

        It 'preserve excludes inherited tweaks' {
            $workstation = Get-Profile -Name 'workstation'

            ($workstation.Tweaks -contains 'remove-teams') | Should Be $false
            ($workstation.Tweaks -contains 'remove-bing-news') | Should Be $true
            ($workstation.Tweaks -contains 'disable-telemetry') | Should Be $true
        }

        It 'inherits tweaks into child profiles' {
            $base = Get-Profile -Name 'base'
            $laptop = Get-Profile -Name 'laptop'

            foreach ($tweak in $base.Tweaks) {
                ($laptop.Tweaks -contains $tweak) | Should Be $true
            }
        }
    }

    Context 'Get-AvailableProfiles' {
        It 'returns at least base profile' {
            $profiles = Get-AvailableProfiles
            $baseProfile = $profiles | Where-Object { $_.Name -eq 'base' }
            $baseProfile | Should Not BeNullOrEmpty
        }

        It 'returns all 5 profiles' {
            $profiles = Get-AvailableProfiles
            $profiles.Count | Should Be 5
        }
    }
}
