# Roadmap - WinTune

## Phase 0: Foundation (Completed)
- [x] Repository bootstrap (`README`, `LICENSE`, skeleton folders).
- [x] CLI entry point (`src/wintune.ps1`) with module dot-sourcing.
- [x] Pre-flight checks (admin, execution policy warning, Windows build detection).
- [x] Core modules scaffolded and wired (`Scanner`, `Profiles`, `TweaksEngine`, `BackupManager`, `Reporter`).
- [x] Initial `bloat-database.json` and profile set (`base`, `gaming`, `workstation`, `laptop`, `minimal`).
- [x] Initial tweak set (10 reference tweaks).
- [x] Pester scaffolding and baseline tests.

## Phase 1: Audit Baseline + Data Gate (Completed)
- [x] Freeze `Audit` contract: CLI inputs, JSON output shape, and exit-code behavior.
- [x] Stabilize `Scanner` and `Reporter` for edge cases (empty collections, missing items, null snapshots).
- [x] Add minimal logging scaffold (`session`, `audit`, `error` files and directory convention).
- [x] Add minimal schema gate for `src/data/bloat-database.json` (local validation + CI validation).
- [x] Add CI smoke checks for CLI read-only paths (`List` and `List -OutputJson`).
- [x] Add/extend unit tests for Scanner/Reporter contract safety.

**DoD**
- `Audit` is deterministic for same snapshot/profile inputs.
- `bloat-database.json` passes schema validation in local check and CI.
- Pester unit tests (58) and CLI smoke checks are green in CI.
- Logging wired into Audit/Apply/Revert with session, audit, error files.
- Exit codes documented (`0` success, `1` error) and tested.
- `-OutputJson` contract frozen: specs for every action + compliance test.

## Phase 2: Safe Apply Core (Completed)
- [x] Make `Apply` strictly idempotent (repeat run has no unsafe side-effects).
- [x] Enforce backup-before-mutate for each tweak type (package/service/task/registry/command).
- [x] Finalize behavior of `-WhatIf`, `-Confirm`, `-Dangerous`, `-StopOnError`.
- [x] Add tests for partial failures and stop-on-error behavior.
- [x] Add buildMin/buildMax filtering in TweaksEngine (build-aware detection).
- [x] Move `--Confirm` to `-Confirm` in CLI (SupportsShouldProcess on Invoke-TweakGeneric).
- [x] Add `Test-CommandDetected` for hibernation detection, per-tweak Write-SessionEvent logging.

**DoD**
- Repeated `Apply` is safe and predictable.
- Backup is produced before mutation paths execute.
- Flag behavior is documented and covered by tests.
- Build-aware filtering skips tweaks outside their target Windows build range.

## Phase 3: Revert Reliability (Completed)
- [x] Harden `Revert` manifest validation and error handling.
- [x] Enforce reverse-order rollback and explicit per-item status reporting.
- [x] Document rollback limitations (full revert vs best-effort revert) per type.
- [x] Add integration scenario: `Apply -> Revert -> verify state` (per-type unit tests).
- [x] Normalize WMI StartMode values ("Auto" -> "Automatic") for safe Set-Service restore.

**DoD**
- `Apply -> Revert` is reproducible in integration tests.
- Revert report is transparent for success/failure per item.

## Phase 4: Contract & Profile Governance (Completed)
- [x] Freeze and test `-OutputJson` contract for List and Audit actions.
- [ ] Freeze and test `-OutputJson` contract for Apply and Revert actions (PARTIAL: shapes exist, no admin-free automated tests).
- [x] Add schema/contract checks for `profiles/*.json` (Test-ProfileSchema via Validate-Schemas.ps1 -IncludeProfiles).
- [x] Add compatibility rules for tweak IDs (regex pattern) and profile inheritance integrity (circular detection in visited-set).
- [x] Add preserve ID validation against bloat-database.json.
- [x] Strengthen CI gates for contract stability on data/profile changes.
- [x] Add `"command"` type to backup-manifest-schema.json.
- [x] Add Test-BloatDatabaseSchema for runtime database validation in TweaksEngine.

**DoD**
- Contract and profile changes fail fast without explicit updates and tests.
- CI prevents silent shape/compatibility regressions.

## Phase 5: WPF GUI (In Progress)
- [x] Scaffold WPF GUI project (`gui/WinTune.Gui`) on `net8.0-windows`.
- [x] Implement dashboard, profile selector, audit results, apply progress, revert views.
- [x] Wire GUI to PowerShell via `-OutputJson` (no direct module imports) — PsRunner.cs with System.Diagnostics.Process.
- [x] Add ModernWpf styling and default dark theme.
- [x] Add 5-minute timeout with proc.Kill fallback in PsRunner.
- [x] Replaced `PowerShell.Create()` with `Process.Start("powershell.exe")` for correct external process invocation.
- [x] Removed Microsoft.PowerShell.SDK package dependency (saves ~150MB).
- [x] Define GUI-level smoke tests (launch + List + OutputJson parsing).

**DoD**
- GUI builds via `dotnet build` and runs via `dotnet run --project gui/WinTune.Gui`.
- All views render without exceptions.
- GUI only uses CLI JSON contracts (no direct PowerShell module calls).
- Default dark theme is applied.

## Phase 6: Release Readiness (v0.1)
- [x] CI on `windows-latest`: Pester (20 suites, 60+ tests) + schema checks + CLI smoke checks.
- [x] Publish operator runbook: guarantees, limitations, dangerous-policy.
- [x] Tag and publish `v0.1.0` only on fully green CI.

**DoD**
- Full CI is green.
- Runbook is complete and aligned with actual behavior.
- Release tag `v0.1.0` is created from validated state.
