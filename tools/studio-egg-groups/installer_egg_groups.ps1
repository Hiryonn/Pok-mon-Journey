# Installe la page « Groupes d'Œuf » (Données > Pokémon > Groupes d'Œuf) dans Pokémon Studio
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
function Backup($p) { if (-not (Test-Path "$p.bak-egg-groups")) { Copy-Item $p "$p.bak-egg-groups" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-egg-groups') | Out-Null
Copy-Item (Join-Path $here 'pj-egg-groups-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-egg-groups.js') (Join-Path $renderer 'pj-egg-groups') -Force
Copy-Item (Join-Path $here 'pj-egg-groups.css') (Join-Path $renderer 'pj-egg-groups') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-egg-groups') {
  Backup $html
  $tag = '<!-- pj-egg-groups --><link rel="stylesheet" href="./pj-egg-groups/pj-egg-groups.css"><script defer src="./pj-egg-groups/pj-egg-groups.js"></script><!-- pj-egg-groups -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-egg-groups:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-egg-groups:preload */;(() => {
  // Groupes d'Œuf — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'save', 'buildPlugin'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-egg-groups:' + n, payload); });
    contextBridge.exposeInMainWorld('pjEggGroups', api);
  } catch (e) { console.error('[pj-egg-groups] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-egg-groups:main') {
  Backup $index
  $s += "`n/* pj-egg-groups:main */`ntry{require('./pj-egg-groups-main.js')}catch(e){console.error('[pj-egg-groups]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Page Groupes d''Œuf installée. Redémarre Pokémon Studio.' -ForegroundColor Green
