---
name: ponytail-band
description: >
  Rebuild and open Ponytail Band, the local HTML activity dashboard tracking
  sessions, projects, turns, duration, Ponytail levels, and test results.
  Use for /ponytail-band, "ponytail band", "open ponytail board", "ver dashboard
  de ponytail", or "show my ponytail sessions".
---

# Ponytail Band (Antigravity Board)

Builds and shows the local self-contained HTML board from `%APPDATA%\ponytail\band\tasks.csv`
(or `$XDG_CONFIG_HOME/ponytail/band/tasks.csv` if set).

## Steps

1. Run the board generator script so `board.html` reflects the latest ledger:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.gemini\config\plugins\ponytail\hooks\ponytail-band-board.ps1"
   ```
2. Read the CSV ledger path printed (same folder as `board.html`, file `tasks.csv`) if it exists, and summarize in 2-3 lines: total sessions, projects, turns, and test pass rate.
3. Give the user a clickable `file:///` link to `board.html` so they can open it directly in their browser. If they ask to open it now, launch it with `Start-Process` or the browser tool.

## Boundaries

- One-shot display: does NOT change the active Ponytail level.
- Data stays 100% local. Never fabricate cost or token figures (Antigravity hooks do not expose them).
