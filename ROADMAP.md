# Roadmap — WinTune

## Phase 0: Foundation (Week 1)
- [x] Create GitHub repo with README + LICENSE.
- [ ] Set up folder skeleton (`src/`, `tests/`, `docs/`, `gui/`, `logs/`).
- [ ] Write `wintune.ps1` entry point with dot-source module loading scaffold.
- [ ] Add pre-flight checks:
  - Admin rights elevation check (fail early with clear message).
  - Execution Policy check (warn on `Restricted`/`AllSigned`).
  - Windows build detection (`[Environment]::OSVersion.Version.Build`).
- [ ] Build `Scanner.ps1` MVP: enumerate UWP packages, services, scheduled tasks.
- [ ] Build `data/bloat-database.json` with initial entry schema (AppX IDs, service names, task paths, registry keys).
- [ ] Build `profiles/base.json` — common debloat base profile.
- [ ] Build one reference profile (e.g., `profiles/minimal.json` with `"inherits": "base"`).
- [ ] Define the tweak function contract (metadata block, `-WhatIf`/`-Confirm` params, return object).
- [ ] Build `Profiles.ps1` — load + resolve `inherits` chain (breadth-first, child overrides parent).
- [ ] Build `TweaksEngine.ps1` — iterate resolved tweak list, load `.ps1`, call function.
- [ ] Build `BackupManager.ps1` MVP — registry export to `.reg` + JSON manifest (no SRP yet).
- [ ] Set up Pester test scaffolding.
- [ ] Write tests for: module loading, profile inheritance resolution, admin check.

## Phase 1: Audit Engine (Week 2)
- [ ] Implement profile-to-snapshot comparison logic.
- [ ] Implement Debloat Completion Rate calculation.
- [ ] Build `Reporter.ps1` (console tables).
- [ ] Add logging scaffold (Session / Audit / Error log levels).
- [ ] Add `Audit` CLI entry: `wintune.ps1 -Action Audit -Profile Minimal`.
- [ ] Write first 10 tweak definitions (privacy + debloat).
- [ ] Write Pester tests for Scanner, Reporter, and each tweak.

## Phase 2: Safe Apply (Week 3)
- [ ] Complete `BackupManager.ps1` — add SRP as non-fatal secondary backup.
- [ ] Implement idempotent apply logic (skip already-applied tweaks).
- [ ] Implement `Apply` CLI entry with `-WhatIf` preview and `-Confirm` per-item prompting.
- [ ] Add granular toggles: user can uncheck specific items before confirming.
- [ ] Wire `-Dangerous` flag for security-sensitive tweaks.
- [ ] Write 20 more tweak definitions (performance + UI).
- [ ] Write Pester tests for TweaksEngine + BackupManager.

## Phase 3: Profiles & Scoring (Week 4)
- [ ] Finalize 4 default profiles: `Gaming`, `Workstation`, `Laptop`, `Minimal`.
- [ ] Add informational delta metrics (RAM, boot time, process count).
- [ ] HTML report export via `Reporter.ps1`.
- [ ] Revert command: `wintune.ps1 -Action Revert -Session <timestamp>`.
- [ ] Write integration tests (mock-based).

## Phase 4: Polish & Release v0.1 (Week 5)
- [ ] PowerShell error handling and structured logging throughout.
- [ ] Documentation: usage GIFs, tweak contribution guide.
- [ ] CI: GitHub Action that runs Pester tests on `windows-latest`.
- [ ] Tag `v0.1.0`.

## Phase 5: PySide6 GUI Application (Post-v0.1)
- [ ] Build PySide6 GUI in `gui/` with 6 screens:
  - Dashboard (profile selector + action buttons).
  - Audit Report (Debloat Completion Rate + per-tweak checkboxes).
  - Apply Progress (live progress bar with per-tweak status).
  - Revert (session history browser + revert confirmation).
  - Settings (backup path, output path, dangerous mode).
  - Report Viewer (inline HTML report or browser launch).
- [ ] Implement `-OutputJson` flag in engine for machine-readable GUI consumption.
- [ ] Dark theme throughout (Windows 11 dark palette).
- [ ] App icon (generated separately, stored in `gui/assets/`).
- [ ] System tray mini-audit reminder (optional, low priority).

## Phase 6: Community expansion
- [ ] Crowd-sourced bloat-database.json via PRs.
- [ ] Plugin system for custom user profiles.
- [ ] Localization (ru, de, en).
