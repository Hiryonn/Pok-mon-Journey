# Installe le « Générateur de personnages » (Données > Personnages) dans Pokémon Studio
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# Il faut aussi les pages de Studio : tools\studio-plugins\installer_pages.bat
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
function Backup($p) { if (-not (Test-Path "$p.bak-generateur")) { Copy-Item $p "$p.bak-generateur" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-generateur') | Out-Null
Copy-Item (Join-Path $here 'pj-generateur-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-generateur.js') (Join-Path $renderer 'pj-generateur') -Force
Copy-Item (Join-Path $here 'pj-generateur.css') (Join-Path $renderer 'pj-generateur') -Force
Copy-Item (Join-Path $here 'pj-recolor.js') (Join-Path $renderer 'pj-generateur') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -match 'pj-generateur/pj-generateur.js' -and $s -notmatch 'pj-generateur/pj-recolor.js') {
  Backup $html
  $s = $s.Replace('<script defer src="./pj-generateur/pj-generateur.js"></script>', '<script defer src="./pj-generateur/pj-generateur.js"></script><script defer src="./pj-generateur/pj-recolor.js"></script>')
  Write-Text $html $s
}
if ($s -notmatch 'pj-generateur/pj-generateur.js') {
  Backup $html
  $tag = '<!-- pj-generateur --><link rel="stylesheet" href="./pj-generateur/pj-generateur.css"><script defer src="./pj-generateur/pj-generateur.js"></script><script defer src="./pj-generateur/pj-recolor.js"></script><!-- pj-generateur -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -match 'pj-generateur:preload' -and $s -notmatch 'exportParts') {
  Backup $preload
  $s = $s.Replace("'pickFolder']", "'pickFolder', 'recolorList', 'readProjectImages', 'saveProjectImage', 'exportParts']").Replace("'saveProjectImage']", "'saveProjectImage', 'exportParts']")
  Write-Text $preload $s
}
if ($s -notmatch 'pj-generateur:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-generateur:preload */;(() => {
  // Générateur de personnages — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readImages', 'saveConfig', 'exportSprites', 'pickFolder', 'recolorList', 'readProjectImages', 'saveProjectImage', 'exportParts'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-generateur:' + n, payload); });
    contextBridge.exposeInMainWorld('pjGenerateur', api);
  } catch (e) { console.error('[pj-generateur] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-generateur:main') {
  Backup $index
  $s += "`n/* pj-generateur:main */`ntry{require('./pj-generateur-main.js')}catch(e){console.error('[pj-generateur]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Générateur de personnages installé. Redémarre Pokémon Studio.' -ForegroundColor Green
