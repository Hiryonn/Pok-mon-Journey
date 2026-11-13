# Installe la section « Aseprite » dans Pokémon Studio Extra (Aseprite intégré, limité aux graphismes du projet)
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# Il faut aussi les pages de Studio (tools\studio-plugins\installer_pages.bat) et l'éditeur Smartphone (même style).
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Join-Path $env:LOCALAPPDATA 'Programs\pokemon-studio\resources\app'
if (-not (Test-Path (Join-Path $app '.vite\build\index.js'))) {
  Write-Host "Studio introuvable (ou pas encore dépaqueté) : $app" -ForegroundColor Red
  exit 1
}
$utf8 = New-Object System.Text.UTF8Encoding $false
function Read-Text($p) { [System.IO.File]::ReadAllText($p, $utf8) }
function Write-Text($p, $s) { [System.IO.File]::WriteAllText($p, $s, $utf8) }
function Backup($p) { if (-not (Test-Path "$p.bak-aseprite")) { Copy-Item $p "$p.bak-aseprite" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-aseprite') | Out-Null
foreach ($f in 'pj-aseprite-main.js', 'pj-aseprite-bridge.lua', 'pj-aseprite-win.ps1') { Copy-Item (Join-Path $here $f) $build -Force }
Copy-Item (Join-Path $here 'pj-aseprite.js') (Join-Path $renderer 'pj-aseprite') -Force
Copy-Item (Join-Path $here 'pj-aseprite.css') (Join-Path $renderer 'pj-aseprite') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-aseprite') {
  Backup $html
  $tag = '<!-- pj-aseprite --><link rel="stylesheet" href="./pj-aseprite/pj-aseprite.css"><script defer src="./pj-aseprite/pj-aseprite.js"></script><!-- pj-aseprite -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-aseprite:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-aseprite:preload */;(() => {
  // Aseprite — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'start', 'layout', 'focus', 'open', 'restart', 'pickExe', 'preview'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-aseprite:' + n, payload); });
    contextBridge.exposeInMainWorld('pjAseprite', api);
  } catch (e) { console.error('[pj-aseprite] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-aseprite:main') {
  Backup $index
  $s += "`n/* pj-aseprite:main */`ntry{require('./pj-aseprite-main.js')}catch(e){console.error('[pj-aseprite]',e)}`n"
  Write-Text $index $s
}

# onglet « Aseprite » dans la barre de gauche
python (Join-Path $here '..\studio-plugins\patch_studio_pages.py')
Write-Host 'Section Aseprite installée. Redémarre Pokémon Studio Extra.' -ForegroundColor Green
