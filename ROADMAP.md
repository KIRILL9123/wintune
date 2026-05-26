# Roadmap — WinTune

## v0.1.0 (Released)

18 tweaks, 5 profiles. Idempotent Apply, reverse-order Revert, build-aware detection, Pester tests. [Full release notes](https://github.com/KIRILL9123/wintune/releases/tag/v0.1.0).

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
- [ ] GUI ApplyProgress polls progress file (infrastructure ready, UI wiring pending)

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
- [x] **CI build** — added to `ci.yml`
- [ ] **OutputJson contract tests** for Apply/Revert (blocked by admin requirement)

---

### I. GUI Redesign — Tauri Rewrite

- [x] Rust backend: PowerShell runner, command handlers for Audit/Apply/Revert/List/Sessions
- [x] HTML/CSS/JS frontend: Dashboard, Profiles, Audit, Apply, Revert views
- [x] Dark theme with modern design system, cards, score circle, stat grid
- [x] IPC via `window.__TAURI__.core.invoke()`

---

### J. Tauri Build

- [x] `Cargo.toml` with Tauri v2 dependencies
- [x] `tauri.conf.json` — window config, bundle settings
- [ ] `cargo build` (pending C++ build tools)
- [ ] `cargo tauri build` — single .exe output (~5MB)

---

## v0.2 DoD

- [x] GUI Dashboard/ProfileSelector/Revert use real PowerShell data
- [x] Async operations with loading/error states
- [x] Exit code 2 on partial Apply failure
- [x] Get-Score filters by build
- [x] Command revert works for hibernation
- [x] Telemetry services (WpnService, DPS) covered in bloat DB
- [x] Helpers.ps1 extracted, Reporter depends on it
- [x] CI build step
- [x] Scheduled audit task registration script
- [x] Streaming progress infrastructure (engine + CLI side)
- [x] Tauri GUI scaffold with all 5 views
- [x] Tauri build configuration
- [x] All Pester tests green (125+)

---

## Beyond v0.2

- `windows10` profile (after build-aware scoring)
- GUI live Apply progress (streaming from JSONL)
- `cargo tauri build` — release single-exe
- Community profile PR template
