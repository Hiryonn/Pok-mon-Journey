# Installe l'éditeur « Variantes » (Pokémon Argentés, Dorés, Radiants) dans Pokémon Studio
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
function Backup($p) { if (-not (Test-Path "$p.bak-variantes")) { Copy-Item $p "$p.bak-variantes" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-variantes') | Out-Null
Copy-Item (Join-Path $here 'pj-variantes-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-variantes.js') (Join-Path $renderer 'pj-variantes') -Force
Copy-Item (Join-Path $here 'pj-variantes.css') (Join-Path $renderer 'pj-variantes') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-variantes') {
  Backup $html
  $tag = '<!-- pj-variantes --><link rel="stylesheet" href="./pj-variantes/pj-variantes.css"><script defer src="./pj-variantes/pj-variantes.js"></script><!-- pj-variantes -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-variantes:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-variantes:preload */;(() => {
  // Variantes — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readImages', 'save', 'buildPlugin', 'pluginStatus'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-variantes:' + n, payload); });
    contextBridge.exposeInMainWorld('pjVariantes', api);
  } catch (e) { console.error('[pj-variantes] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-variantes:main') {
  Backup $index
  $s += "`n/* pj-variantes:main */`ntry{require('./pj-variantes-main.js')}catch(e){console.error('[pj-variantes]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Éditeur Variantes installé. Redémarre Pokémon Studio.' -ForegroundColor Green
