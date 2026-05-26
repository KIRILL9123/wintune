# WinTune v0.1 — Operator Runbook

## Overview

WinTune is a modular Windows 11 tuning engine that audits, applies, and reverts optimization profiles. It removes bloatware packages, disables telemetry services, disarms scheduled tasks, sets privacy-focused registry values, and runs safe commands like disabling hibernation.

**Repository:** `https://github.com/KIRILL9123/wintune`
**License:** MIT

---

## System Requirements

| Requirement | Detail |
|---|---|
| OS | Windows 11 (build 22000+), Windows 10 (build 19045+) |
| PowerShell | Windows PowerShell 5.1 or PowerShell 7+ |
| Execution Policy | `RemoteSigned` or `Bypass` (recommended) |
| Privilege | **Administrator** for Audit, Apply, Revert. List works without admin. |
| GUI | Node.js 20+ and Rust stable for `cargo build` (Tauri) |

---

## Quick Start

```powershell
# List available profiles (no admin required)
.\src\wintune.ps1 -Action List

# Audit what would be changed by the gaming profile
.\src\wintune.ps1 -Action Audit -Profile gaming

# Preview changes without applying (dry-run)
.\src\wintune.ps1 -Action Apply -Profile gaming -WhatIf

# Apply with confirmation prompt for each tweak
.\src\wintune.ps1 -Action Apply -Profile gaming -Confirm

# Apply without confirmation (batch mode)
.\src\wintune.ps1 -Action Apply -Profile gaming -Confirm:$false

# Revert a previous session
.\src\wintune.ps1 -Action Revert -Session 2026-05-25_14-30-00
```

### JSON Output (for GUI / scripting)

```powershell
.\src\wintune.ps1 -Action List -OutputJson
.\src\wintune.ps1 -Action Audit -Profile gaming -OutputJson
.\src\wintune.ps1 -Action Apply -Profile gaming -OutputJson -Confirm:$false
.\src\wintune.ps1 -Action Revert -Session 2025-05-25_14-30-00 -OutputJson -Confirm:$false
```

---

## Profiles

| Profile | Tweaks | Inherits | Description |
|---|---|---|---|
| `base` | 10 | — | Core privacy and telemetry removal. Foundation for all other profiles. |
| `gaming` | 3 (+10) | base | Keeps Xbox services and Game Bar. Removes telemetry, disables SysMain and hibernation. |
| `workstation` | 2 (+10) | base | Balanced for productivity. Minimal tweaks on top of base. |
| `laptop` | 3 (+10) | base | Battery-friendly. Disables SysMain, hibernation, background apps. |
| `minimal` | 4 (+10) | base | Maximum debloat. Disables search indexing, SysMain, hibernation. |

All profiles inherit from `base`. Cumulative tweak counts shown (profile + inherited).

**Preserve mechanism:** Profiles can `preserve` specific tweaks from parent profiles. Example: `gaming.json` preserves `remove-xbox-app` and `remove-xbox-gaming-overlay` from `base`, keeping Xbox components intact.

---

## Flags

| Flag | Scope | Behavior |
|---|---|---|
| `-WhatIf` | Audit, Apply | Prints pending changes without applying them. No mutations. |
| `-Confirm` | Apply, Revert | PowerShell `ShouldProcess` prompt per tweak. Disabled by default in `-OutputJson` mode. |
| `-Confirm:$false` | Apply, Revert | Suppresses all prompts. Use for scripts and GUI integration. |
| `-Dangerous` | Apply | Required for profiles that modify critical system components. Without this flag, dangerous tweaks are skipped with a warning. |
| `-StopOnError` | Apply | Halts execution on the first tweak failure. Without it, the engine continues and reports all errors at the end. |

No profiles are currently marked `dangerous: true`, but the mechanism is in place for future profiles that modify deeply integrated system components.

---

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success. All operations completed without error. |
| `1` | Error. Missing admin, missing required parameter, profile not found, or tweak failure with `-StopOnError`. |

---

## Backup & Rollback

### Backup Location

```
%LOCALAPPDATA%\WinTune\backups\<session-timestamp>\
  ├── manifest.json        # Ordered list of all changes with original values
  └── registry-backup.reg  # Registry export (best-effort)
```

Override with `-BackupPath` or environment variable `WINTUNE_BACKUP_PATH`.

### Rollback (Revert)

```powershell
.\src\wintune.ps1 -Action Revert -Session 2025-05-25_14-30-00
```

Revert processes changes in **reverse order** (last-applied first). Each change reports its own success/failure independently.

### Rollback Limitations by Tweak Type

| Type | Revertible? | Details |
|---|---|---|
| **registry** | Fully | Restores original value. Does NOT delete keys created by the tweak. |
| **service** | Partially | Restores StartupType and attempts Start/Stop to match original Status. Fails if the service was deleted after backup. |
| **task** | Partially | Re-enables disabled tasks. Does NOT recreate deleted tasks. Silently skips if the task no longer exists. |
| **package** | **NOT** | Package reinstall is not implemented. Skipped with a warning. |
| **command** | **NOT** | Command undo is not implemented. Commands like `powercfg /h off` cannot be reversed automatically. |

### System Restore Point

A system restore point is created as a best-effort measure during `Apply`. If System Restore is disabled on the machine, the restore point is silently skipped — the backup manifest still exists and can be used for per-item revert.

---

## Idempotency Guarantee

Running `Apply` with the same profile multiple times is safe:

