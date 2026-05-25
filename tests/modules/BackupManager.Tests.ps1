Describe 'BackupManager module' {
    BeforeAll {
        $moduleRoot = Join-Path $PSScriptRoot "..\..\src\modules"
        Get-ChildItem "$moduleRoot\*.ps1" | ForEach-Object { . $_.FullName }
    }

    Context 'New-Backup manifest structure' {
        $c1 = @([PSCustomObject]@{ TweakId = 'a'; Type = 'registry'; Name = 'HKLM\Test\Val'; OriginalValue = 1; NewValue = 0; Timestamp = '2026-01-01'; Success = $true; Error = $null })
        $c2 = @([PSCustomObject]@{ TweakId = 'a'; Type = 'registry'; Name = 'HKLM\Test\A'; OriginalValue = 1; NewValue = 0; Timestamp = '2026-01-01'; Success = $true; Error = $null },
                 [PSCustomObject]@{ TweakId = 'b'; Type = 'service'; Name = 'TestSvc'; OriginalValue = 'Automatic'; NewValue = 'Disabled'; Timestamp = '2026-01-01'; Success = $true; Error = $null })

        It 'includes SequenceNumber' {
            Mock Write-Warning { }; Mock Checkpoint-Computer { }
            Mock New-Item { [PSCustomObject]@{ FullName = 'C:\tmp' } }
            Mock Set-Content { }
            $r = New-Backup -ProfileName 'test' -Changes $c1
            $r.ManifestPath | Should Not BeNullOrEmpty
        }

        It 'SequenceNumber increments' {
            Mock Write-Warning { }; Mock Checkpoint-Computer { }
            Mock New-Item { [PSCustomObject]@{ FullName = 'C:\tmp' } }
            Mock Set-Content { $script:j = $Value }
            New-Backup -ProfileName 'test' -Changes $c2
            $p = $script:j | ConvertFrom-Json
            $p.Changes.Count | Should Be 2
            $p.Changes[0].SequenceNumber | Should Be 1
            $p.Changes[1].SequenceNumber | Should Be 2
        }

        It 'includes Session, Profile, CreatedAt' {
            Mock Write-Warning { }; Mock Checkpoint-Computer { }
            Mock New-Item { [PSCustomObject]@{ FullName = 'C:\tmp' } }
            Mock Set-Content { $script:j2 = $Value }
            New-Backup -ProfileName 'test-profile' -Changes $c1
            $p = $script:j2 | ConvertFrom-Json
            $p.Session | Should Not BeNullOrEmpty
            $p.Profile | Should Be 'test-profile'
            $p.CreatedAt | Should Not BeNullOrEmpty
        }
    }

    Context 'Restore-Backup startup validation' {
        It 'throws on missing backup dir' {
            Mock Get-BackupPath { 'C:\tmp\nope' }
            Mock Test-Path { $false }
            { Restore-Backup -Session 'bad' } | Should Throw
        }

        It 'throws when manifest file read fails' {
            Mock Get-BackupPath { 'C:\tmp\x' }
            Mock Test-Path { $true }
            Mock Get-Content { throw "File not found" }
            { Restore-Backup -Session 'x' } | Should Throw
        }
    }

    Context 'Restore-Backup manifest validation' {
        BeforeEach {
            Mock Get-BackupPath { 'C:\tmp\x' }
            Mock Test-Path { $true }
            Mock Write-Warning { }
        }

        It 'throws on malformed JSON' {
            Mock Get-Content { '{{{bad' }
            { Restore-Backup -Session 'x' } | Should Throw
        }

        It 'returns empty on empty Changes' {
            Mock Get-Content { '{ "Session":"t","Profile":"t","Changes":[] }' }
            $r = Restore-Backup -Session 'x'
            $r.Count | Should Be 0
        }

        It 'flags missing TweakId' {
            Mock Get-Content { '{ "Session":"t","Profile":"t","Changes":[{"Type":"registry","Name":"HKLM\\Test"}] }' }
            $r = Restore-Backup -Session 'x'
            $r.Count | Should Be 1
            $r[0].Reverted | Should Be $false
            $r[0].Error | Should Match 'missing TweakId or Type'
        }

        It 'flags missing OriginalValue for registry' {
            Mock Get-Content { '{ "Session":"t","Profile":"t","Changes":[{"TweakId":"x","Type":"registry","Name":"HKLM\\Test"}] }' }
            $r = Restore-Backup -Session 'x'
            $r.Count | Should Be 1
            $r[0].Reverted | Should Be $false
            $r[0].Error | Should Match 'Missing OriginalValue'
        }
    }

    Context 'Restore-Backup reverse order' {
        It 'sorts by SequenceNumber descending' {
            Mock Get-BackupPath { 'C:\tmp\x' }; Mock Test-Path { $true }
            Mock Get-Content { '{ "Session":"t","Profile":"t","Changes":[{"SequenceNumber":1,"TweakId":"a","Type":"registry","Name":"HKLM\\Test\\A","OriginalValue":1},{"SequenceNumber":2,"TweakId":"b","Type":"registry","Name":"HKLM\\Test\\B","OriginalValue":2},{"SequenceNumber":3,"TweakId":"c","Type":"registry","Name":"HKLM\\Test\\C","OriginalValue":3}] }' }
            Mock Set-ItemProperty { }
            $r = Restore-Backup -Session 'x'
            $r.Count | Should Be 3
            $r[0].TweakId | Should Be 'c'
            $r[1].TweakId | Should Be 'b'
            $r[2].TweakId | Should Be 'a'
        }

        It 'falls back to Timestamp' {
            Mock Get-BackupPath { 'C:\tmp\x' }; Mock Test-Path { $true }
            Mock Get-Content { '{ "Session":"t","Profile":"t","Changes":[{"TweakId":"a","Type":"registry","Name":"HKLM\\Test\\A","OriginalValue":1,"Timestamp":"2026-01-01T10:00:01"},{"TweakId":"b","Type":"registry","Name":"HKLM\\Test\\B","OriginalValue":2,"Timestamp":"2026-01-01T10:00:02"},{"TweakId":"c","Type":"registry","Name":"HKLM\\Test\\C","OriginalValue":3,"Timestamp":"2026-01-01T10:00:03"}] }' }
            Mock Set-ItemProperty { }
            $r = Restore-Backup -Session 'x'
            $r.Count | Should Be 3
            $r[0].TweakId | Should Be 'c'
            $r[1].TweakId | Should Be 'b'
            $r[2].TweakId | Should Be 'a'
        }
    }

    Context 'Restore-Backup error handling' {
        It 'captures operation failures' {
            Mock Get-BackupPath { 'C:\tmp\x' }; Mock Test-Path { $true }
            Mock Get-Content { '{ "Session":"t","Profile":"t","Changes":[{"SequenceNumber":1,"TweakId":"x","Type":"registry","Name":"HKLM\\Test\\Bad","OriginalValue":1}] }' }
            Mock Set-ItemProperty { throw "Access denied" }
            $r = Restore-Backup -Session 'x'
            $r[0].Reverted | Should Be $false
            $r[0].Error | Should Be 'Access denied'
        }

        It 'reports unknown type' {
            Mock Get-BackupPath { 'C:\tmp\x' }; Mock Test-Path { $true }
            Mock Get-Content { '{ "Session":"t","Profile":"t","Changes":[{"SequenceNumber":1,"TweakId":"x","Type":"unknown","Name":"X","OriginalValue":1}] }' }
            Mock Write-Warning { }
            $r = Restore-Backup -Session 'x'
            $r[0].Reverted | Should Be $false
        }
    }
}
