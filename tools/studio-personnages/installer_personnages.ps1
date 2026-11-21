# Installe les pages Données > Personnages (Héros, Alliés) dans Pokémon Studio Extra
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# Il faut aussi les pages de Studio (tools\studio-plugins\installer_pages.bat) et l'éditeur Smartphone (même style).
# Le jeu lit les réglages avec le plugin scripts\personnages (construire_plugins.bat).
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
function Backup($p) { if (-not (Test-Path "$p.bak-personnages")) { Copy-Item $p "$p.bak-personnages" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-personnages') | Out-Null
Copy-Item (Join-Path $here 'pj-personnages-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-personnages.js') (Join-Path $renderer 'pj-personnages') -Force
Copy-Item (Join-Path $here 'pj-personnages.css') (Join-Path $renderer 'pj-personnages') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-personnages') {
  Backup $html
  $tag = '<!-- pj-personnages --><link rel="stylesheet" href="./pj-personnages/pj-personnages.css"><script defer src="./pj-personnages/pj-personnages.js"></script><!-- pj-personnages -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
}
Write-Text $html $s

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-personnages:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-personnages:preload */;(() => {
  // Personnages — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readImage', 'save', 'getMounts'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-personnages:' + n, payload); });
    contextBridge.exposeInMainWorld('pjPersonnages', api);
  } catch (e) { console.error('[pj-personnages] preload', e); }
})();
'@
}
# mise à jour d'une ancienne installation : montures (getMounts)
$s = $s.Replace("['getContext', 'readImage', 'save'].forEach", "['getContext', 'readImage', 'save', 'getMounts'].forEach")
Write-Text $preload $s

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-personnages:main') {
  Backup $index
  $s += "`n/* pj-personnages:main */`ntry{require('./pj-personnages-main.js')}catch(e){console.error('[pj-personnages]',e)}`n"
}
Write-Text $index $s

# Données > Personnages (menu et pages)
python (Join-Path $here '..\studio-plugins\patch_studio_pages.py')
Write-Host 'Personnages installé. Redémarre Pokémon Studio Extra.' -ForegroundColor Green
