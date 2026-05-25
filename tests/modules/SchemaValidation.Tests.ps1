Describe "Schema validation" {
    It "validates bloat database schema" {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        $scriptPath = Join-Path $repoRoot "scripts\Validate-Schemas.ps1"

        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1
        $LASTEXITCODE | Should Be 0
        ($output -join "`n") | Should Match "Schema validation passed"
    }
}
