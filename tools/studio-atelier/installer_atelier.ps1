# Installe l'Atelier (éditeur d'images du projet) dans Pokémon Studio Extra
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# Il faut aussi les pages de Studio (tools\studio-plugins\installer_pages.bat) et l'éditeur Smartphone (même style).
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
function Backup($p) { if (-not (Test-Path "$p.bak-atelier")) { Copy-Item $p "$p.bak-atelier" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-atelier') | Out-Null
Copy-Item (Join-Path $here 'pj-atelier-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-atelier.js') (Join-Path $renderer 'pj-atelier') -Force
Copy-Item (Join-Path $here 'pj-atelier.css') (Join-Path $renderer 'pj-atelier') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
$s = [regex]::Replace($s, '\s*<!-- pj-aseprite -->.*?<!-- pj-aseprite -->', '')
if ($s -notmatch 'pj-atelier') {
  Backup $html
  $tag = '<!-- pj-atelier --><link rel="stylesheet" href="./pj-atelier/pj-atelier.css"><script defer src="./pj-atelier/pj-atelier.js"></script><!-- pj-atelier -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
}
Write-Text $html $s

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
$s = [regex]::Replace($s, '(?s)\s*/\* pj-aseprite:preload \*/.*?\n\}\)\(\);', '')
if ($s -notmatch 'pj-atelier:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-atelier:preload */;(() => {
  // Atelier — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'read', 'exists', 'write', 'mkdir'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-atelier:' + n, payload); });
    contextBridge.exposeInMainWorld('pjAtelier', api);
  } catch (e) { console.error('[pj-atelier] preload', e); }
})();
'@
}
Write-Text $preload $s

$index = Join-Path $build 'index.js'
$s = Read-Text $index
$s = [regex]::Replace($s, '\s*/\* pj-aseprite:main \*/\s*try\{require\(''\./pj-aseprite-main\.js''\)\}catch\(e\)\{console\.error\(''\[pj-aseprite\]'',e\)\}', '')
if ($s -notmatch 'pj-atelier:main') {
  Backup $index
  $s += "`n/* pj-atelier:main */`ntry{require('./pj-atelier-main.js')}catch(e){console.error('[pj-atelier]',e)}`n"
}
Write-Text $index $s

# onglet « Atelier » dans la barre de gauche
python (Join-Path $here '..\studio-plugins\patch_studio_pages.py')
Write-Host 'Atelier installé. Redémarre Pokémon Studio Extra.' -ForegroundColor Green
