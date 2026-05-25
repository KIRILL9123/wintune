# Roadmap — WinTune

## v0.1.0 (Released)

18 tweaks, 5 profiles. Idempotent Apply, reverse-order Revert, build-aware detection, WPF scaffold, 60+ Pester + 8 xUnit. [Full release notes](https://github.com/KIRILL9123/wintune/releases/tag/v0.1.0).

---

## v0.2 Plan

### A. GUI Static Views — Real Backend

Wire Dashboard, ProfileSelector, and Revert to live `PsRunner` calls + async ViewModels with loading/error/cancellation states.

- [x] DashboardViewModel → `Audit -Profile <selected> -OutputJson`, parse real score
- [x] ProfileSelectorViewModel → `List -OutputJson`, populate from parsed JSON
- [x] RevertViewModel → scan `%LOCALAPPDATA%\WinTune\backups\*` for sessions

---

### B. GUI Live Apply Progress — Streaming

**Decided: Option 2 (streaming).** Engine writes structured lines to stdout during execution. GUI reads with `StreamReader.ReadLineAsync()`.

- [x] Add `-ProgressFile` to TweaksEngine — each tweak writes `{"seq": "N/M", "id": "...", "status": "running|done|failed"}` as JSONL
- [x] wintune.ps1 creates temp progress file, includes path in Apply output JSON
- [ ] GUI `ApplyProgressViewModel` polls progress file (infrastructure ready, UI wiring after Phase 5 complete)

---

### C. Exit Code 2 — Partial Success

- [x] `wintune.ps1` Apply path: exit `2` when `$changes` contains failures

---

### D. Build-Aware Scoring

- [x] `Reporter.ps1` `Get-Score`: exclude build-inapplicable tweaks from Total

---

### E. Tweak Database — Telemetry Services

- [x] `disable-wpnservice` (WpnService)
- [x] `disable-dps` (DPS — Diagnostic Policy Service)
- [x] Both added to `base` profile (10→12 tweaks)

---

### F. Command-Type Revert

- [x] `$commandUndo` mapping: `disable-hibernation` → `powercfg /h on`

---

### G. Scheduled Audit

- [x] `scripts/Register-ScheduledAudit.ps1` — SYSTEM task, weekly Audit

---

### H. Tech Debt

- [x] **Helpers.ps1** — `Test-CommandDetected` extracted from TweaksEngine
- [x] **CI dotnet test** — added to `ci.yml`
- [ ] **OutputJson contract tests** for Apply/Revert (blocked by admin requirement)

---

### I. GUI Redesign

- [x] MainWindow: NavigationView with Segoe MDL2 icons, compact pane, branding header
- [x] Dashboard: score circle, system stats grid (packages/services/processes/RAM), loading/error/empty states
- [x] ProfileSelector: UniformGrid cards, tweak count, dangerous badge
- [x] ApplyProgress: ProgressBar, streaming progress list, cancel/complete
- [x] Revert: card-based session list, error/empty states
- [x] BoolToVisibilityConverter in App.xaml

---

### J. dotnet publish

- [x] `PublishSingleFile=true`, `PublishReadyToRun=true`, `RuntimeIdentifier=win-x64`
- [x] Build: `dotnet publish gui/WinTune.Gui -c Release -o publish`

---

## v0.2 DoD

- [x] GUI Dashboard/ProfileSelector/Revert use real PsRunner data
- [x] Async ViewModels with loading/error/cancellation
- [x] Exit code 2 on partial Apply failure
- [x] Get-Score filters by build
- [x] Command revert works for hibernation
- [x] Telemetry services (WpnService, DPS) covered in bloat DB
- [x] Helpers.ps1 extracted, Reporter depends on it
- [x] `dotnet test` in CI
- [x] Scheduled audit task registration script
- [x] Streaming progress infrastructure (engine + CLI side)
- [x] Modern GUI design with icons, cards, states
- [x] dotnet publish single-file configuration
- [x] All Pester + xUnit tests green (125 + 8)

---

## Beyond v0.2

- `windows10` profile (after build-aware scoring)
- GUI live Apply progress (streaming)
- Installer / `dotnet publish` single-exe
- Community profile PR template
