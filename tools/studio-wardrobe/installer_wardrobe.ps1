# Installe la page "Tenues" (onglet Plugins) dans Pokemon Studio.
# A relancer apres chaque mise a jour de Studio. Studio doit etre ferme puis rouvert.
# Il faut aussi l'onglet Plugins : tools\studio-plugins\installer_pages.bat
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Join-Path $env:LOCALAPPDATA 'Programs\pokemon-studio\resources\app'
if (-not (Test-Path (Join-Path $app '.vite\build\index.js'))) {
  Write-Host "Studio introuvable (ou pas encore depaquete) : $app" -ForegroundColor Red
  exit 1
}
$utf8 = New-Object System.Text.UTF8Encoding $false
function Read-Text($p) { [System.IO.File]::ReadAllText($p, $utf8) }
function Write-Text($p, $s) { [System.IO.File]::WriteAllText($p, $s, $utf8) }
function Backup($p) { if (-not (Test-Path "$p.bak-wardrobe")) { Copy-Item $p "$p.bak-wardrobe" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-wardrobe') | Out-Null
Copy-Item (Join-Path $here 'pj-wardrobe-main.js') $build -Force
foreach ($f in 'pj-wardrobe.js', 'pj-wardrobe.css') {
  Copy-Item (Join-Path $here $f) (Join-Path $renderer 'pj-wardrobe') -Force
}

# page : feuille de style + scripts (la logique d'assemblage avant la page)
$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-wardrobe/pj-wardrobe.js') {
  Backup $html
  $tag = '<!-- pj-wardrobe --><link rel="stylesheet" href="./pj-wardrobe/pj-wardrobe.css"><script defer src="./pj-wardrobe/pj-wardrobe.js"></script><!-- pj-wardrobe -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

# preload : expose l'API au rendu
$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-wardrobe:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-wardrobe:preload */;(() => {
  // Tenues - exposition de l'API au rendu (ajoute par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readImage', 'saveOutfits', 'createItem'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-wardrobe:' + n, payload); });
    contextBridge.exposeInMainWorld('pjWardrobe', api);
  } catch (e) { console.error('[pj-wardrobe] preload', e); }
})();
'@
  Write-Text $preload $s
}

# processus principal : canaux IPC
$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-wardrobe:main') {
  Backup $index
  $s += "`n/* pj-wardrobe:main */`ntry{require('./pj-wardrobe-main.js')}catch(e){console.error('[pj-wardrobe]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Page Tenues installee. Redemarre Pokemon Studio (Plugins > Tenues).' -ForegroundColor Green
