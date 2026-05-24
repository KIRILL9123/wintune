# AI Context — WinTune

## Product vision
Build an open-source, deterministic Windows 11 tuning utility that is safe, auditable, and feels like a guided checklist rather than a magic "optimize" button. No AI inference at runtime. All logic is explicit rules and PowerShell.

## Target users
- Power users who reinstall Windows and want a repeatable post-install script.
- Users with existing Windows installs who want to audit and progressively clean bloatware, ads, and telemetry.
- Gamers and laptop users who need profile-based presets.

## Mandatory constraints
1. **No cloud / no AI at runtime**: everything works offline. No LLM calls, no telemetry home.
2. **Revert-first**: every mutation must generate a reversible backup before execution.
3. **Idempotent**: running the same tweak twice must not break anything.
4. **Non-destructive by default**: `Audit` mode never changes the system.
5. **Deterministic scoring**: the "optimization score" is a pure function of `(current state, selected profile)`. No guesswork.

## Tech stack
- **Runtime**: PowerShell 5.1+ (ships with Windows 11; no user dependencies).
- **Optional UI layer**: Python 3 + `rich`/`textual` for a pretty TUI wrapper (separate repo or `gui/` folder). Core engine stays PowerShell so it runs on locked-down systems.
- **Data format**: JSON for tweak manifests and bloatware database.
- **Tests**: Pester (PowerShell test framework).

## Architecture

### 1. Scanner (`modules/Scanner.ps1`)
Responsibilities:
- Enumerate installed UWP packages (`Get-AppxPackage`).
- Enumerate running / installed services (`Get-Service`).
- Enumerate scheduled tasks (`Get-ScheduledTask`).
- Read registry keys related to telemetry, ads, and context-menu overrides.
- Measure baseline metrics: idle RAM, cold-start process count, boot-to-desktop time estimate (Event Log based).

Output: a structured **System State Snapshot** (JSON).

### 2. Profiles (`modules/Profiles.ps1`)
Each profile is a JSON manifest:
```json
{
  "name": "Gaming",
  "description": "Strip telemetry, disable unnecessary services, keep Xbox & GameBar",
  "rules": {
    "remove_packages": ["Microsoft.BingNews", "Microsoft.BingWeather"],
    "disable_services": ["DiagTrack", "dmwappushservice"],
    "disable_tasks": ["...\\Microsoft\\Windows\\Application Experience\\..."],
    "registry_sets": [{"path": "HKLM\\...", "name": "...", "value": 0}]
  },
  "preserve": ["Microsoft.XboxApp", "XblAuthManager"]
}
```

### 3. TweaksEngine (`modules/TweaksEngine.ps1`)
- Reads the profile.
- Compares it against the Snapshot.
- For each delta, calls `BackupManager` to save current value.
- Applies change (remove package, stop & disable service, etc.).
- Logs action to local CSV log.

### 4. BackupManager (`modules/BackupManager.ps1`)
- Creates a System Restore Point (if available).
- Exports affected registry keys to `.reg` files under `backups/<timestamp>/`.
- Saves a JSON manifest of all changes in that session.
- `Revert-Session` reads the manifest and undoes changes in reverse order.

### 5. Reporter (`modules/Reporter.ps1`)
- Console table output (pretty print with alignment).
- HTML report export for sharing or archiving.
- Score breakdown per category: Privacy, Performance, UI, Debloat.

## Scoring algorithm (Debloat Completion Rate)
Given a Snapshot and a Profile:
- `total = count(profile.rules.remove_packages) + count(profile.rules.disable_services) + count(profile.rules.disable_tasks) + count(profile.rules.registry_sets)`
- `removed = count(items in total that are still present on the system)`
- `score = round((removed / total) * 100)`

Additional metrics (informational, not part of score):
- Boot time delta (before vs after).
- Idle RAM delta.
- Idle process count delta.

## UI flow (CLI / TUI)
1. Welcome screen — choose mode: `Audit` or `Apply`.
2. If `Apply` — choose profile: `Gaming`, `Workstation`, `Laptop`, `Minimal`.
3. Scanner runs, shows live progress.
4. Report preview — list of changes + predicted score improvement.
5. Confirm (Y/n) or granular toggle per item.
6. Apply → Backup → Execute → Final report.

## File naming conventions
- PowerShell modules: PascalCase (`Scanner.ps1`, `BackupManager.ps1`).
- JSON manifests: kebab-case (`bloat-database.json`, `gaming-profile.json`).
- Folders: lowercase (`src/`, `docs/`, `tests/`).

## Testing strategy
- Unit tests for each module with Pester.
- Mock registry / service / package calls so tests run safely on any machine.
- Integration test on a Windows 11 VM after every major merge.

## What NOT to build
- An AI chatbot interface.
- A one-click "Fix everything" button without review.
- Automatic driver updates or Windows Update manipulation.
- Anything that cannot be reverted cleanly.

## Development phases
See `ROADMAP.md`.
