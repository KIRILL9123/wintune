$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Join-Path $here "..\..\src\modules"
Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }

Describe 'Apply -> Revert integration' {

    Context 'Registry change round-trip' {
        It 'creates backup, reverts registry value, verifies manifest round-trip' {
            Mock Checkpoint-Computer { }
            $tmpDir = Join-Path $env:TEMP "WinTuneInt_$(Get-Random)"
            $env:WINTUNE_BACKUP_PATH = $tmpDir

            $changes = @(
                [PSCustomObject]@{ TweakId = 'reg-test'; Type = 'registry'; Name = 'HKCU\Software\WinTuneTest\MyValue'; OriginalValue = 0; NewValue = 1; Timestamp = (Get-Date).ToString('o'); Success = $true; Error = $null }
            )

            $backup = New-Backup -ProfileName 'integration-test' -Changes $changes

            try {
                $backup.Session | Should Not BeNullOrEmpty
                $backup.ManifestPath | Should Not BeNullOrEmpty
                Test-Path $backup.ManifestPath | Should Be $true

                $manifest = Get-Content $backup.ManifestPath -Raw | ConvertFrom-Json
                @($manifest.Changes).Count | Should Be 1
                @($manifest.Changes)[0].TweakId | Should Be 'reg-test'
                @($manifest.Changes)[0].SequenceNumber | Should Be 1
                @($manifest.Changes)[0].OriginalValue | Should Be 0
                $manifest.Profile | Should Be 'integration-test'
                $manifest.Session | Should Be $backup.Session

                Mock Set-ItemProperty { }
                $results = Restore-Backup -Session $backup.Session
                @($results).Count | Should Be 1
                @($results)[0].TweakId | Should Be 'reg-test'
                @($results)[0].Reverted | Should Be $true
                @($results)[0].Error | Should Be $null
            } finally {
                Remove-Item -Recurse -Force $tmpDir -EA SilentlyContinue
                Remove-Item Env:WINTUNE_BACKUP_PATH -EA SilentlyContinue
            }
        }
    }

    Context 'Service change round-trip' {
        It 'creates backup and reverts Service StartType + Status' {
            Mock Checkpoint-Computer { }
            $tmpDir = Join-Path $env:TEMP "WinTuneInt_$(Get-Random)"
            $env:WINTUNE_BACKUP_PATH = $tmpDir

            $origVal = @{ StartType = 'Automatic'; Status = 'Running' }
            $changes = @(
                [PSCustomObject]@{ TweakId = 'svc-test'; Type = 'service'; Name = 'TestSvc'; OriginalValue = $origVal; NewValue = 'Disabled'; Timestamp = (Get-Date).ToString('o'); Success = $true; Error = $null }
            )

            $backup = New-Backup -ProfileName 'test' -Changes $changes

            try {
                $manifest = Get-Content $backup.ManifestPath -Raw | ConvertFrom-Json
                $manifest.Changes[0].OriginalValue.StartType | Should Be 'Automatic'
                $manifest.Changes[0].OriginalValue.Status | Should Be 'Running'

                Mock Get-Service { return [PSCustomObject]@{ Name = 'TestSvc'; Status = 'Stopped' } }
                Mock Set-Service { }
                Mock Start-Service { }

                $results = Restore-Backup -Session $backup.Session
                $results.Count | Should Be 1
                $results[0].Reverted | Should Be $true
                Assert-MockCalled Set-Service -Times 1
                Assert-MockCalled Start-Service -Times 1
            } finally {
                Remove-Item -Recurse -Force $tmpDir -EA SilentlyContinue
                Remove-Item Env:WINTUNE_BACKUP_PATH -EA SilentlyContinue
            }
        }
    }

    Context 'Multiple changes reverse-order revert' {
        It 'reverts C then B then A when applied as A, B, C' {
            Mock Checkpoint-Computer { }
            $tmpDir = Join-Path $env:TEMP "WinTuneInt_$(Get-Random)"
            $env:WINTUNE_BACKUP_PATH = $tmpDir

            $changes = @(
                [PSCustomObject]@{ TweakId = 'a'; Type = 'registry'; Name = 'HKCU\Test\A'; OriginalValue = 1; NewValue = 0; Timestamp = '2026-01-01'; Success = $true; Error = $null }
                [PSCustomObject]@{ TweakId = 'b'; Type = 'registry'; Name = 'HKCU\Test\B'; OriginalValue = 2; NewValue = 0; Timestamp = '2026-01-01'; Success = $true; Error = $null }
                [PSCustomObject]@{ TweakId = 'c'; Type = 'registry'; Name = 'HKCU\Test\C'; OriginalValue = 3; NewValue = 0; Timestamp = '2026-01-01'; Success = $true; Error = $null }
            )

            $backup = New-Backup -ProfileName 'test' -Changes $changes

            try {
                $manifest = Get-Content $backup.ManifestPath -Raw | ConvertFrom-Json
                $manifest.Changes[0].SequenceNumber | Should Be 1
                $manifest.Changes[1].SequenceNumber | Should Be 2
                $manifest.Changes[2].SequenceNumber | Should Be 3

                Mock Set-ItemProperty { }
                $results = Restore-Backup -Session $backup.Session
                $results.Count | Should Be 3
                $results[0].TweakId | Should Be 'c'
                $results[1].TweakId | Should Be 'b'
                $results[2].TweakId | Should Be 'a'
            } finally {
                Remove-Item -Recurse -Force $tmpDir -EA SilentlyContinue
                Remove-Item Env:WINTUNE_BACKUP_PATH -EA SilentlyContinue
            }
        }
    }

    Context 'Package and command revert warnings' {
        It 'warns on package revert' {
            Mock Checkpoint-Computer { }
            $tmpDir = Join-Path $env:TEMP "WinTuneInt_$(Get-Random)"
            $env:WINTUNE_BACKUP_PATH = $tmpDir

            $changes = @(
                [PSCustomObject]@{ TweakId = 'pkg-test'; Type = 'package'; Name = 'SomePkg'; OriginalValue = $null; NewValue = $null; Timestamp = (Get-Date).ToString('o'); Success = $true; Error = $null }
            )

            $backup = New-Backup -ProfileName 'test' -Changes $changes

            try {
                $results = Restore-Backup -Session $backup.Session
                $results[0].Reverted | Should Be $false
                $results[0].Error | Should Match 'not supported'
            } finally {
                Remove-Item -Recurse -Force $tmpDir -EA SilentlyContinue
                Remove-Item Env:WINTUNE_BACKUP_PATH -EA SilentlyContinue
            }
        }

        It 'warns on command revert' {
            Mock Checkpoint-Computer { }
            $tmpDir = Join-Path $env:TEMP "WinTuneInt_$(Get-Random)"
            $env:WINTUNE_BACKUP_PATH = $tmpDir

            $changes = @(
                [PSCustomObject]@{ TweakId = 'cmd-test'; Type = 'command'; Name = 'Hibernation'; OriginalValue = $null; NewValue = $null; Timestamp = (Get-Date).ToString('o'); Success = $true; Error = $null }
            )

            $backup = New-Backup -ProfileName 'test' -Changes $changes

            try {
                $results = Restore-Backup -Session $backup.Session
                $results[0].Reverted | Should Be $false
                $results[0].Error | Should Match 'not supported'
            } finally {
                Remove-Item -Recurse -Force $tmpDir -EA SilentlyContinue
                Remove-Item Env:WINTUNE_BACKUP_PATH -EA SilentlyContinue
            }
        }
    }

    Context 'Revert after tampered manifest' {
        It 'reports invalid entry and skips it' {
            Mock Checkpoint-Computer { }
            $tmpDir = Join-Path $env:TEMP "WinTuneInt_$(Get-Random)"
            $env:WINTUNE_BACKUP_PATH = $tmpDir

            $changes = @(
                [PSCustomObject]@{ TweakId = 'good'; Type = 'registry'; Name = 'HKCU\Test\Good'; OriginalValue = 1; NewValue = 0; Timestamp = (Get-Date).ToString('o'); Success = $true; Error = $null }
            )

            $backup = New-Backup -ProfileName 'test' -Changes $changes

            try {
                $manifest = Get-Content $backup.ManifestPath -Raw | ConvertFrom-Json
                $bad = [PSCustomObject]@{ Type = 'registry'; Name = 'HKCU\Test\Bad' }
                $tampered = @($manifest.Changes) + $bad
                $manifest.Changes = $tampered
                $manifest | ConvertTo-Json -Depth 10 | Set-Content $backup.ManifestPath -Encoding UTF8

                Mock Set-ItemProperty { }
                Mock Write-Warning { }

                $results = Restore-Backup -Session $backup.Session
                $results.Count | Should Be 2
                $results[0].TweakId | Should Be 'good'
                $results[0].Reverted | Should Be $true
                $results[1].Reverted | Should Be $false
                $results[1].Error | Should Match 'missing TweakId or Type'
            } finally {
                Remove-Item -Recurse -Force $tmpDir -EA SilentlyContinue
                Remove-Item Env:WINTUNE_BACKUP_PATH -EA SilentlyContinue
            }
        }
    }

    Context 'Revert twice on same backup' {
        It 'reports success on second revert' {
            Mock Checkpoint-Computer { }
            $tmpDir = Join-Path $env:TEMP "WinTuneInt_$(Get-Random)"
            $env:WINTUNE_BACKUP_PATH = $tmpDir

            $changes = @(
                [PSCustomObject]@{ TweakId = 'dup'; Type = 'registry'; Name = 'HKCU\Test\Dup'; OriginalValue = 1; NewValue = 0; Timestamp = (Get-Date).ToString('o'); Success = $true; Error = $null }
            )

            $backup = New-Backup -ProfileName 'test' -Changes $changes

            try {
                Mock Set-ItemProperty { }
                $r1 = Restore-Backup -Session $backup.Session
                $r1.Count | Should Be 1
                $r1[0].Reverted | Should Be $true

                $r2 = Restore-Backup -Session $backup.Session
                $r2.Count | Should Be 1
                $r2[0].Reverted | Should Be $true
            } finally {
                Remove-Item -Recurse -Force $tmpDir -EA SilentlyContinue
                Remove-Item Env:WINTUNE_BACKUP_PATH -EA SilentlyContinue
            }
        }
    }

    Context 'Task type round-trip' {
        It 'creates backup and reverts task enable state' {
            Mock Checkpoint-Computer { }
            $tmpDir = Join-Path $env:TEMP "WinTuneInt_$(Get-Random)"
            $env:WINTUNE_BACKUP_PATH = $tmpDir

            $changes = @(
                [PSCustomObject]@{ TweakId = 'task-test'; Type = 'task'; Name = 'TestTask'; OriginalValue = 'Ready'; NewValue = 'Disabled'; Timestamp = (Get-Date).ToString('o'); Success = $true; Error = $null }
            )

            $backup = New-Backup -ProfileName 'test' -Changes $changes

            try {
                Mock Get-ScheduledTask { return @{ TaskName = 'TestTask'; State = 'Disabled' } }
                Mock Enable-ScheduledTask { }

                $results = Restore-Backup -Session $backup.Session
                $results.Count | Should Be 1
                $results[0].Reverted | Should Be $true
                Assert-MockCalled Enable-ScheduledTask -Times 1
            } finally {
                Remove-Item -Recurse -Force $tmpDir -EA SilentlyContinue
                Remove-Item Env:WINTUNE_BACKUP_PATH -EA SilentlyContinue
            }
        }
    }
}
