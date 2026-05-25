# Backup Manifest Contract (v0.1)

This document defines the stable manifest written by `BackupManager`.

## Path
`<backupRoot>\<session>\manifest.json`

## Top-level fields
- `Session` (string, `yyyy-MM-dd_HH-mm-ss`)
- `Profile` (string)
- `CreatedAt` (ISO-8601 string)
- `RestorePoint` (string or null)
- `RegistryFile` (string path)
- `Changes` (array)

## Change entry fields
- `TweakId` (string)
- `Type` (`package` | `service` | `task` | `registry` | `command`)
- `Name` (string)
- `OriginalValue` (any or null)
- `NewValue` (any or null)
- `Timestamp` (ISO-8601 string)
- `Success` (boolean)
- `Error` (string or null)

## Compatibility policy
- Field names above are frozen for `v0.1`.
- New optional fields are allowed.
- Removal/rename/type-change is breaking.
