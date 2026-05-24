Describe 'Module loading' {
    It 'all modules dot-source without errors' {
        $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
        $files = Get-ChildItem "$moduleRoot\*.ps1"
        $errors = @()
        foreach ($f in $files) {
            try {
                . $f.FullName
            } catch {
                $errors += "$($f.Name): $_"
            }
        }
        $errors | Should -BeNullOrEmpty
    }

    It 'exports all required functions' {
        $expected = @(
            'Get-ProfilePath',
            'Get-Profile',
            'Resolve-ProfileInheritance',
            'Get-AvailableProfiles',
            'Invoke-Scanner',
            'Get-BackupPath',
            'New-SessionTimestamp',
            'New-Backup',
            'Restore-Backup',
            'Invoke-TweaksEngine',
            'Invoke-TweakGeneric',
            'Read-OriginalValue',
            'Test-CommandDetected',
            'Get-Score',
            'Out-ConsoleReport',
            'Out-HtmlReport'
        )

        foreach ($func in $expected) {
            (Get-Command $func -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        }
    }
}
