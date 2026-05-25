function Get-ProfilePath {
    $script:ProfilesDir = Join-Path (Split-Path $PSScriptRoot -Parent) "profiles"
    if (-not (Test-Path $script:ProfilesDir)) {
        throw "Profiles directory not found: $script:ProfilesDir"
    }

    return $script:ProfilesDir
}

function Get-Profile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    $profilesDir = Get-ProfilePath
    $profileFile = Join-Path $profilesDir ("{0}.json" -f $Name)

    if (-not (Test-Path $profileFile)) {
        throw "Profile '$Name' not found at $profileFile"
    }

    $raw = Get-Content -Path $profileFile -Raw | ConvertFrom-Json
    return Resolve-ProfileInheritance -ProfileObj $raw -ProfilesDir $profilesDir
}

function Resolve-ProfileInheritance {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ProfileObj,

        [Parameter(Mandatory=$true)]
        [string]$ProfilesDir,

        [Parameter()]
        [string[]]$Visited = @()
    )

    $inherits = @()
    if ($null -ne $ProfileObj.inherits) {
        if ($ProfileObj.inherits -is [array]) {
            $inherits = @($ProfileObj.inherits)
        } else {
            $inherits = @([string]$ProfileObj.inherits)
        }
    }

    $allTweaks = @()
    $allPreserve = @()

    foreach ($parentName in $inherits) {
        if (-not $parentName) {
            continue
        }

        if ($Visited -contains $parentName) {
            Write-Warning "Circular inheritance detected for profile '$parentName' - skipping."
            continue
        }

        $parentFile = Join-Path $ProfilesDir ("{0}.json" -f $parentName)
        if (-not (Test-Path $parentFile)) {
            Write-Warning "Parent profile '$parentName' not found - skipping."
            continue
        }

        $parentRaw = Get-Content -Path $parentFile -Raw | ConvertFrom-Json
        $resolved = Resolve-ProfileInheritance -ProfileObj $parentRaw -ProfilesDir $ProfilesDir -Visited ($Visited + $parentName)

        if ($resolved.Tweaks) {
            $allTweaks += @($resolved.Tweaks)
        }
        if ($resolved.Preserve) {
            $allPreserve += @($resolved.Preserve)
        }
    }

    if ($ProfileObj.tweaks) {
        $allTweaks += @($ProfileObj.tweaks)
    }
    if ($ProfileObj.preserve) {
        $allPreserve += @($ProfileObj.preserve)
    }

    $distinctTweaks = @($allTweaks | Where-Object { $_ } | Select-Object -Unique)
    $distinctPreserve = @($allPreserve | Where-Object { $_ } | Select-Object -Unique)
    $activeTweaks = @($distinctTweaks | Where-Object { $distinctPreserve -notcontains $_ })

    return [PSCustomObject]@{
        Name        = $ProfileObj.name
        Description = $ProfileObj.description
        Tweaks      = $activeTweaks
        Preserve    = $distinctPreserve
        Distinct    = $distinctTweaks.Count
        Preserved   = $distinctPreserve.Count
        Dangerous   = if ($ProfileObj.dangerous) { $true } else { $false }
    }
}

function Get-AvailableProfiles {
    $profilesDir = Get-ProfilePath
    $files = Get-ChildItem "$profilesDir\*.json"

    $result = foreach ($f in $files) {
        $data = Get-Content -Path $f.FullName -Raw | ConvertFrom-Json
        [PSCustomObject]@{
            Name        = $data.name
            Description = $data.description
            Inherits    = if ($data.inherits -is [array]) { $data.inherits -join ', ' } else { $data.inherits }
            TweakCount  = if ($data.tweaks) { @($data.tweaks).Count } else { 0 }
            Dangerous   = if ($data.dangerous) { $true } else { $false }
        }
    }

    return $result
}
