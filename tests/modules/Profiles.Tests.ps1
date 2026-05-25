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

    Context 'Test-ProfileSchema' {
        It 'passes for a valid profile' {
            $p = [PSCustomObject]@{ name = 'test'; tweaks = @('disable-foo', 'enable-bar') }
            { Test-ProfileSchema -ProfileObj $p -ProfileName 'test' } | Should Not Throw
        }

        It 'passes with all optional fields' {
            $p = [PSCustomObject]@{ name = 'full'; description = 'A full profile'; tweaks = @('disable-foo'); preserve = @('keep-bar'); dangerous = $false; inherits = 'base' }
            { Test-ProfileSchema -ProfileObj $p } | Should Not Throw
        }

        It 'passes with inherits array' {
            $p = [PSCustomObject]@{ name = 'multi'; tweaks = @('disable-foo'); inherits = @('base', 'gaming') }
            { Test-ProfileSchema -ProfileObj $p } | Should Not Throw
        }

        It 'passes with null inherits' {
            $p = [PSCustomObject]@{ name = 'no-parent'; tweaks = @('disable-foo'); inherits = $null }
            { Test-ProfileSchema -ProfileObj $p } | Should Not Throw
        }

        It 'throws on null profile' {
            { Test-ProfileSchema -ProfileObj $null } | Should Throw
        }

        It 'throws on missing name' {
            $p = [PSCustomObject]@{ tweaks = @('disable-foo') }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'throws on empty name' {
            $p = [PSCustomObject]@{ name = ''; tweaks = @('disable-foo') }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'throws on missing tweaks' {
            $p = [PSCustomObject]@{ name = 'test' }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'throws on non-array tweaks' {
            $p = [PSCustomObject]@{ name = 'test'; tweaks = 'just-one-string' }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'throws on empty tweak string' {
            $p = [PSCustomObject]@{ name = 'test'; tweaks = @('') }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'throws on invalid tweak ID pattern' {
            $p = [PSCustomObject]@{ name = 'test'; tweaks = @('UPPERCASE', 'has_underscore', 'has space') }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'throws on non-boolean dangerous' {
            $p = [PSCustomObject]@{ name = 'test'; tweaks = @('disable-foo'); dangerous = 'yes' }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'throws on dangerous=true without description' {
            $p = [PSCustomObject]@{ name = 'danger'; tweaks = @('disable-foo'); dangerous = $true }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'passes on dangerous=true with description' {
            $p = [PSCustomObject]@{ name = 'danger'; description = 'Dangerous tweaks included'; tweaks = @('disable-foo'); dangerous = $true }
            { Test-ProfileSchema -ProfileObj $p } | Should Not Throw
        }

        It 'throws on non-array preserve' {
            $p = [PSCustomObject]@{ name = 'test'; tweaks = @('disable-foo'); preserve = 'not-array' }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }

        It 'throws on invalid inherits type' {
            $p = [PSCustomObject]@{ name = 'test'; tweaks = @('disable-foo'); inherits = 42 }
            { Test-ProfileSchema -ProfileObj $p } | Should Throw
        }
    }
}
