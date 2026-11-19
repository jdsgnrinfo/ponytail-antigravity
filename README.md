# Ponytail for Antigravity

Adaptación nativa como plugin de **Antigravity** de [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (v5.3.3) — *modo lazy senior dev*: el cambio mínimo que resuelve completamente la tarea, sin sobre-ingeniería ni bloat.

## Qué incluye

### 7 Skills
| Skill | Uso | Descripción |
| :--- | :--- | :--- |
| **`ponytail`** | `/ponytail [lite\|full\|ultra\|off]` | Modo *lazy senior dev* (escalera de decisión YAGNI, diffs mínimos, tests donde hay riesgo). |
| **`ponytail-review`** | `/ponytail-review` | Revisión de calidad de cambios/diffs/PRs (bugs, seguridad, escala, tests faltantes, bloat). |
| **`ponytail-audit`** | `/ponytail-audit` | Auditoría completa del repositorio, rankeada en lenguaje simple. |
| **`ponytail-debt`** | `/ponytail-debt` | Lista todos los comentarios `shortcut:` / `ponytail:` como ledger de deuda técnica. |
| **`ponytail-gain`** | `/ponytail-gain` | Tabla con los resultados medidos del benchmark de Ponytail 5. |
| **`ponytail-band`** | `/ponytail-band` | Regenera y enlaza el tablero HTML local de actividad (`board.html`). |
| **`ponytail-help`** | `/ponytail-help` | Referencia rápida de niveles, skills y configuración. |

### Hooks nativos de Antigravity (`hooks.json`, Windows PowerShell)
Escritos en PowerShell nativo (sin dependencia de Node.js):
- **`SessionStart` / `PreInvocation`:** activan Ponytail con el nivel por defecto (`PONYTAIL_DEFAULT_MODE` > `%APPDATA%\ponytail\config.json` > `full`) y rastrean `/ponytail lite|full|ultra|off`, `/ponytail default <nivel>`, `stop ponytail` y `normal mode`.
- **`PostToolUse` (`run_command`):** detecta ejecuciones de tests (`pytest`, `vitest`, `jest`, `npm test`, `cargo test`, `go test`, etc.) y si pasaron o fallaron.
- **`Stop`:** registra cada sesión en `%APPDATA%\ponytail\band\tasks.csv` y genera un tablero local autocontenido en `%APPDATA%\ponytail\band\board.html`.

> **Nota sobre OS:** Las 7 skills funcionan en cualquier sistema operativo (Windows, macOS, Linux). Los scripts de `hooks/` incluidos actualmente están escritos en PowerShell para Windows.

---

## Instalación

### Opción 1: Antigravity CLI (recomendada)
```bash
agy plugin install https://github.com/jdsgnrinfo/ponytail-antigravity
```

### Opción 2: Instalación manual global (todos tus proyectos)
Cloná o descargá este repositorio dentro de:
- **Windows:** `%USERPROFILE%\.gemini\config\plugins\ponytail\`
- **macOS / Linux:** `~/.gemini/config/plugins/ponytail/`

```bash
git clone https://github.com/jdsgnrinfo/ponytail-antigravity.git ~/.gemini/config/plugins/ponytail
```

### Opción 3: Instalación por proyecto (compartida con tu equipo)
Copiá o cloná el repositorio dentro de `.agents/plugins/ponytail/` en la raíz de tu proyecto.

---

## Configuración del nivel por defecto

Resolución: variable de entorno > archivo de configuración > `full`.

- **Por comando en el chat:** `/ponytail default lite` (`lite`, `full`, `ultra` o `off`)
- **Variable de entorno:** `PONYTAIL_DEFAULT_MODE=ultra`
- **Archivo de configuración** (`%APPDATA%\ponytail\config.json` en Windows o `~/.config/ponytail/config.json` en macOS/Linux):
  ```json
  {
    "defaultMode": "full",
    "hideStatus": false
  }
  ```

---

## Créditos y licencia

Basado en [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) de Dietrich Gebert. Distribuido bajo licencia **MIT** (ver [LICENSE](./LICENSE)).
