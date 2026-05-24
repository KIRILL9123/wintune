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
6. **WhatIf / Confirm by default**: every tweak function must support `-WhatIf` and `-Confirm` from day one (PowerShell common parameters).

## Prequisites & safety
1. **Admin rights required**: all operations require elevation. A check runs on startup — if not admin, the tool shows a clear message and exits. No silent fallback.
2. **Execution Policy**: PowerShell's default policy may block `.ps1` execution. On startup, WinTune checks `Get-ExecutionPolicy` and warns if it's too restrictive (`Restricted` or `AllSigned`). Recommended policy is `RemoteSigned` (set via `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`). The tool never changes the policy automatically.
3. **Windows build detection**: the `Scanner` reads `[Environment]::OSVersion.Version.Build` at startup. Some tweaks are build-specific (service names, removable packages differ between 21H2 and 24H2). The bloat-database.json and tweaks must tag their minimum/maximum build versions.
4. **Defender & UAC policy**: by default, WinTune **never disables** Windows Defender or UAC. Any tweak that touches security settings must be flagged as `"dangerous": true` in its manifest and requires an explicit `-Dangerous` flag at the CLI level to be considered. Even then, the user is prompted separately for each dangerous tweak.

## Tech stack
- **Runtime**: PowerShell 5.1+ (ships with Windows 11; no user dependencies).
- **Optional UI layer (gui/)**: Python 3 + `rich`/`textual` for a pretty TUI wrapper in a separate `gui/` folder. Core engine stays PowerShell so it runs on locked-down systems. The `gui/` layer communicates with the core via stdout JSON or saved report files — no tight coupling.
- **Data format**: JSON for profile manifests and bloatware database. PowerShell script files (`.ps1`) for individual tweak implementations.
- **Tests**: Pester (PowerShell test framework).

## Repository structure
```
wintune/
├── src/
│   ├── wintune.ps1              # CLI entry point (dot-sources all modules)
│   ├── modules/
│   │   ├── Scanner.ps1          # Discovery + metric collection
│   │   ├── TweaksEngine.ps1     # Apply / revert logic
│   │   ├── BackupManager.ps1    # Registry exports + restore points
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
│       └── bloat-database.json  # Shared dictionary: App IDs, service names, task paths, registry keys
├── gui/                         # Optional Python TUI (separate entry point)
├── tests/
│   ├── modules/
│   ├── tweaks/
│   └── integration/
├── docs/
├── logs/                        # Session / Audit / Error logs (gitignored)
├── AI_CONTEXT.md
├── ROADMAP.md
└── README.md
```

## Architecture

### Data flow (tweaks / profiles / bloat-database)

```
profile.json ──"inherits"──→ base.json (optional chain)
     │
     ├── tweak_id_1 ──→ tweaks/privacy/disable-telemetry.ps1
     │                        │
     │                        └── references entries in bloat-database.json (AppX IDs, service names, etc.)
     │
     ├── tweak_id_2 ──→ tweaks/debloat/remove-candy-crush.ps1
     └── ...
```

- `profiles/*.json` — lists which tweaks to enable. May inherit from another profile via `"inherits"` field.
- `tweaks/*.ps1` — each file exports a single function (e.g. `Invoke-DisableTelemetry`). The function:
  - Accepts `-WhatIf` and `-Confirm`
  - Calls `BackupManager` before mutations
  - Returns a result object with status / error / delta
- `data/bloat-database.json` — shared registry of known Windows bloat identifiers. Referenced by tweaks, not by profiles directly.

### Profile inheritance model

```json
// profiles/base.json
{
  "name": "base",
  "description": "Common debloat inherited by all profiles",
  "inherits": null,
  "tweaks": ["remove-bing-news", "disable-telemetry", "disable-cortana"],
  "preserve": [],
  "dangerous": false
}

// profiles/gaming.json
{
  "name": "Gaming",
  "inherits": "base",
  "tweaks": ["keep-xbox-app", "disable-sysmain", "disable-hibernation"],
  "preserve": ["Microsoft.XboxApp", "XblAuthManager"],
  "dangerous": false
}
```

