# Installe l'éditeur « Triple Triad » (cartes, adversaires, boutique) dans Pokémon Studio
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# L'éditeur Smartphone doit être installé avant (même style, même section « Plugins »).
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Join-Path $env:LOCALAPPDATA 'Programs\pokemon-studio\resources\app'
if (-not (Test-Path (Join-Path $app '.vite\build\index.js'))) {
  Write-Host "Studio introuvable (ou pas encore dépaqueté) : $app" -ForegroundColor Red
  Write-Host "Installe d'abord l'éditeur d'évents (il dépaquette Studio), puis relance ce script."
  exit 1
}
$utf8 = New-Object System.Text.UTF8Encoding $false
function Read-Text($p) { [System.IO.File]::ReadAllText($p, $utf8) }
function Write-Text($p, $s) { [System.IO.File]::WriteAllText($p, $s, $utf8) }
function Backup($p) { if (-not (Test-Path "$p.bak-triad")) { Copy-Item $p "$p.bak-triad" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-triad') | Out-Null
Copy-Item (Join-Path $here 'pj-triad-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-triad.js') (Join-Path $renderer 'pj-triad') -Force
Copy-Item (Join-Path $here 'pj-triad.css') (Join-Path $renderer 'pj-triad') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-triad/pj-triad.js') {
  Backup $html
  $tag = '<!-- pj-triad --><link rel="stylesheet" href="./pj-triad/pj-triad.css"><script defer src="./pj-triad/pj-triad.js"></script><!-- pj-triad -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-triad:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-triad:preload */;(() => {
  // Triple Triad — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readIcons', 'readItemIcons', 'save', 'buildPlugin', 'pluginStatus'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-triad:' + n, payload); });
    contextBridge.exposeInMainWorld('pjTriad', api);
  } catch (e) { console.error('[pj-triad] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-triad:main') {
  Backup $index
  $s += "`n/* pj-triad:main */`ntry{require('./pj-triad-main.js')}catch(e){console.error('[pj-triad]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Éditeur Triple Triad installé. Redémarre Pokémon Studio.' -ForegroundColor Green
