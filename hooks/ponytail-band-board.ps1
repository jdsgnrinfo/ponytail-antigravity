# Ponytail Band Board generator (self-contained local HTML dashboard)
# Reads %APPDATA%\ponytail\band\tasks.csv and writes board.html (no server, no network).
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'ponytail-common.ps1')
Initialize-Utf8Console

function Build-PonytailBandBoard {
    $bandDir = Get-PonytailBandDir
    $csvPath = Join-Path $bandDir 'tasks.csv'
    $htmlPath = Join-Path $bandDir 'board.html'

    $rows = @()
    if (Test-Path -LiteralPath $csvPath) {
        try {
            $imported = Import-Csv -LiteralPath $csvPath -Encoding UTF8
            if ($imported) {
                $rows = @($imported)
            }
        } catch {}
    }

    $tasksJson = '[]'
    if ($rows.Count -gt 0) {
        $normalized = foreach ($r in $rows) {
            [PSCustomObject]@{
                key        = [string]$r.key
                started    = [string]$r.started
                project    = if ([string]::IsNullOrWhiteSpace($r.project)) { 'general' } else { [string]$r.project }
                name       = if ([string]::IsNullOrWhiteSpace($r.name)) { '(untitled session)' } else { [string]$r.name }
                level      = if ([string]::IsNullOrWhiteSpace($r.level)) { 'full' } else { [string]$r.level }
                model      = if ([string]::IsNullOrWhiteSpace($r.model)) { 'auto' } else { [string]$r.model }
                turns      = [int]($r.turns -as [int])
                elapsedSec = [int]($r.elapsed_sec -as [int])
                tests      = if ([string]::IsNullOrWhiteSpace($r.tests)) { 'none' } else { [string]$r.tests }
            }
        }
        $tasksJson = ConvertTo-Json -InputObject @($normalized) -Depth 4 -Compress
    }

    # Prevent closing script tag injection
    $safeTasksJson = $tasksJson -replace '</', '<\/'

    $html = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ponytail Band — Antigravity Board</title>
<style>
:root{color-scheme:dark;--bg:#09090b;--panel:#111113;--card:#141417;--line:#232328;--text:#f4f4f5;--muted:#a1a1aa;--faint:#71717a;--accent:#5fe08a;--ultra:#ff8a3d;--lite:#4cc3ff;--off:#71717a;--ok:#5fe08a;--okbg:#122519;--bad:#ff6b5b;--badbg:#2a1412;--nonebg:#1d1d22}
:root[data-theme=light]{color-scheme:light;--bg:#f6f6f4;--panel:#ffffff;--card:#ffffff;--line:#e4e4e7;--text:#18181b;--muted:#52525b;--faint:#71717a;--accent:#16a34a;--ultra:#ea580c;--lite:#0284c7;--off:#71717a;--ok:#15803d;--okbg:#dcfce7;--bad:#b91c1c;--badbg:#fee2e2;--nonebg:#f4f4f5}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;padding:28px 24px 48px}
.wrap{max-width:1120px;margin:0 auto}
header{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:24px;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:12px}
.dot{width:12px;height:12px;border-radius:999px;background:var(--accent);box-shadow:0 0 12px var(--accent)}
h1{margin:0;font-size:20px;font-weight:700;letter-spacing:-0.02em}
.sub{color:var(--muted);font-size:12px}
.controls{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
button{background:var(--card);color:var(--text);border:1px solid var(--line);border-radius:8px;padding:6px 12px;font:12px/1.2 inherit;cursor:pointer}
button:hover{border-color:var(--muted)}
button.active{background:var(--text);color:var(--bg);border-color:var(--text)}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-bottom:20px}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px}
.kpi .label{font-size:12px;color:var(--muted);margin-bottom:6px}
.kpi .val{font:700 24px/1.1 ui-monospace,SFMono-Regular,Menlo,monospace}
.kpi .hint{font-size:11px;color:var(--faint);margin-top:6px}
.grid2{display:grid;grid-template-columns:2fr 1fr;gap:12px;margin-bottom:20px}
@media(max-width:820px){.grid2{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px}
.card h2{margin:0 0 12px;font-size:13px;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:.05em}
.bars{display:flex;align-items:flex-end;gap:6px;height:110px;padding-top:8px}
.bar-col{flex:1;display:flex;flex-direction:column;align-items:center;gap:4px;min-width:0}
.bar{width:100%;max-width:28px;background:var(--accent);border-radius:4px 4px 0 0;min-height:3px;opacity:.88}
.bar-lbl{font:10px/1 ui-monospace,monospace;color:var(--faint);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}
.levels{display:flex;flex-direction:column;gap:10px}
.lvl-row{display:flex;align-items:center;gap:10px;font-size:12px}
.lvl-name{width:54px;font:600 11px/1 ui-monospace,monospace;text-transform:uppercase}
.lvl-track{flex:1;height:8px;background:var(--nonebg);border-radius:999px;overflow:hidden}
.lvl-fill{height:100%;border-radius:999px}
.lvl-cnt{width:32px;text-align:right;font:12px/1 ui-monospace,monospace;color:var(--muted)}
table{width:100%;border-collapse:collapse;font-size:13px}
th{text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:var(--muted);padding:10px 8px;border-bottom:1px solid var(--line)}
td{padding:10px 8px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:none}
.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px}
.pill{display:inline-block;padding:2px 8px;border-radius:999px;font:600 11px/1.3 ui-monospace,monospace;text-transform:uppercase}
.p-full{background:rgba(95,224,138,.14);color:var(--accent)}
.p-ultra{background:rgba(255,138,61,.16);color:var(--ultra)}
.p-lite{background:rgba(76,195,255,.16);color:var(--lite)}
.p-off{background:var(--nonebg);color:var(--off)}
.t-pass{background:var(--okbg);color:var(--ok)}
.t-fail{background:var(--badbg);color:var(--bad)}
.t-none{background:var(--nonebg);color:var(--faint)}
.empty{padding:28px;text-align:center;color:var(--muted)}
footer{margin-top:20px;font-size:11px;color:var(--faint);display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="brand">
      <div class="dot"></div>
      <div>
        <h1>Ponytail Band</h1>
        <div class="sub">Local Antigravity session ledger &amp; activity board</div>
      </div>
    </div>
    <div class="controls">
      <div id="projectFilters" class="controls"></div>
      <button id="themeBtn" type="button">Light / Dark</button>
    </div>
  </header>

  <section class="kpis" id="kpis"></section>

  <section class="grid2">
    <div class="card">
      <h2>Daily Activity (last 14 days)</h2>
      <div class="bars" id="dailyChart"></div>
    </div>
    <div class="card">
      <h2>Ponytail Levels</h2>
      <div class="levels" id="levelChart"></div>
    </div>
  </section>

  <section class="card">
    <h2>Sessions</h2>
    <div style="overflow-x:auto">
      <table>
        <thead>
          <tr>
            <th>Started</th>
            <th>Project</th>
            <th>Task</th>
            <th>Level</th>
            <th>Model</th>
            <th>Turns</th>
            <th>Duration</th>
            <th>Tests</th>
          </tr>
        </thead>
        <tbody id="rows"></tbody>
      </table>
    </div>
  </section>

  <footer>
    <span>Data stays local on your machine (%APPDATA%\ponytail\band\tasks.csv).</span>
    <span>Note: Antigravity hooks do not expose USD cost or exact token counts.</span>
  </footer>
</div>
<script>
const TASKS = __TASKS_JSON__;
let selectedProject = 'ALL';

const esc = s => String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const fmtDur = sec => {
  sec = Math.max(0, Number(sec) || 0);
  if (sec < 60) return sec + 's';
  const m = Math.floor(sec / 60), s = sec % 60;
  if (m < 60) return m + 'm ' + s + 's';
  return Math.floor(m / 60) + 'h ' + (m % 60) + 'm';
};
const fmtDate = iso => {
  const d = new Date(iso);
  if (isNaN(d)) return iso || '';
  return d.toLocaleString(undefined, { month:'short', day:'numeric', hour:'2-digit', minute:'2-digit' });
};
const dayKey = iso => {
  const d = new Date(iso);
  if (isNaN(d)) return '';
  return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
};

function render() {
  const projects = ['ALL', ...Array.from(new Set(TASKS.map(t => t.project))).sort()];
  document.getElementById('projectFilters').innerHTML = projects.map(p =>
    `<button type="button" class="${p===selectedProject?'active':''}" data-p="${esc(p)}">${esc(p==='ALL'?'All projects':p)}</button>`
  ).join('');
  document.querySelectorAll('#projectFilters button').forEach(b => {
    b.onclick = () => { selectedProject = b.dataset.p; render(); };
  });

  const list = (selectedProject === 'ALL' ? TASKS : TASKS.filter(t => t.project === selectedProject))
    .slice().sort((a,b) => (b.started || '').localeCompare(a.started || ''));

  const totalSessions = list.length;
  const totalTurns = list.reduce((s,t) => s + (t.turns||0), 0);
  const totalSec = list.reduce((s,t) => s + (t.elapsedSec||0), 0);
  const tested = list.filter(t => t.tests === 'pass' || t.tests === 'fail');
  const passed = tested.filter(t => t.tests === 'pass').length;
  const testRate = tested.length ? Math.round(passed / tested.length * 100) + '%' : '—';

  document.getElementById('kpis').innerHTML = `
    <div class="kpi"><div class="label">Sessions</div><div class="val">${totalSessions}</div><div class="hint">${projects.length - 1} project(s)</div></div>
    <div class="kpi"><div class="label">Agent Turns</div><div class="val">${totalTurns}</div><div class="hint">avg ${totalSessions ? (totalTurns/totalSessions).toFixed(1) : '0'} / session</div></div>
    <div class="kpi"><div class="label">Total Time</div><div class="val">${fmtDur(totalSec)}</div><div class="hint">wall time across sessions</div></div>
    <div class="kpi"><div class="label">Tests Passed</div><div class="val">${testRate}</div><div class="hint">${passed}/${tested.length} tested session(s)</div></div>
  `;

  // Last 14 days bar chart
  const counts = {};
  list.forEach(t => { const k = dayKey(t.started); if (k) counts[k] = (counts[k]||0) + 1; });
  const days = [];
  for (let i = 13; i >= 0; i--) {
    const d = new Date(Date.now() - i * 86400000);
    const k = dayKey(d.toISOString());
    days.push({ k, lbl: String(d.getDate()), c: counts[k] || 0 });
  }
  const maxC = Math.max(1, ...days.map(d => d.c));
  document.getElementById('dailyChart').innerHTML = days.map(d =>
    `<div class="bar-col" title="${d.k}: ${d.c} session(s)"><div class="bar" style="height:${d.c ? Math.max(8, Math.round(d.c/maxC*84)) : 3}px;opacity:${d.c?0.9:0.15}"></div><div class="bar-lbl">${d.lbl}</div></div>`
  ).join('');

  // Level breakdown
  const lvls = [
    { k:'full', color:'var(--accent)' },
    { k:'ultra', color:'var(--ultra)' },
    { k:'lite', color:'var(--lite)' },
    { k:'off', color:'var(--off)' },
  ];
  document.getElementById('levelChart').innerHTML = lvls.map(l => {
    const c = list.filter(t => (t.level||'full') === l.k).length;
    const pct = totalSessions ? Math.round(c / totalSessions * 100) : 0;
    return `<div class="lvl-row"><span class="lvl-name">${l.k}</span><div class="lvl-track"><div class="lvl-fill" style="width:${pct}%;background:${l.color}"></div></div><span class="lvl-cnt">${c}</span></div>`;
  }).join('');

  // Rows
  const tbody = document.getElementById('rows');
  if (!list.length) {
    tbody.innerHTML = '<tr><td colspan="8" class="empty">No sessions recorded yet. Complete a turn in Antigravity to see it here.</td></tr>';
  } else {
    tbody.innerHTML = list.map(t => `
      <tr>
        <td class="mono">${esc(fmtDate(t.started))}</td>
        <td class="mono">${esc(t.project)}</td>
        <td>${esc(t.name)}</td>
        <td><span class="pill p-${esc(t.level)}">${esc(t.level)}</span></td>
        <td class="mono">${esc(t.model)}</td>
        <td class="mono">${t.turns}</td>
        <td class="mono">${fmtDur(t.elapsedSec)}</td>
        <td><span class="pill t-${esc(t.tests)}">${esc(t.tests)}</span></td>
      </tr>
    `).join('');
  }
}

document.getElementById('themeBtn').onclick = () => {
  const root = document.documentElement;
  const next = root.getAttribute('data-theme') === 'light' ? 'dark' : 'light';
  root.setAttribute('data-theme', next);
  try { localStorage.setItem('ponytail-band-theme', next); } catch {}
};
try {
  const saved = localStorage.getItem('ponytail-band-theme');
  if (saved) document.documentElement.setAttribute('data-theme', saved);
} catch {}
render();
</script>
</body>
</html>
'@

    $finalHtml = $html.Replace('__TASKS_JSON__', $safeTasksJson)
    [System.IO.File]::WriteAllText($htmlPath, $finalHtml, (New-Object System.Text.UTF8Encoding($false)))
    return $htmlPath
}

if ($MyInvocation.InvocationName -ne '.') {
    $out = Build-PonytailBandBoard
    Write-Output $out
}