**Merge rule (CSS-like specificity):**
1. Start with all tweaks from the `inherits` chain (resolved breadth-first, `base` first).
2. Apply the child profile's `tweaks` — these are *added* to the set.
3. If a tweak ID appears in both parent and child, the child wins (deduped, child's version kept).
4. `preserve` items in the child exempt the corresponding tweak ID from execution, even if inherited.
5. `"dangerous": true` in the child does **not** propagate back to parent — each profile declares its own danger level.

### 1. Scanner (`modules/Scanner.ps1`)
Responsibilities:
- Enumerate installed UWP packages (`Get-AppxPackage`).
- Enumerate running / installed services (`Get-Service`).
- Enumerate scheduled tasks (`Get-ScheduledTask`).
- Read registry keys related to telemetry, ads, and context-menu overrides.
- Measure baseline metrics: idle RAM, cold-start process count, boot-to-desktop time estimate (Event Log based).
- Detect Windows build number and store it in the snapshot.

Output: a structured **System State Snapshot** (JSON).

### 2. Profiles (`modules/Profiles.ps1`)
- Loads the requested profile JSON from `profiles/`.
- Resolves the `inherits` chain (breadth-first, deduped, child overrides parent).
- Returns a flat, resolved tweak list with `preserve` exclusions applied.
- Handles missing `inherits` files gracefully (warning, continue with what we have).

### 3. Tweak definition format

Each `.ps1` file in `tweaks/` looks like this:

```powershell
function Invoke-DisableTelemetry {
    param(
        [switch]$WhatIf,
        [switch]$Confirm
    )
    # 1. Check WhatIf
    # 2. Prompt via Confirm
    # 3. Call BackupManager
    # 4. Apply change
}
```

The function is discovered and invoked by TweaksEngine. No manual registration needed — the engine scans `tweaks/`, reads a small metadata block at the top of each script, and maps tweak IDs to functions.

### 4. TweaksEngine (`modules/TweaksEngine.ps1`)
- Loads the resolved profile (flat tweak list from Profiles).
- For each tweak ID, finds the matching `.ps1` in `tweaks/<category>/`.
- Calls the tweak function with `-WhatIf` / `-Confirm` if flags are set.
- For each delta, calls `BackupManager` to save current value.
- Applies change (remove package, stop & disable service, etc.).
- Logs action to session log.
- Aggregates results for final report.

### 5. BackupManager (`modules/BackupManager.ps1`)
- **Primary backup mechanism:**
  - Exports affected registry keys to `.reg` files under `backups/<timestamp>/`.
  - Saves a JSON manifest of all changes in that session (what was changed, original values, timestamps).
- **Secondary (non-fatal):**
  - Creates a System Restore Point via `Checkpoint-Computer` if available. If SRP is disabled or fails, the operation continues with a warning — **never** a hard block.
- `Revert-Session` reads the manifest and undoes changes in reverse order.

### 6. Reporter (`modules/Reporter.ps1`)
- Console table output (pretty print with alignment).
- HTML report export for sharing or archiving.
- Score breakdown per category: Privacy, Performance, UI, Debloat.

## Scoring algorithm (Debloat Completion Rate)
Given a **Snapshots** and a **Profile**:
1. Resolve the profile's `inherits` chain into a flat tweak list.
2. For each tweak, check whether the target item (package, service, task, registry key) is **still present** on the system.
3. Count:
   - `total = count of all tweaks in the resolved profile`
   - `present = count of tweaks whose target is still on the system`
   - `removed = total - present`
   - `score = round((removed / total) * 100)`
4. A score of 100 means the system matches the profile perfectly. 0 means nothing has been cleaned yet.

Additional metrics (informational, not part of score):
- Boot time delta (before vs after).
- Idle RAM delta.
- Idle process count delta.

## Logging (three-level)

All logs go to `<repo_root>/logs/<timestamp>/` (gitignored).

| Log type | File | Format | Purpose |
|---|---|---|---|
| **Session** | `session.json` | JSON | Full record of this run: what was checked, applied, skipped, errored |
| **Audit** | `audit.csv` | CSV (append-only) | Append-only history of every mutation across all sessions. One row per changed item. |
| **Error** | `error.log` | Plain text | Stack traces and non-recoverable errors, separated for easy triage |

## Module loading (`wintune.ps1`)

The entry point uses **explicit dot-sourcing** — no `.psd1` manifest:

```powershell
# wintune.ps1 — top of script
$script:ModuleRoot = Join-Path $PSScriptRoot "modules"
Get-ChildItem "$ModuleRoot/*.ps1" | ForEach-Object { . $_.FullName }
```

This keeps the dependency chain transparent and works without a module install step. Every module is re-loaded on each invocation — fine for a CLI tool that starts and exits.

## UI flow (CLI / TUI)
1. Pre-flight checks (admin, execution policy, build detection).
2. Welcome screen — choose mode: `Audit` or `Apply`.
3. If `Apply` — choose profile: `Gaming`, `Workstation`, `Laptop`, `Minimal`.
4. Scanner runs, shows live progress.
5. Report preview — list of changes + predicted score improvement.
6. Confirm (Y/n) or granular toggle per item (`-WhatIf` shows preview, `-Confirm` prompts per item).
7. Apply → Backup → Execute → Final report.

## File naming conventions
- PowerShell modules: PascalCase (`Scanner.ps1`, `BackupManager.ps1`).
- JSON manifests: kebab-case (`bloat-database.json`, `gaming-profile.json`).
- Tweak PowerShell files: kebab-case with category prefix (`disable-telemetry.ps1`, `remove-candy-crush.ps1`).
- Folders: lowercase (`src/`, `docs/`, `tests/`, `gui/`).

## Testing strategy
- Unit tests for each module with Pester.
- Mock registry / service / package calls so tests run safely on any machine.
- Test the module-loading scaffold (dot-source all modules in CI).
- Integration test on a Windows 11 VM after every major merge.

## What NOT to build
- An AI chatbot interface.
- A one-click "Fix everything" button without review.
- Automatic driver updates or Windows Update manipulation.
- Anything that cannot be reverted cleanly.
- Disabling Windows Defender or UAC without explicit `-Dangerous` flag.

## Development phases
See `ROADMAP.md`.
