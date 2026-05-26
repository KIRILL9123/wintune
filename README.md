# WinTune

> Modular Windows 11 tuning engine with a built-in system health scanner. Works on fresh installs *and* on systems that have been running for years.

[![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=flat&logo=powershell&logoColor=white)]()
[![Windows 11](https://img.shields.io/badge/Windows%2011-%230079d5.svg?style=flat&logo=windows-11&logoColor=white)]()
[![Pester](https://img.shields.io/badge/tested%20with-Pester-%23C0392B.svg?style=flat)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)]()

## What makes it different

- **Two entry modes**: *Fresh Setup* (post-install presets) and *Live Audit* (scans what you already have and shows what can still be improved).
- **Completion-based score**: not a vague "0-100% health", but a measurable **Debloat Completion Rate** — how many removable items (services, tasks, packages, registry noise) are still present vs. what this profile expects.
- **Revert-first architecture**: every tweak generates a timestamped undo package before it touches the system.
- **Deterministic profiles**: Gaming, Workstation, Laptop/Battery, Minimal — each is a curated checklist, not a black-box "optimize" button.

## Quick start

```powershell
# Audit current system without changing anything
.\src\wintune.ps1 -Action Audit -Profile Gaming

# Preview changes (WhatIf mode, no actual changes)
.\src\wintune.ps1 -Action Apply -Profile Minimal -WhatIf

# Apply tweaks with full backup
.\src\wintune.ps1 -Action Apply -Profile Minimal -Confirm

# Revert last session
.\src\wintune.ps1 -Action Revert -Session 2026-05-24_13-42-00
```

## Prerequisites

- **PowerShell 5.1+** (ships with Windows 11).
- **Administrator rights** — all operations require elevation. WinTune checks on startup and exits with a clear message if not running as admin.
- **Execution Policy** — PowerShell may block `.ps1` execution by default. Set it once:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```
  WinTune checks the policy on startup and warns if it's too restrictive.

## Safety

WinTune is designed to be safe by default:

| Guarantee | Detail |
|---|---|
| **No changes in Audit mode** | `-Action Audit` is read-only. Always. |
| **Revert before every mutation** | A backup is created before anything is touched. |
| **WhatIf preview** | `-WhatIf` shows what *would* happen without doing it. |
| **Confirm per item** | `-Confirm` prompts for each change individually. |
| **No silent Defender/UAC changes** | Security-related tweaks require the explicit `-Dangerous` flag and a separate confirmation. |
| **Idempotent** | Running the same tweak twice is safe — already-applied tweaks are skipped. |

## Core concept: Debloat Completion Rate

Instead of guessing "how fast is my PC", WinTune calculates how close your current Windows image is to a clean, profile-optimized baseline:

1. **Discovery phase** — enumerate all uninstallable UWP packages, disableable services, scheduled tasks, optional features, and known registry ad-placements present on *this* machine.
2. **Scoring** — for the selected profile, `score = ((total_present - still_present) / total_present) * 100`.
3. **Actionable report** — you see the exact list of what still costs you points, with per-item risk notes and one-click (or one-command) remediation.

This keeps the metric objective: the "100%" is the cleanest possible state for *your* hardware and *your* chosen profile.

## Repository structure

```
wintune/
├── src/
│   ├── wintune.ps1              # CLI entry point (dot-sources all modules)
│   ├── modules/
│   │   ├── Scanner.ps1          # Discovery + metric collection
│   │   ├── TweaksEngine.ps1     # Apply / revert logic
│   │   ├── BackupManager.ps1    # Registry backups + restore points
│   │   ├── Profiles.ps1         # Profile loading, inheritance, scoring
│   │   └── Reporter.ps1         # HTML / console reports
│   ├── tweaks/
│   │   ├── privacy/
│   │   ├── performance/
│   │   ├── ui/
│   │   └── debloat/
│   ├── profiles/
│   │   ├── base.json            # Common debloat inherited by all profiles
│   │   ├── gaming.json
│   │   ├── workstation.json
│   │   ├── laptop.json
│   │   └── minimal.json
│   └── data/
│       └── bloat-database.json  # Shared dictionary of App IDs, service names, task paths
├── gui-tauri/                   # Tauri GUI (Rust + HTML/CSS/JS)
├── tests/
│   ├── modules/
│   ├── tweaks/
│   └── integration/
├── docs/
├── logs/                        # Session / Audit / Error logs (gitignored)
├── AI_CONTEXT.md                # Full context for AI-assisted development
├── ROADMAP.md
└── README.md
```

## Contributing

- **Tweaks**: add a `.ps1` file under `src/tweaks/<category>/` with a single exported function that accepts `-WhatIf` and `-Confirm`. Reference entries from `data/bloat-database.json`. Write a matching Pester test.
- **Profiles**: add or edit JSON under `src/profiles/`. Use `"inherits": "base"` to avoid duplicating common debloat. Child profile tweaks always override parent.
- **GUI**: Tauri work goes in `gui-tauri/`. Rust backend calls PowerShell; HTML/CSS/JS frontend. The PowerShell core must never depend on it.
- Open a PR — all contributions must pass Pester tests.

## License

MIT
