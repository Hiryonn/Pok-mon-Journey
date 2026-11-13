# Installe l'éditeur Cartes (éditeur de cartes façon Tiled) dans Pokémon Studio Extra
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
function Backup($p) { if (-not (Test-Path "$p.bak-cartes")) { Copy-Item $p "$p.bak-cartes" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-cartes') | Out-Null
Copy-Item (Join-Path $here 'pj-cartes-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-cartes.js') (Join-Path $renderer 'pj-cartes') -Force
Copy-Item (Join-Path $here 'pj-cartes.css') (Join-Path $renderer 'pj-cartes') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-cartes') {
  Backup $html
  $tag = '<!-- pj-cartes --><link rel="stylesheet" href="./pj-cartes/pj-cartes.css"><script defer src="./pj-cartes/pj-cartes.js"></script><!-- pj-cartes -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
}
Write-Text $html $s

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
$s = [regex]::Replace($s, '(?s)\s*/\* pj-cartes:preload \*/.*?\n\}\)\(\);', '')
if ($s -notmatch 'pj-cartes:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-cartes:preload */;(() => {
  // Cartes — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readText', 'readImage', 'mtime', 'writeText', 'list', 'exists', 'writeOverview'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-cartes:' + n, payload); });
    contextBridge.exposeInMainWorld('pjCartes', api);
  } catch (e) { console.error('[pj-cartes] preload', e); }
})();
'@
}
Write-Text $preload $s

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-cartes:main') {
  Backup $index
  $s += "`n/* pj-cartes:main */`ntry{require('./pj-cartes-main.js')}catch(e){console.error('[pj-cartes]',e)}`n"
}
Write-Text $index $s

# onglet « Cartes » dans la barre de gauche
python (Join-Path $here '..\studio-plugins\patch_studio_pages.py')
Write-Host 'Éditeur Cartes installé. Redémarre Pokémon Studio Extra.' -ForegroundColor Green
