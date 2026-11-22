# Installe l'éditeur d'évènements (Monde > Évènements) dans Pokémon Studio Extra
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# Il faut aussi les pages de Studio (tools\studio-plugins\installer_pages.bat).
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
function Backup($p) { if (-not (Test-Path "$p.bak-events")) { Copy-Item $p "$p.bak-events" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-events') | Out-Null
Copy-Item (Join-Path $here 'pj-events-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-events-runtime.rb') $build -Force
Copy-Item (Join-Path $here 'pj-events.js') (Join-Path $renderer 'pj-events') -Force
Copy-Item (Join-Path $here 'pj-events.css') (Join-Path $renderer 'pj-events') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-events') {
  Backup $html
  $tag = '<!-- pj-events --><link rel="stylesheet" href="./pj-events/pj-events.css"><script defer src="./pj-events/pj-events.js"></script><!-- pj-events -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
}
Write-Text $html $s

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if (($s -match 'pj-events:preload') -and ($s -notmatch 'upsertPluginEntry')) {
  Backup $preload
  $s = $s.Replace("'installRuntime']", "'installRuntime', 'upsertPluginEntry']")
}
if ($s -notmatch 'pj-events:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-events:preload */;(() => {
  // Éditeur d'évènements — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readMapEvents', 'saveMapEvents', 'readCommonEvents', 'saveCommonEvents', 'readRmxpEvents', 'readRmxpCommonEvents', 'installRuntime', 'upsertPluginEntry'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-events:' + n, payload); });
    contextBridge.exposeInMainWorld('pjEvents', api);
  } catch (e) { console.error('[pj-events] preload', e); }
})();
'@
}
Write-Text $preload $s

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-events:main') {
  Backup $index
  $s += "`n/* pj-events:main */`ntry{require('./pj-events-main.js')}catch(e){console.error('[pj-events]',e)}`n"
}
Write-Text $index $s

# page Monde > Évènements
python (Join-Path $here '..\studio-plugins\patch_studio_pages.py')
Write-Host "Éditeur d'évènements installé. Redémarre Pokémon Studio Extra." -ForegroundColor Green
