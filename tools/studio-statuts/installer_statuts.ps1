# Installe l'éditeur « Statuts » (Données > Statuts : Saignement et autres statuts du projet) dans Pokémon Studio
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
function Backup($p) { if (-not (Test-Path "$p.bak-statuts")) { Copy-Item $p "$p.bak-statuts" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-statuts') | Out-Null
Copy-Item (Join-Path $here 'pj-statuts-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-statuts.js') (Join-Path $renderer 'pj-statuts') -Force
Copy-Item (Join-Path $here 'pj-statuts.css') (Join-Path $renderer 'pj-statuts') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-statuts') {
  Backup $html
  $tag = '<!-- pj-statuts --><link rel="stylesheet" href="./pj-statuts/pj-statuts.css"><script defer src="./pj-statuts/pj-statuts.js"></script><!-- pj-statuts -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-statuts:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-statuts:preload */;(() => {
  // Statuts — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'save', 'buildPlugin'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-statuts:' + n, payload); });
    contextBridge.exposeInMainWorld('pjStatuts', api);
  } catch (e) { console.error('[pj-statuts] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-statuts:main') {
  Backup $index
  $s += "`n/* pj-statuts:main */`ntry{require('./pj-statuts-main.js')}catch(e){console.error('[pj-statuts]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Éditeur Statuts installé. Redémarre Pokémon Studio.' -ForegroundColor Green
