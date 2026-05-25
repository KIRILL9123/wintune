function Test-CommandDetected {
    param([string]$TweakId)

    switch ($TweakId) {
        'disable-hibernation' {
            return $null -ne (powercfg /a 2>$null | Select-String -Pattern 'Hibernation' -SimpleMatch)
        }
        default {
            return $false
        }
    }
}
