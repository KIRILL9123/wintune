# Roadmap — WinTune

## Phase 0: Foundation (Week 1)
- [ ] Create GitHub repo with README + LICENSE.
- [ ] Set up folder skeleton (`src/`, `tests/`, `docs/`).
- [ ] Build `Scanner.ps1` MVP: enumerate UWP packages, services, scheduled tasks.
- [ ] Build minimal JSON manifest format for a single profile (e.g., `minimal-profile.json`).
- [ ] Add Pester test scaffolding.

## Phase 1: Audit Engine (Week 2)
- [ ] Implement profile-to-snapshot comparison logic.
- [ ] Implement Debloat Completion Rate calculation.
- [ ] Build console reporter (pretty tables).
- [ ] Add `Audit` CLI entry: `wintune.ps1 -Action Audit -Profile Minimal`.
- [ ] Write first 20 tweak definitions (privacy + debloat).

## Phase 2: Safe Apply (Week 3)
- [ ] Build `BackupManager.ps1` (registry export + restore point).
- [ ] Build `TweaksEngine.ps1` with idempotent apply logic.
- [ ] Implement `Apply` CLI entry with `--WhatIf` preview.
- [ ] Add granular toggles: user can uncheck specific items before applying.
- [ ] Write 30 more tweak definitions (performance + UI).

## Phase 3: Profiles & Scoring (Week 4)
- [ ] Finalize 4 default profiles: `Gaming`, `Workstation`, `Laptop`, `Minimal`.
- [ ] Add informational delta metrics (RAM, boot time, process count).
- [ ] HTML report export.
- [ ] Revert command: `wintune.ps1 -Action Revert -Session <timestamp>`.

## Phase 4: Polish & Release v0.1 (Week 5)
- [ ] PowerShell error handling and logging.
- [ ] Documentation: usage GIFs, tweak contribution guide.
- [ ] CI: GitHub Action that runs Pester tests on `windows-latest`.
- [ ] Tag `v0.1.0`.

## Phase 5: Optional TUI (Post-v0.1)
- [ ] Python wrapper with `textual` for mouse-friendly interface.
- [ ] Real-time progress bars and checkboxes.
- [ ] System tray mini-audit reminder (optional, low priority).

## Phase 6: Community expansion
- [ ] Crowd-sourced bloat-database.json via PRs.
- [ ] Plugin system for custom user profiles.
- [ ] Localization (ru, de, en).
