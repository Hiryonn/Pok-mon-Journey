# Ajoute le bouton « Importer de Pokéngine » au panneau « Nouveau Pokémon » de Pokémon Studio
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
function Backup($p) { if (-not (Test-Path "$p.bak-pokengine")) { Copy-Item $p "$p.bak-pokengine" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-pokengine') | Out-Null
Copy-Item (Join-Path $here 'pj-pokengine-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-pokengine.js') (Join-Path $renderer 'pj-pokengine') -Force
Copy-Item (Join-Path $here 'pj-pokengine.css') (Join-Path $renderer 'pj-pokengine') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-pokengine') {
  Backup $html
  $tag = '<!-- pj-pokengine --><link rel="stylesheet" href="./pj-pokengine/pj-pokengine.css"><script defer src="./pj-pokengine/pj-pokengine.js"></script><!-- pj-pokengine -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-pokengine:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-pokengine:preload */;(() => {
  // Importer de Pokéngine — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['choisir', 'importer'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-pokengine:' + n, payload); });
    contextBridge.exposeInMainWorld('pjMementos', api);
  } catch (e) { console.error('[pj-pokengine] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-pokengine:main') {
  Backup $index
  $s += "`n/* pj-pokengine:main */`ntry{require('./pj-pokengine-main.js')}catch(e){console.error('[pj-pokengine]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Bouton Importer de Pokéngine installé. Redémarre Pokémon Studio.' -ForegroundColor Green
