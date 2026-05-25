Describe "CLI contracts" {
    It "List action supports OutputJson and returns parseable JSON" {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        $entry = Join-Path $repoRoot "src\wintune.ps1"

        $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $entry -Action List -OutputJson
        $LASTEXITCODE | Should Be 0

        $parsed = $raw | ConvertFrom-Json
        @($parsed).Count | Should BeGreaterThan 0
        $first = @($parsed)[0]
        $first.Name | Should Not BeNullOrEmpty
        $first.Description | Should Not BeNullOrEmpty
    }
}
