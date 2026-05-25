Describe 'TweaksEngine module' {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
        Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }
    }

    Context 'Invoke-TweakGeneric idempotent guards' {
        It 'skips package already removed without error' {
            $tweak = [PSCustomObject]@{ TweakId = 'test-pkg'; Type = 'package'; Name = 'Does.Not.Exist*'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Remove-AppxPackage { }
            { Invoke-TweakGeneric -Tweak $tweak -Snapshot $snap } | Should Not Throw
            Assert-MockCalled Remove-AppxPackage -Times 0
        }

        It 'skips service already disabled without error' {
            $tweak = [PSCustomObject]@{ TweakId = 'test-svc'; Type = 'service'; Name = 'TestSvc'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Service { return [PSCustomObject]@{ Name = 'TestSvc'; Status = 'Stopped'; StartType = 'Disabled' } }
            Mock Set-Service { }
            Mock Stop-Service { }
            { Invoke-TweakGeneric -Tweak $tweak -Snapshot $snap } | Should Not Throw
            Assert-MockCalled Set-Service -Times 0
            Assert-MockCalled Stop-Service -Times 0
        }

        It 'skips service not found without error' {
            $tweak = [PSCustomObject]@{ TweakId = 'test-svc'; Type = 'service'; Name = 'NonExistentSvc'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Service { return $null }
            { Invoke-TweakGeneric -Tweak $tweak -Snapshot $snap } | Should Not Throw
        }

        It 'skips task already disabled without error' {
            $tweak = [PSCustomObject]@{ TweakId = 'test-task'; Type = 'task'; Name = 'TestTask'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-ScheduledTask { return @([PSCustomObject]@{ TaskName = 'TestTask'; TaskPath = '\'; State = 'Disabled' }) }
            Mock Disable-ScheduledTask { }
            { Invoke-TweakGeneric -Tweak $tweak -Snapshot $snap } | Should Not Throw
            Assert-MockCalled Disable-ScheduledTask -Times 0
        }

        It 'skips task not found without error' {
            $tweak = [PSCustomObject]@{ TweakId = 'test-task'; Type = 'task'; Name = 'NonExistentTask'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-ScheduledTask { return @() }
            { Invoke-TweakGeneric -Tweak $tweak -Snapshot $snap } | Should Not Throw
        }

        It 'skips registry value already set to 0 without error' {
            $tweak = [PSCustomObject]@{ TweakId = 'test-reg'; Type = 'registry'; Name = 'HKLM\Software\Test\Value'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-ItemProperty { return [PSCustomObject]@{ Value = 0 } }
            Mock Set-ItemProperty { }
            Mock Test-Path { return $true }
            { Invoke-TweakGeneric -Tweak $tweak -Snapshot $snap } | Should Not Throw
            Assert-MockCalled Set-ItemProperty -Times 0
        }
    }

    Context 'Invoke-TweaksEngine backup timing' {
        It 'returns backup=$null when no tweaks pending' {
            $profile = @{ Name = 'test'; Tweaks = @('test-tweak'); Dangerous = $false }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-tweak", "type": "package", "name": "NotInstalledPkg*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [] }' }

            $result = Invoke-TweaksEngine -ProfileName 'test' -Snapshot $snap -Dangerous

            $result.Backup | Should Be $null
            $result.Changes.Count | Should Be 0
        }
    }

    Context 'Read-OriginalValue type-specific capture' {
        It 'service returns hashtable with StartType and Status' {
            $tweak = [PSCustomObject]@{ TweakId = 'test-svc'; Type = 'service'; Name = 'TestSvc'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-CimInstance { return [PSCustomObject]@{ StartMode = 'Automatic'; Status = 'Running' } }

            $result = Read-OriginalValue -Tweak $tweak -Snapshot $snap

            $result -is [hashtable] | Should Be $true
            $result.StartType | Should Be 'Automatic'
            $result.Status | Should Be 'Running'
        }

        It 'task returns state string' {
            $tweak = [PSCustomObject]@{ TweakId = 'test-task'; Type = 'task'; Name = 'TestTask'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-ScheduledTask { return @([PSCustomObject]@{ TaskName = 'TestTask'; TaskPath = '\'; State = 'Ready' }) }

            $result = Read-OriginalValue -Tweak $tweak -Snapshot $snap

            $result | Should Be 'Ready'
        }

        It 'command returns enabled when Test-CommandDetected returns true' {
            $tweak = [PSCustomObject]@{ TweakId = 'disable-hibernation'; Type = 'command'; Name = 'Hibernation'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Test-CommandDetected { return $true }

            $result = Read-OriginalValue -Tweak $tweak -Snapshot $snap

            $result | Should Be 'enabled'
        }

        It 'command returns disabled when Test-CommandDetected returns false' {
            $tweak = [PSCustomObject]@{ TweakId = 'disable-hibernation'; Type = 'command'; Name = 'Hibernation'; Entry = $null }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Test-CommandDetected { return $false }

            $result = Read-OriginalValue -Tweak $tweak -Snapshot $snap

            $result | Should Be 'disabled'
        }
    }

    Context 'Detection after scoping fix' {
        It 'finds 1 pending package with name wildcard matching' {
            $profile = @{ Name = 'test'; Tweaks = @('test-tweak'); Dangerous = $false }
            $snap = [PSCustomObject]@{ Packages = @([PSCustomObject]@{ Name = 'BloatPkg_1.0' }); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-tweak", "type": "package", "name": "BloatPkg*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [] }' }
            Mock Read-OriginalValue { return 'test-pkg' }
            Mock New-Backup { return [PSCustomObject]@{ Session = 'test'; BackupDir = 'C:\tmp'; ManifestPath = 'C:\tmp\manifest.json' } }
            Mock Invoke-TweakGeneric { }
            Mock Set-Content { }

            $result = Invoke-TweaksEngine -ProfileName 'test' -Snapshot $snap -Dangerous

            $result.Changes.Count | Should Be 1
        }
    }

    Context 'Flag behavior' {
        It 'WhatIf returns early with empty changes' {
            $profile = @{ Name = 'test'; Tweaks = @('test-tweak'); Dangerous = $false }
            $snap = [PSCustomObject]@{ Packages = @([PSCustomObject]@{ Name = 'BloatPkg_1.0' }); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-tweak", "type": "package", "name": "BloatPkg*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [] }' }
            Mock Write-Host { }

            $result = Invoke-TweaksEngine -ProfileName 'test' -Snapshot $snap -WhatIf -Dangerous

            $result.Changes.Count | Should Be 0
            $result.Backup | Should Be $null
        }

        It 'StopOnError re-throws on tweak failure' {
            $profile = @{ Name = 'test'; Tweaks = @('test-tweak'); Dangerous = $false }
            $snap = [PSCustomObject]@{ Packages = @([PSCustomObject]@{ Name = 'BloatPkg_1.0' }); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-tweak", "type": "package", "name": "BloatPkg*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [] }' }
            Mock Read-OriginalValue { return 'test-pkg' }
            Mock New-Backup { return [PSCustomObject]@{ Session = 'test'; BackupDir = 'C:\tmp'; ManifestPath = 'C:\tmp\manifest.json' } }
            Mock Invoke-TweakGeneric { throw "Simulated failure" }
            Mock Set-Content { }

            { Invoke-TweaksEngine -ProfileName 'test' -Snapshot $snap -StopOnError -Dangerous } | Should Throw
        }

        It 'without StopOnError continues after tweak failure' {
            $profile = @{ Name = 'test'; Tweaks = @('test-tweak', 'test-tweak-2'); Dangerous = $false }
            $snap = [PSCustomObject]@{ Packages = @([PSCustomObject]@{ Name = 'BloatPkg_1.0' }, [PSCustomObject]@{ Name = 'OtherPkg' }); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-tweak", "type": "package", "name": "BloatPkg*", "detect": "mock", "buildMin": 0, "buildMax": 0}, {"id": "test-tweak-2", "type": "package", "name": "OtherPkg*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [], "Changes": [] }' }
            Mock Read-OriginalValue { return 'test-pkg' }
            Mock New-Backup { return [PSCustomObject]@{ Session = 'test'; BackupDir = 'C:\tmp'; ManifestPath = 'C:\tmp\manifest.json' } }
            Mock Set-Content { }
            $callState = @{ Count = 0 }
            Mock Invoke-TweakGeneric {
                $callState.Count++
                if ($callState.Count -eq 1) { throw "First fails" }
            }

            $result = Invoke-TweaksEngine -ProfileName 'test' -Snapshot $snap -Dangerous

            $result.Changes.Count | Should Be 2
            $result.Changes[0].Success | Should Be $false
            $result.Changes[0].Error | Should Be 'First fails'
            $result.Changes[1].Success | Should Be $true
        }
    }

    Context 'Partial failure edge cases' {
        It 'all items fail without StopOnError - errors and backup captured' {
            $profile = @{ Name = 'test'; Tweaks = @('test-a', 'test-b'); Dangerous = $false }
            $snap = [PSCustomObject]@{ Packages = @([PSCustomObject]@{ Name = 'PkgA' }, [PSCustomObject]@{ Name = 'PkgB' }); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-a", "type": "package", "name": "PkgA*", "detect": "mock", "buildMin": 0, "buildMax": 0}, {"id": "test-b", "type": "package", "name": "PkgB*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [], "Changes": [] }' }
            Mock Read-OriginalValue { return 'pkg' }
            Mock New-Backup { return [PSCustomObject]@{ Session = 'test'; BackupDir = 'C:\tmp'; ManifestPath = 'C:\tmp\manifest.json' } }
            Mock Invoke-TweakGeneric { throw "Fail $_" }
            Mock Set-Content { }

            $result = Invoke-TweaksEngine -ProfileName 'test' -Snapshot $snap -Dangerous

            $result.Changes.Count | Should Be 2
            $result.Changes[0].Success | Should Be $false
            $result.Changes[1].Success | Should Be $false
            $result.Backup | Should Not Be $null
        }

        It 'StopOnError with single item - backup created before throw' {
            $profile = @{ Name = 'test'; Tweaks = @('test-tweak'); Dangerous = $false }
            $snap = [PSCustomObject]@{ Packages = @([PSCustomObject]@{ Name = 'BloatPkg_1.0' }); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-tweak", "type": "package", "name": "BloatPkg*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [] }' }
            Mock Read-OriginalValue { return 'test-pkg' }
            Mock New-Backup { return [PSCustomObject]@{ Session = 'test'; BackupDir = 'C:\tmp'; ManifestPath = 'C:\tmp\manifest.json' } }

            $backupCreated = $false
            Mock Invoke-TweakGeneric { $script:backupCreated = $true; throw "fail" }
            Mock Set-Content { }

            try { Invoke-TweaksEngine -ProfileName 'test' -Snapshot $snap -StopOnError -Dangerous } catch { }

            Assert-MockCalled New-Backup -Times 1
        }

        It 'no pending items with StopOnError does not throw' {
            $profile = @{ Name = 'test'; Tweaks = @('test-tweak'); Dangerous = $false }
            $snap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-tweak", "type": "package", "name": "NotInstalled*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [] }' }

            $result = Invoke-TweaksEngine -ProfileName 'test' -Snapshot $snap -StopOnError -Dangerous

            $result.Changes.Count | Should Be 0
        }
    }

    Context 'Second Apply idempotency' {
        It 'returns 0 changes when snapshot has no pending items' {
            $profile = @{ Name = 'test'; Tweaks = @('test-tweak'); Dangerous = $false }
            Mock Get-Profile { return $profile }
            Mock Get-Content { return '{ "version": 1, "updated": "2026-01-01", "packages": [{"id": "test-tweak", "type": "package", "name": "BloatPkg*", "detect": "mock", "buildMin": 0, "buildMax": 0}], "services": [], "tasks": [], "registry": [], "commands": [] }' }

            $cleanSnap = [PSCustomObject]@{ Packages = @(); Services = @(); Tasks = @(); Registry = @{}; Metrics = $null }
            $result = Invoke-TweaksEngine -ProfileName 'test' -Snapshot $cleanSnap -Dangerous

            $result.Changes.Count | Should Be 0
            $result.Backup | Should Be $null
        }
    }
}
