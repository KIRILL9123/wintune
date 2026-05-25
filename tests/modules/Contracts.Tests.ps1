Describe 'CLI contracts' {
    BeforeAll {
        $script:Entry = Resolve-Path (Join-Path $PSScriptRoot "..\..\src\wintune.ps1")
    }

    Context 'List -OutputJson' {
        It 'returns parseable JSON with exit code 0' {
            $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action List -OutputJson
            $LASTEXITCODE | Should Be 0
            $parsed = $raw | ConvertFrom-Json
            @($parsed).Count | Should BeGreaterThan 0
        }

        It 'each profile has Name, Description, Inherits, TweakCount, Dangerous' {
            $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action List -OutputJson
            foreach ($p in ($raw | ConvertFrom-Json)) {
                $p.Name        | Should Not BeNullOrEmpty
                $p.Description | Should Not BeNullOrEmpty
                $p.TweakCount  | Should BeGreaterThan 0
                ($p.Dangerous -eq $true -or $p.Dangerous -eq $false) | Should Be $true
            }
        }

        It 'Inherits is string or null' {
            $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action List -OutputJson
            foreach ($p in ($raw | ConvertFrom-Json)) {
                ($p.Inherits -is [string] -or $null -eq $p.Inherits) | Should Be $true
            }
        }

        It 'all 5 profiles are returned' {
            $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action List -OutputJson
            $parsed = $raw | ConvertFrom-Json
            @($parsed).Count | Should Be 5
        }
    }

    Context 'Audit -OutputJson without admin' {
        It 'returns parseable JSON with exit code 1' {
            $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action Audit -OutputJson 2>$null
            $LASTEXITCODE | Should Be 1
            $parsed = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            $parsed | Should Not Be $null
        }

        It 'error JSON contains success=false and error message' {
            $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action Audit -OutputJson 2>$null
            $parsed = $raw | ConvertFrom-Json
            $parsed.success | Should Be $false
            $parsed.error   | Should Not BeNullOrEmpty
        }

        It 'error JSON has no interactive prompts' {
            $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action Audit -OutputJson 2>$null
            $combined = $raw -join "`n"
            $combined | Should Not Match 'Are you sure|Type.*yes to confirm'
        }
    }

    Context 'Exit codes' {
        It 'List returns exit code 0' {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action List -OutputJson | Out-Null
            $LASTEXITCODE | Should Be 0
        }

        It 'List without -Action returns exit code 1' {
            & powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$($script:Entry)' 2>&1" | Out-Null
            $LASTEXITCODE | Should Be 1
        }

        It 'Audit without admin returns exit code 1' {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action Audit 2>&1 | Out-Null
            $LASTEXITCODE | Should Be 1
        }

        It 'Audit without -Profile returns exit code 1' {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action Audit 2>&1 | Out-Null
            $LASTEXITCODE | Should Be 1
        }

        It 'Apply without admin returns exit code 1' {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action Apply 2>&1 | Out-Null
            $LASTEXITCODE | Should Be 1
        }

        It 'Revert without admin returns exit code 1' {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Entry -Action Revert 2>&1 | Out-Null
            $LASTEXITCODE | Should Be 1
        }
    }
}
