[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$IncludeProfiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        throw "Cannot resolve script path."
    }
    $RepoRoot = (Resolve-Path (Join-Path (Split-Path $scriptPath -Parent) "..")).Path
}

function Test-RequiredKeys {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Object,
        [Parameter(Mandatory=$true)]
        [string[]]$Required
    )

    foreach ($key in $Required) {
        if (-not $Object.ContainsKey($key)) {
            throw "Missing required key '$key'."
        }
    }
}

function Convert-JsonToHashtable {
    param([Parameter(Mandatory=$true)][string]$Path)
    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    return Convert-ToHashtableRecursive -InputObject $json
}

function Convert-ToHashtableRecursive {
    param($InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($k in $InputObject.Keys) {
            $result[$k] = Convert-ToHashtableRecursive -InputObject $InputObject[$k]
        }
        return $result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $arr = @()
        foreach ($item in $InputObject) {
            $arr += ,(Convert-ToHashtableRecursive -InputObject $item)
        }
        return $arr
    }

    if ($InputObject -is [pscustomobject]) {
        $result = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $result[$prop.Name] = Convert-ToHashtableRecursive -InputObject $prop.Value
        }
        return $result
    }

    return $InputObject
}

$bloatPath = Join-Path $RepoRoot "src\data\bloat-database.json"
$bloatSchemaPath = Join-Path $RepoRoot "docs\schemas\bloat-entry-schema.json"

if (-not (Test-Path $bloatPath)) { throw "Missing file: $bloatPath" }
if (-not (Test-Path $bloatSchemaPath)) { throw "Missing schema: $bloatSchemaPath" }

$bloat = Convert-JsonToHashtable -Path $bloatPath
$schema = Convert-JsonToHashtable -Path $bloatSchemaPath

Test-RequiredKeys -Object $bloat -Required @("version", "updated", "packages", "services", "tasks", "registry", "commands")
if ($bloat.version -lt 1) { throw "Invalid bloat database version: $($bloat.version)" }

$requiredEntryFields = @("id", "type", "name", "detect", "buildMin", "buildMax")
$allowedTypes = @("package", "service", "task", "registry", "command")
$allIds = @{}

foreach ($section in @("packages", "services", "tasks", "registry", "commands")) {
    if (-not ($bloat[$section] -is [System.Collections.IEnumerable])) {
        throw "Section '$section' must be an array."
    }

    foreach ($entry in $bloat[$section]) {
        $entryHash = Convert-ToHashtableRecursive -InputObject $entry

        Test-RequiredKeys -Object $entryHash -Required $requiredEntryFields
        if ($entryHash.type -notin $allowedTypes) {
            throw "Invalid type '$($entryHash.type)' in section '$section'."
        }
        if ($entryHash.type -ne $section.TrimEnd("s")) {
            # Allow plural mismatch for "registry" and "commands" through explicit mapping.
            $map = @{ packages="package"; services="service"; tasks="task"; registry="registry"; commands="command" }
            if ($entryHash.type -ne $map[$section]) {
                throw "Type '$($entryHash.type)' does not match section '$section'."
            }
        }
        if ($allIds.ContainsKey($entryHash.id)) {
            throw "Duplicate tweak id found: $($entryHash.id)"
        }
        $allIds[$entryHash.id] = $true
    }
}

if ($IncludeProfiles) {
    $profilesDir = Join-Path $RepoRoot "src\profiles"
    $profileSchemaPath = Join-Path $RepoRoot "docs\schemas\profile-schema.json"
    if (-not (Test-Path $profileSchemaPath)) { throw "Missing schema: $profileSchemaPath" }

    $profiles = Get-ChildItem -Path $profilesDir -Filter *.json -File
    foreach ($profileFile in $profiles) {
        $profile = Convert-JsonToHashtable -Path $profileFile.FullName
        Test-RequiredKeys -Object $profile -Required @("name", "description", "tweaks", "dangerous")

        foreach ($id in @($profile.tweaks)) {
            if (-not $allIds.ContainsKey($id)) {
                throw "Profile '$($profile.name)' references unknown tweak id '$id'."
            }
        }

        $preserve = if ($profile.preserve) { @($profile.preserve) } else { @() }
        foreach ($id in $preserve) {
            if (-not $allIds.ContainsKey($id)) {
                throw "Profile '$($profile.name)' preserve list references unknown id '$id'."
            }
        }
    }
}

Write-Host "Schema validation passed."
