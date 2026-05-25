# WinTune GUI (WPF)

WPF C# (.NET) desktop application for WinTune.

## Status

Scaffolded. PowerShell core (`src/`) remains fully independent. GUI uses CLI JSON only.

## Tech stack

- .NET 8 (WPF)
- ModernWpf.UI (Windows 11 Fluent styling)
- Dark theme by default

## Communication with engine

The GUI never imports PowerShell modules or calls cmdlets directly. It communicates exclusively via the `wintune.ps1` CLI:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\src\wintune.ps1' -Action Audit -Profile Gaming -OutputJson"
```

## Planned screens

| Screen | Purpose |
|---|---|
| Dashboard | Debloat score + action buttons (Audit, Apply, Revert) |
| Profile Selector | Cards for Gaming, Workstation, Laptop, Minimal |
| Audit Results | DataGrid: tweak ID, type, risk, state, include checkbox |
| Apply Progress | Per-tweak progress list + overall progress |
| Revert | Session history with per-row Revert action |

## Build and run

```bash
dotnet run --project gui/WinTune.Gui
```