- **Packages**: removed packages are not re-processed.
- **Services**: already-disabled services are skipped.
- **Tasks**: already-disabled tasks are skipped.
- **Registry**: values already set to `0` are skipped.
- **Commands**: already-disabled features (e.g., hibernation) are skipped.

**Build-aware filtering:** Tweaks specify `buildMin` / `buildMax` constraints. The engine skips tweaks outside the current Windows build range. For example, `remove-copilot` (buildMin: 22621) is skipped on Windows 10 (build 19045).

---

## Logging

Session logs are stored in `logs\<session-id>\`:

| File | Purpose |
|---|---|
| `session.json` | Structured event log with timestamps and levels |
| `audit.csv` | Tabular audit trail |
| `error.log` | Dedicated error log |

Per-tweak logging is enabled for `Apply` — each tweak success/failure is recorded in `session.json`.

---

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `WINTUNE_BACKUP_PATH` | `%LOCALAPPDATA%\WinTune\backups` | Backup directory override |
| `WINTUNE_OUTPUT_DIR` | `.\reports` | HTML/JSON report output directory |

---

## GUI (Tauri)

The Tauri GUI is available under `gui-tauri/`:

```bash
cd gui-tauri/src-tauri
cargo build          # debug build
cargo build --release  # release build (~5MB single .exe)
```

The GUI communicates with the PowerShell engine exclusively through `-OutputJson` — no direct module imports. All CLI contracts and guarantees apply equally to GUI usage.

**GUI architecture:**
- **Rust backend** (`src-tauri/src/`): spawns PowerShell, parses JSON, exposes commands via Tauri IPC
- **HTML/CSS/JS frontend** (`src/`): plain HTML/CSS/JS, dark theme, 5 views (Dashboard, Profiles, Audit, Apply, Revert)

---

## Test Coverage

| Layer | Framework | Tests |
|---|---|---|
| PowerShell modules | Pester 3.4+ | 60+ tests (9 suites) |
| PowerShell CLI contracts | Pester | List, Audit JSON shape, exit codes |
| Schema validation | PowerShell | Bloat DB, profile tweaks, profile preserve IDs |
| GUI integration | N/A (Tauri) | Smoke test via `cargo build` in CI |
| CI | GitHub Actions | `windows-latest`, full Pester + schema + CLI smoke |

---

## Known Limitations

1. **Revert is best-effort, not full.** Package removal and hibernation disable are not revertible through the engine. Use System Restore for full system rollback.

2. **Registry key creation not undone.** If a tweak creates a new registry key (rare), revert sets the value but does not delete the key.

3. **No admin-free dry-run for Apply.** Apply and Audit require admin. Use `List` and `-WhatIf` for read-only inspection.

4. **GUI is Tauri-based.** Rust backend + HTML/CSS/JS frontend. Single binary ~5MB.

5. **Windows 10 support is partial.** The engine runs on Windows 10, but tweaks with `buildMin: 22621+` are silently skipped. No Windows 10-specific profiles exist yet.

6. **No automated Apply/Revert contract tests in CI.** These require admin rights and cannot run in GitHub Actions runners. Manual verification required.

7. **PowerShell script execution order.** All modules are dot-sourced alphabetically. Reporter depends on TweaksEngine for `Test-CommandDetected` — this is documented but not architecturally enforced.

---

## Recovery Procedures

### If Apply fails mid-way

1. Errors are collected per-tweak. Check `-OutputJson` or console output for which tweaks failed.
2. Run `Revert -Session <timestamp>` to roll back all successful changes.
3. Address the error (e.g., missing permissions, conflicting software) and retry `Apply`.

### If Revert fails for specific items

1. `Revert` returns per-item status. Registry and service changes are usually recoverable.
2. For package and command types, manual reinstall/reenable is required (see Rollback Limitations above).
3. Use System Restore Point (if available) for full system rollback.

### If backup manifest is corrupted

1. The engine validates manifest structure before reverting.
2. If the manifest is unparseable or missing required fields, revert will error with details.
3. Manual rollback: reinstall packages via Microsoft Store, re-enable services via `services.msc`, restore registry from `.reg` backup file in the backup directory.

### If system is unbootable after tweaks

1. Boot into Windows Recovery Environment (WinRE).
2. Use System Restore to roll back to the point created before Apply.
3. If no restore point exists, use Safe Mode to manually undo changes via `services.msc`, `taskschd.msc`, and `regedit`.

---

## Dangerous Profile Policy

A profile marked `dangerous: true` modifies system components where failure could impact system stability (e.g., deeply integrated services, kernel-level settings).

**Rules for dangerous profiles:**
1. Must include a `description` explaining the risk.
2. Require explicit `-Dangerous` flag at Apply time.
3. Without `-Dangerous`, dangerous tweaks are skipped with a warning — the profile is partially applied.
4. Dangerous profiles must be tested on a VM or snapshot-capable system before production use.

No profiles are currently marked dangerous. This policy is forward-looking for v0.2+.

---

## Version

**Current:** v0.1.0-pre

**Release checklist:**
- [x] All CI checks green (`windows-latest`)
- [x] Pester: 9 suites, 60+ tests
- [x] Tauri build configuration
- [x] Schema validation: bloat DB + profiles
- [x] Idempotency guaranteed for all tweak types
- [x] Backup-before-mutate enforced
- [x] Build-aware filtering active
- [x] Rollback limitations documented
- [x] Runbook complete
