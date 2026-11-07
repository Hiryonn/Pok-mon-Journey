# Installe l'éditeur « Advanced Pokédex » (pages Taille et Poids du Pokédex) dans Pokémon Studio
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
function Backup($p) { if (-not (Test-Path "$p.bak-adex")) { Copy-Item $p "$p.bak-adex" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-adex') | Out-Null
Copy-Item (Join-Path $here 'pj-adex-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-adex.js') (Join-Path $renderer 'pj-adex') -Force
Copy-Item (Join-Path $here 'pj-adex.css') (Join-Path $renderer 'pj-adex') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-adex') {
  Backup $html
  $tag = '<!-- pj-adex --><link rel="stylesheet" href="./pj-adex/pj-adex.css"><script defer src="./pj-adex/pj-adex.js"></script><!-- pj-adex -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-adex:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-adex:preload */;(() => {
  // Advanced Pokédex — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readImages', 'save', 'buildPlugin', 'pluginStatus'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-adex:' + n, payload); });
    contextBridge.exposeInMainWorld('pjAdex', api);
  } catch (e) { console.error('[pj-adex] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-adex:main') {
  Backup $index
  $s += "`n/* pj-adex:main */`ntry{require('./pj-adex-main.js')}catch(e){console.error('[pj-adex]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Éditeur Advanced Pokédex installé. Redémarre Pokémon Studio.' -ForegroundColor Green
