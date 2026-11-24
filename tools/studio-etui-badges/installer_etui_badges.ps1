# Installe la page « Étui à badges » (Level design > Dresseurs > Étui à badges) dans Pokémon Studio
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
function Backup($p) { if (-not (Test-Path "$p.bak-etui-badges")) { Copy-Item $p "$p.bak-etui-badges" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-etui-badges') | Out-Null
Copy-Item (Join-Path $here 'pj-etui-badges-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-etui-badges.js') (Join-Path $renderer 'pj-etui-badges') -Force
Copy-Item (Join-Path $here 'pj-etui-badges.css') (Join-Path $renderer 'pj-etui-badges') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-etui-badges') {
  Backup $html
  $tag = '<!-- pj-etui-badges --><link rel="stylesheet" href="./pj-etui-badges/pj-etui-badges.css"><script defer src="./pj-etui-badges/pj-etui-badges.js"></script><!-- pj-etui-badges -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-etui-badges:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-etui-badges:preload */;(() => {
  // Étui à badges — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'save', 'buildPlugin', 'readImage', 'readSound', 'importImage'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-etui-badges:' + n, payload); });
    contextBridge.exposeInMainWorld('pjEtuiBadges', api);
  } catch (e) { console.error('[pj-etui-badges] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-etui-badges:main') {
  Backup $index
  $s += "`n/* pj-etui-badges:main */`ntry{require('./pj-etui-badges-main.js')}catch(e){console.error('[pj-etui-badges]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Éditeur Étui à badges installé. Redémarre Pokémon Studio.' -ForegroundColor Green
