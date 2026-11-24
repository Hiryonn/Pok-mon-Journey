# Installe la page « Rubans et insignes » (Données > Pokémon > Rubans et insignes) dans Pokémon Studio
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# L'éditeur Smartphone doit être installé avant (même style).
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
function Backup($p) { if (-not (Test-Path "$p.bak-mementos")) { Copy-Item $p "$p.bak-mementos" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-mementos') | Out-Null
Copy-Item (Join-Path $here 'pj-mementos-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-mementos.js') (Join-Path $renderer 'pj-mementos') -Force
Copy-Item (Join-Path $here 'pj-mementos.css') (Join-Path $renderer 'pj-mementos') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-mementos') {
  Backup $html
  $tag = '<!-- pj-mementos --><link rel="stylesheet" href="./pj-mementos/pj-mementos.css"><script defer src="./pj-mementos/pj-mementos.js"></script><!-- pj-mementos -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-mementos:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-mementos:preload */;(() => {
  // Rubans et insignes — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'save', 'buildPlugin', 'readImage'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-mementos:' + n, payload); });
    contextBridge.exposeInMainWorld('pjMementos', api);
  } catch (e) { console.error('[pj-mementos] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-mementos:main') {
  Backup $index
  $s += "`n/* pj-mementos:main */`ntry{require('./pj-mementos-main.js')}catch(e){console.error('[pj-mementos]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Page Rubans et insignes installée. Redémarre Pokémon Studio.' -ForegroundColor Green
