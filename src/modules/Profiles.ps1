function Get-ProfilePath {
    $script:ProfilesDir = Join-Path (Split-Path $PSScriptRoot -Parent) "profiles"
    if (-not (Test-Path $script:ProfilesDir)) {
        throw "Profiles directory not found: $script:ProfilesDir"
    }

    return $script:ProfilesDir
}

function Test-ProfileSchema {
    <#
    .SYNOPSIS
        Validates a profile JSON object against the profile schema contract.
        Throws on missing required fields or type mismatches.
    #>
    param(
        [Parameter(Mandatory=$true)]
        $ProfileObj,

        [Parameter()]
        [string]$ProfileName = "unknown"
    )

    $errors = @()

    if (-not $ProfileObj) {
        throw "Profile '$ProfileName': profile object is null"
    }

    if ($null -eq $ProfileObj.name -or $ProfileObj.name -eq '') {
        $errors += "missing or empty required field: name"
    }
    if ($ProfileObj.name -and $ProfileObj.name -isnot [string]) {
        $errors += "name must be a string, got $($ProfileObj.name.GetType().Name)"
    }

    if ($null -eq $ProfileObj.tweaks) {
        $errors += "missing required field: tweaks"
    } elseif ($ProfileObj.tweaks -isnot [array]) {
        $errors += "tweaks must be an array, got $($ProfileObj.tweaks.GetType().Name)"
    } else {
        foreach ($t in $ProfileObj.tweaks) {
            if ($t -isnot [string] -or $t -eq '') {
                $errors += "each tweak must be a non-empty string, got '$t'"
            } elseif ($t -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
                $errors += "tweak '$t' does not match pattern ^[a-z0-9]+(-[a-z0-9]+)*$"
            }
        }
    }

    if ($ProfileObj.PSObject.Properties.Name -contains 'description') {
        if ($null -ne $ProfileObj.description -and $ProfileObj.description -isnot [string]) {
            $errors += "description must be a string or null, got $($ProfileObj.description.GetType().Name)"
        }
    }

    if ($ProfileObj.PSObject.Properties.Name -contains 'preserve') {
        if ($ProfileObj.preserve -isnot [array]) {
            $errors += "preserve must be an array, got $($ProfileObj.preserve.GetType().Name)"
        } else {
            foreach ($p in $ProfileObj.preserve) {
                if ($p -isnot [string]) {
                    $errors += "each preserve entry must be a string, got '$p'"
                }
            }
        }
    }

    if ($ProfileObj.PSObject.Properties.Name -contains 'dangerous') {
        if ($ProfileObj.dangerous -isnot [bool]) {
            $errors += "dangerous must be a boolean, got $($ProfileObj.dangerous.GetType().Name)"
        }
    }

    if ($ProfileObj.PSObject.Properties.Name -contains 'inherits') {
        if ($null -ne $ProfileObj.inherits) {
            if ($ProfileObj.inherits -is [string]) {
                # single string — valid
            } elseif ($ProfileObj.inherits -is [array]) {
                foreach ($p in $ProfileObj.inherits) {
                    if ($p -isnot [string]) {
                        $errors += "each inherits entry must be a string, got '$p'"
                    }
                }
            } else {
                $errors += "inherits must be a string, array of strings, or null, got $($ProfileObj.inherits.GetType().Name)"
            }
        }
    }

    if ($ProfileObj.dangerous -eq $true) {
        if (-not $ProfileObj.description) {
            $errors += "dangerous profile must have a description explaining why"
        }
    }

    if ($errors.Count -gt 0) {
        throw "Profile '$ProfileName' schema validation failed: $($errors -join '; ')"
    }
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
    Test-ProfileSchema -ProfileObj $raw -ProfileName $Name
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
        Test-ProfileSchema -ProfileObj $parentRaw -ProfileName $parentName
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
