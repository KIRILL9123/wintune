function Get-ProfilePath {
    $script:ProfilesDir = Join-Path (Split-Path $PSScriptRoot -Parent) "profiles"
    if (-not (Test-Path $ProfilesDir)) {
        throw "Profiles directory not found: $ProfilesDir"
    }
    return $ProfilesDir
}

function Get-Profile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    $profilesDir = Get-ProfilePath
    $profileFile = Join-Path $profilesDir "$Name.json"

    if (-not (Test-Path $profileFile)) {
        throw "Profile '$Name' not found at $profileFile"
    }

    $raw = Get-Content $profileFile -Raw | ConvertFrom-Json
    return Resolve-ProfileInheritance -ProfileObj $raw -ProfilesDir $profilesDir
}

function Resolve-ProfileInheritance {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ProfileObj,

        [Parameter(Mandatory=$true)]
        [string]$ProfilesDir,

        [Parameter()]
        [System.Collections.Generic.HashSet[string]]$Visited = $null
    )

    if (-not $Visited) {
        $Visited = [System.Collections.Generic.HashSet[string]]::new()
    }

    $inherits = $ProfileObj.inherits
    if ($inherits -is [string]) {
        $inherits = @($inherits)
    }
    if (-not $inherits) {
        $inherits = @()
    }

    $allTweaks = [System.Collections.Generic.HashSet[string]]::new()
    $allPreserve = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($parentName in $inherits) {
        if ($Visited.Contains($parentName)) {
            Write-Warning "Circular inheritance detected for profile '$parentName' — skipping."
            continue
        }
        $Visited.Add($parentName) | Out-Null

        $parentFile = Join-Path $ProfilesDir "$parentName.json"
        if (-not (Test-Path $parentFile)) {
            Write-Warning "Parent profile '$parentName' not found — skipping."
            continue
        }

        $parentRaw = Get-Content $parentFile -Raw | ConvertFrom-Json
        $resolved = Resolve-ProfileInheritance -ProfileObj $parentRaw -ProfilesDir $ProfilesDir -Visited $Visited

        foreach ($id in $resolved.tweaks) {
            $null = $allTweaks.Add($id)
        }
        foreach ($id in $resolved.preserve) {
            $null = $allPreserve.Add($id)
        }
    }

    # Child overrides parent
    if ($ProfileObj.tweaks) {
        foreach ($id in $ProfileObj.tweaks) {
            $null = $allTweaks.Add($id)
        }
    }
    if ($ProfileObj.preserve) {
        foreach ($id in $ProfileObj.preserve) {
            $null = $allPreserve.Add($id)
        }
    }

    # Remove preserved tweaks from active set
    $activeTweaks = [System.Collections.Generic.List[string]]::new()
    foreach ($id in $allTweaks) {
        if (-not $allPreserve.Contains($id)) {
            $activeTweaks.Add($id)
        }
    }

    return [PSCustomObject]@{
        Name        = $ProfileObj.name
        Description = $ProfileObj.description
        Tweaks      = $activeTweaks.ToArray()
        Distinct    = $allTweaks.Count
        Preserved   = $allPreserve.Count
        Dangerous   = if ($ProfileObj.dangerous) { $true } else { $false }
    }
}

function Get-AvailableProfiles {
    $profilesDir = Get-ProfilePath
    $files = Get-ChildItem "$profilesDir/*.json"
    $result = foreach ($f in $files) {
        $data = Get-Content $f.FullName -Raw | ConvertFrom-Json
        [PSCustomObject]@{
            Name        = $data.name
            Description = $data.description
            Inherits    = if ($data.inherits -is [array]) { $data.inherits -join ', ' } else { $data.inherits }
            TweakCount  = if ($data.tweaks) { $data.tweaks.Count } else { 0 }
            Dangerous   = if ($data.dangerous) { $true } else { $false }
        }
    }
    return $result
}
