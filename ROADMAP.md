# Roadmap — WinTune

## v0.1.0 (Released)

18 tweaks, 5 profiles. Idempotent Apply, reverse-order Revert, build-aware detection, WPF scaffold, 60+ Pester + 8 xUnit. [Full release notes](https://github.com/KIRILL9123/wintune/releases/tag/v0.1.0).

---

## v0.2 Plan

### A. GUI Static Views — Real Backend

Wire Dashboard, ProfileSelector, and Revert to live `PsRunner` calls + async ViewModels with loading/error/cancellation states.

- [ ] DashboardViewModel → `Audit -Profile <selected> -OutputJson`, parse real score
- [ ] ProfileSelectorViewModel → `List -OutputJson`, populate from parsed JSON
- [ ] RevertViewModel → scan `%LOCALAPPDATA%\WinTune\backups\*` for sessions

---

### B. GUI Live Apply Progress — Streaming

**Decided: Option 2 (streaming).** Engine writes structured lines to stdout during execution. GUI reads with `StreamReader.ReadLineAsync()`.

- [ ] Add `Write-ProgressLine` to engine — each tweak step writes `{"seq": N, "id": "...", "status": "..."}` to stdout alongside `-OutputJson`
- [ ] GUI `ApplyProgressViewModel` reads lines in real-time, updates progress bar + list

---

### C. Exit Code 2 — Partial Success

Frozen in `cli-spec.md:86`. Apply must exit `2` when some tweaks fail and `-StopOnError` is not set.

- [ ] `wintune.ps1` Apply path: exit `2` when `$changes` contains failures
- [ ] Pester test in `Contracts.Tests.ps1`

---

### D. Build-Aware Scoring

`Get-Score` must filter tweaks by `buildMin`/`buildMax` — same as TweaksEngine. Prerequisite for `windows10` profile.

- [ ] `Reporter.ps1` `Get-Score`: exclude build-inapplicable tweaks from Total
- [ ] Tests in `Reporter.Tests.ps1`

---

### E. Tweak Database — Telemetry Services

Expand `bloat-database.json` with all major telemetry services.

- [ ] `dmwappushsvc` (WAP Push) — service
- [ ] `WpnService` (Windows Push Notifications) — service  
- [ ] `DiagTrack` already exists — verify detect script
- [ ] Corresponding `keep-*` entries for profiles that want them preserved
- [ ] Hard constraint: every entry has a testable detect script

---

### F. Command-Type Revert

`Restore-Backup` currently throws for `command` type. Implement undo.

- [ ] `$commandUndo` mapping: `disable-hibernation` → `powercfg /h on`
- [ ] Generic hashtable for future command tweaks
- [ ] Tests in `ApplyRevert.Tests.ps1`

---

### G. Scheduled Audit

**Decided: task runs as SYSTEM via `schtasks /ru SYSTEM`.** Weekly audit writes `logs\audit\<YYYY-MM-DD>.json`.

- [ ] `scripts/Register-ScheduledAudit.ps1` — registers task, accepts `-Profile` and `-OutputPath`
- [ ] Task action: `powershell.exe -File wintune.ps1 -Action Audit -Profile <name> -OutputJson`

---

### H. Tech Debt

- [ ] **Helpers.ps1** — move `Test-CommandDetected` out of TweaksEngine into `src/modules/Helpers.ps1`. Reporter depends on Helpers, not TweaksEngine.
- [ ] **CI dotnet test** — add `dotnet test gui/WinTune.Gui.Tests` to `ci.yml`
- [ ] **OutputJson contract tests** — Apply/Revert shapes (blocked by admin requirement; explore `-WhatIf` + mock approach)

---

## Priority

```
A1 (Dashboard)    ← start here
A2 (ProfileSelector)
A3 (Revert sessions scan)
C  (exit code 2)
D  (build-aware scoring)  ← blocks E
F  (command revert)
E  (telemetry tweaks)
B  (live progress)        ← after engine streaming
G  (scheduled audit)
H  (tech debt)
```

## v0.2 DoD

- [ ] GUI Dashboard/ProfileSelector/Revert use real PsRunner data
- [ ] Async ViewModels with loading/error/cancellation
- [ ] Exit code 2 on partial Apply failure
- [ ] Get-Score filters by build
- [ ] Command revert works for hibernation
- [ ] Telemetry services covered in bloat DB
- [ ] Helpers.ps1 extracted, Reporter depends on it
- [ ] `dotnet test` in CI
- [ ] Scheduled audit task registration script
- [ ] All Pester + xUnit tests green

---

## Beyond v0.2

- `windows10` profile (after build-aware scoring)
- GUI live Apply progress (streaming)
- Installer / `dotnet publish` single-exe
- Community profile PR template
