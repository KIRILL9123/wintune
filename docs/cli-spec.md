# WinTune CLI Specification

## Entry point

```
.\src\wintune.ps1
```

Contract status: **frozen for v0.1**. Changes to parameter semantics, JSON output fields, or exit-code behavior require contract test updates.

## Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-Action` | `Audit \| Apply \| Revert \| List` | Yes | Mode of operation. `Audit` is read-only. `Apply` makes changes. `Revert` undoes a previous session. `List` shows available profiles. |
| `-Profile` | `string` | For `Audit`/`Apply` | Profile name. Matches a file in `src/profiles/<name>.json` (case-insensitive). |
| `-WhatIf` | `switch` | No | Show what would change without making any modifications. Propagates to every tweak function. |
| `-Confirm` | `switch` | No | Prompt for confirmation before each individual change. Propagates to every tweak function. |
| `-Dangerous` | `switch` | No | Allow tweaks flagged as `DANGEROUS: true`. Without this flag, dangerous tweaks are silently skipped. |
| `-StopOnError` | `switch` | No | Treat any non-fatal warning as a fatal error. Exit on first tweak failure. |
| `-Session` | `string` | For `Revert` | Session timestamp in `yyyy-MM-dd_HH-mm-ss` format. Identifies which backup manifest to use. |
| `-BackupPath` | `string` | No | Override the default backup directory (`$env:LOCALAPPDATA\WinTune\backups\`). |
| `-OutputDir` | `string` | No | Directory for report output (HTML, JSON). Defaults to `./reports/`. |
| `-OutputJson` | `switch` | No | Output all results as JSON to stdout. Machine-readable mode for GUI consumption (Tauri). Disables interactive prompts and pretty tables. When set, `-WhatIf` and `-Confirm` are ignored (GUI handles confirmation). |

## Actions

### Audit

```powershell
.\src\wintune.ps1 -Action Audit -Profile Gaming
```

1. Pre-flight checks (admin, execution policy, build detection).
2. Scanner runs → produces System State Snapshot.
3. Profile loaded → inherits resolved → flat tweak list produced.
4. Comparison: for each tweak, check if target item is still present.
5. Score calculated (Debloat Completion Rate).
6. Report printed to console (table) + exported if `-OutputDir` set.

### Apply

```powershell
.\src\wintune.ps1 -Action Apply -Profile Minimal -Confirm
.\src\wintune.ps1 -Action Apply -Profile Gaming -WhatIf
.\src\wintune.ps1 -Action Apply -Profile Minimal -Dangerous   # includes security tweaks
```

1. Same as Audit (steps 1-4).
2. If any dangerous tweaks are present and `-Dangerous` is not set → warn and skip them.
3. Backup: registry export + JSON manifest → `$env:LOCALAPPDATA\WinTune\backups\<timestamp>\`.
4. If `-WhatIf`: show the full change list and exit (no mutations).
5. If `-Confirm`: prompt for each individual change.
6. Execute changes in order (tweak by tweak). On failure: log, continue, unless `-StopOnError`.
7. Final report with delta metrics (RAM, boot time, process count).

### Revert

```powershell
.\src\wintune.ps1 -Action Revert -Session 2026-05-24_13-42-00
```

1. Load backup manifest from `<backupPath>\<session>\manifest.json`.
2. Verify it exists and is valid JSON.
3. Confirm prompt: "Revert session from <timestamp>? This will undo <N> changes."
4. Apply changes in reverse order (last change first).
5. Import `.reg` file if available.
6. Report which changes succeeded / failed.

### List

```powershell
.\src\wintune.ps1 -Action List
```

1. Scan `src/profiles/` for `*.json` files.
2. For each, load name, description, inherits, tweak count, dangerous flag.
3. Print as a formatted table.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (all changes applied, or audit completed) |
| 1 | Fatal error (no admin rights, bad profile, parse error) |
| 2 | Partial success (some tweaks failed, `-StopOnError` not set) |

Note: current implementation may still return `0/1` in some partial-failure paths. Exit code `2` remains part of frozen contract and must be aligned in implementation before `v0.1`.

## Environment variables

| Variable | Overrides | Default |
|---|---|---|
| `$env:WINTUNE_BACKUP_PATH` | `-BackupPath` | `$env:LOCALAPPDATA\WinTune\backups\` |
| `$env:WINTUNE_OUTPUT_DIR` | `-OutputDir` | `$PWD\reports\` |

## Examples

```powershell
# Quick audit
.\src\wintune.ps1 -Action Audit -Profile Gaming

# Preview before applying
.\src\wintune.ps1 -Action Apply -Profile Minimal -WhatIf

# Apply with per-item prompts
.\src\wintune.ps1 -Action Apply -Profile Laptop -Confirm

# Apply including security tweaks
.\src\wintune.ps1 -Action Apply -Profile Workstation -Dangerous -Confirm

# Undo last session
.\src\wintune.ps1 -Action Revert -Session 2026-05-24_13-42-00

# List available profiles
.\src\wintune.ps1 -Action List
```

## JSON output contract (frozen)

Machine-readable output is defined in [output-json-contract.md](C:/Users/kyrylo/Documents/WinTune/docs/output-json-contract.md).

## Backup manifest contract (frozen)

Backup/revert manifest format is defined in [backup-manifest-contract.md](C:/Users/kyrylo/Documents/WinTune/docs/backup-manifest-contract.md).
