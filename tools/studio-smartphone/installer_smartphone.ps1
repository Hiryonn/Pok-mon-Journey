# Installe l'éditeur « Smartphone » (plugin PokeSmart) dans Pokémon Studio
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
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
function Backup($p) { if (-not (Test-Path "$p.bak-smartphone")) { Copy-Item $p "$p.bak-smartphone" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-smartphone') | Out-Null
Copy-Item (Join-Path $here 'pj-smartphone-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-smartphone.js') (Join-Path $renderer 'pj-smartphone') -Force
Copy-Item (Join-Path $here 'pj-smartphone.css') (Join-Path $renderer 'pj-smartphone') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-smartphone') {
  Backup $html
  $tag = '<!-- pj-smartphone --><link rel="stylesheet" href="./pj-smartphone/pj-smartphone.css"><script defer src="./pj-smartphone/pj-smartphone.js"></script><!-- pj-smartphone -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-smartphone:preload') {
  Backup $preload
  $s += @'

/* pj-smartphone:preload */;(() => {
  // Smartphone (PokeSmart) — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'save'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-smartphone:' + n, payload); });
    contextBridge.exposeInMainWorld('pjSmartphone', api);
  } catch (e) { console.error('[pj-smartphone] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-smartphone:main') {
  Backup $index
  $s += "`n/* pj-smartphone:main */`ntry{require('./pj-smartphone-main.js')}catch(e){console.error('[pj-smartphone]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Éditeur Smartphone installé. Redémarre Pokémon Studio.' -ForegroundColor Green
