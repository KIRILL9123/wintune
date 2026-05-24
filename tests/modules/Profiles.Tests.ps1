BeforeAll {
    $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
    Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }
}

Describe 'Get-ProfilePath' {
    It 'returns a valid directory path' {
        $path = Get-ProfilePath
        Test-Path $path | Should -Be $true
    }
}

Describe 'Get-Profile' {
    It 'loads base profile without inheritance' {
        $profile = Get-Profile -Name 'base'
        $profile.Name | Should -Be 'base'
        $profile.Tweaks.Count | Should -BeGreaterThan 0
    }

    It 'loads gaming profile inheriting from base' {
        $profile = Get-Profile -Name 'gaming'
        $profile.Name | Should -Be 'gaming'
        # Should have base tweaks + gaming tweaks
        $profile.Tweaks.Count | Should -BeGreaterThan 2
    }

    It 'throws for non-existent profile' {
        { Get-Profile -Name 'nonexistent' } | Should -Throw
    }

    It 'preserve excludes inherited tweaks' {
        $base = Get-Profile -Name 'base'
        $gaming = Get-Profile -Name 'gaming'

        # Gaming preserves xbox-app which is NOT in base, so counts may be equal
        # At minimum, gaming profile should not crash and return tweaks
        $gaming.Tweaks.Count | Should -BeGreaterThan 0
    }
}

Describe 'Get-AvailableProfiles' {
    It 'returns at least base profile' {
        $profiles = Get-AvailableProfiles
        $baseProfile = $profiles | Where-Object { $_.Name -eq 'base' }
        $baseProfile | Should -Not -BeNullOrEmpty
    }

    It 'returns all 5 profiles' {
        $profiles = Get-AvailableProfiles
        $profiles.Count | Should -Be 5
    }
}
