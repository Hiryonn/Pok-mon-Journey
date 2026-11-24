# Installe l'éditeur de code (façon VS Code, moteur Monaco) dans Pokémon Studio Extra
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# Il faut aussi les pages de Studio (tools\studio-plugins\installer_pages.bat) et l'éditeur Smartphone (même style).
# monaco.js / monaco.css : moteur de VS Code, refait avec tools\studio-code\build\construire_monaco.bat
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
function Backup($p) { if (-not (Test-Path "$p.bak-code")) { Copy-Item $p "$p.bak-code" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-code') | Out-Null
Copy-Item (Join-Path $here 'pj-code-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-code.js') (Join-Path $renderer 'pj-code') -Force
Copy-Item (Join-Path $here 'pj-code.css') (Join-Path $renderer 'pj-code') -Force
Copy-Item (Join-Path $here 'monaco.js') (Join-Path $renderer 'pj-code') -Force
Copy-Item (Join-Path $here 'monaco.css') (Join-Path $renderer 'pj-code') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-code') {
  Backup $html
  $tag = '<!-- pj-code --><link rel="stylesheet" href="./pj-code/pj-code.css"><script defer src="./pj-code/pj-code.js"></script><!-- pj-code -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
}
Write-Text $html $s

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-code:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-code:preload */;(() => {
  // Éditeur de code — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'list', 'read', 'stat', 'write', 'create', 'rename', 'trash', 'reveal', 'index', 'search'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-code:' + n, payload); });
    contextBridge.exposeInMainWorld('pjCode', api);
  } catch (e) { console.error('[pj-code] preload', e); }
})();
'@
}
Write-Text $preload $s

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-code:main') {
  Backup $index
  $s += "`n/* pj-code:main */`ntry{require('./pj-code-main.js')}catch(e){console.error('[pj-code]',e)}`n"
}
Write-Text $index $s

# onglet « Code » dans la barre de gauche
python (Join-Path $here '..\studio-plugins\patch_studio_pages.py')
Write-Host 'Éditeur de code installé. Redémarre Pokémon Studio Extra.' -ForegroundColor Green
