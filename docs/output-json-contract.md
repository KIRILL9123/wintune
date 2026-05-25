# Output JSON Contract (v0.1)

This document defines the stable machine-readable output for `-OutputJson`.

## Rules
- UTF-8 JSON only.
- No interactive prompts in JSON mode.
- Top-level object must always contain `Action`.
- On fatal error, JSON must contain `success=false` and `error`.

## Action shapes

### `List`
Array of profile objects:
- `Name` (string)
- `Description` (string)
- `Inherits` (string or null)
- `TweakCount` (number)
- `Dangerous` (boolean)

### `Audit`
Object:
- `Action` = `"Audit"`
- `Profile` (object)
- `Snapshot` (object)
- `Score` (object with `Total`, `Present`, `Removed`, `Score`)

### `Apply`
Object:
- `Action` = `"Apply"` or `"WhatIf"`
- `Profile` (object)
- `Score` (object)
- `Changes` (array or null)
- `Backup` (object or null)

### `Revert`
Object:
- `Action` = `"Revert"`
- `Session` (string)
- `Results` (array)

## Exit codes
| Code | Condition |
|------|-----------|
| `0`  | Success — action completed normally |
| `1`  | Error — missing/invalid argument, admin required, I/O failure |

## Compatibility policy
- Existing fields cannot be removed or renamed in `v0.1`.
- New fields must be additive and optional.
- Type changes are breaking changes.
