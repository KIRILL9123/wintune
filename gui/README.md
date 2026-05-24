# WinTune GUI

Planned PySide6 (Qt) desktop application for WinTune.

## Status

**Not yet implemented.** The PowerShell engine (`src/`) must reach v0.1 stability before GUI development begins.

## Tech stack

- Python 3.11+
- PySide6 (Qt 6)
- No web technologies — this is a native Windows desktop app

## Communication with engine

The GUI never imports PowerShell modules or calls cmdlets directly. It communicates exclusively via the `wintune.ps1` CLI:

```python
import subprocess, json

result = subprocess.run(
    ["powershell", "-File", "src/wintune.ps1",
     "-Action", "Audit",
     "-Profile", "Gaming",
     "-OutputJson"],
    capture_output=True, text=True
)
snapshot = json.loads(result.stdout)
```

## Planned screens

| Screen | Purpose |
|---|---|
| Dashboard | Profile selector + action buttons (Audit, Apply, Revert, Report) |
| Audit Report | Debloat Completion Rate + per-category breakdown + per-tweak checkboxes |
| Apply Progress | Live progress bar with per-tweak succeed/fail/pending status |
| Revert | Session history browser with revert confirmation |
| Settings | Backup path, output path, dangerous mode toggle |
| Report Viewer | Inline HTML report preview or "Open in Browser" |

## Getting started (when ready)

```bash
cd gui
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

## Theme

Dark theme only (Windows 11 dark palette: `#0d1117` background, `#00f0ff` accent).
