---
name: ponytail-help
description: >
  Quick reference for ponytail levels, skills and commands. One-shot display.
  Use for /ponytail-help, "ponytail help", "how do I use ponytail".
---

# Ponytail Help

Display this reference card when invoked. One-shot, do NOT change mode,
write flag files, or persist anything.

## Levels

| Level | Trigger | What changes |
|-------|---------|--------------|
| **Lite** | `/ponytail lite` | Build what was asked, name the smaller option in one line. |
| **Full** | `/ponytail full` (or `/ponytail`) | The smallest complete change, a check where the logic needs one, and a reply that names what was skipped and any risk. Default. |
| **Ultra** | `/ponytail ultra` | Also questions the request and pushes back before building. |

Level sticks until changed or session end.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| **ponytail** | `/ponytail` | Lazy mode itself: least new code, clear replies that name skipped work and risks. |
| **ponytail-review** | `/ponytail-review` | Quality review of a diff: bugs, security, load, missing tests, speed, what to cut. Each finding says what goes wrong and how to fix it. |
| **ponytail-audit** | `/ponytail-audit` | The same quality review for the whole repo, ranked. |
| **ponytail-debt** | `/ponytail-debt` | Harvest `shortcut:` comments into a tracked ledger. |
| **ponytail-gain** | `/ponytail-gain` | Measured-impact scoreboard: less code, less cost, more speed. |
| **ponytail-band** | `/ponytail-band` | Local HTML activity board (sessions, projects, levels, turns, duration, tests). |
| **ponytail-help** | `/ponytail-help` | This card. |

## Status Badge & Band Board (Antigravity)

- **Inline badge:** Shows `[PONYTAIL:FULL]` / `⚡ [PONYTAIL:ULTRA]` / `[PONYTAIL:LITE]` / `[PONYTAIL:OFF]` inline on session start and level changes. To hide it, set `PONYTAIL_HIDE_STATUS=1` or `"hideStatus": true` in `%APPDATA%\ponytail\config.json`.
- **Band Board:** Recorded automatically on each completed turn (`Stop`) and test run (`PostToolUse`) into `%APPDATA%\ponytail\band\tasks.csv` and rendered to `%APPDATA%\ponytail\band\board.html`. Run `/ponytail-band` to refresh and open it.

## Deactivate

Say `"stop ponytail"` or `"normal mode"`, or run `/ponytail off`. Resume anytime with `/ponytail`.

## Configure Default Mode

Default mode = `full`, auto-active every session via Antigravity lifecycle hooks. Change it:

**Command** (persists to config):
```text
/ponytail default lite
```
(Valid values: `lite`, `full`, `ultra`, `off`.)

**Environment variable** (highest priority):
```powershell
$env:PONYTAIL_DEFAULT_MODE = "ultra"
```

**Config file** (`%APPDATA%\ponytail\config.json` on Windows, `~/.config/ponytail/config.json` on macOS/Linux):
```json
{ "defaultMode": "lite" }
```

Set `"off"` to disable auto-activation on session start, and activate manually with `/ponytail` when wanted.

Resolution: env var > config file > `full`.

## More

Full docs + examples: https://github.com/DietrichGebert/ponytail
