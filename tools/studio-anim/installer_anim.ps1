# Installe l'éditeur « Animations des attaques » (Données > Attaques > Animations) dans Pokémon Studio
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
function Backup($p) { if (-not (Test-Path "$p.bak-anim")) { Copy-Item $p "$p.bak-anim" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-anim') | Out-Null
Copy-Item (Join-Path $here 'pj-anim-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-anim-runtime.rb') $build -Force
Copy-Item (Join-Path $here 'pj-anim.js') (Join-Path $renderer 'pj-anim') -Force
Copy-Item (Join-Path $here 'pj-anim.css') (Join-Path $renderer 'pj-anim') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-anim') {
  Backup $html
  $tag = '<!-- pj-anim --><link rel="stylesheet" href="./pj-anim/pj-anim.css"><script defer src="./pj-anim/pj-anim.js"></script><!-- pj-anim -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-anim:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-anim:preload */;(() => {
  // Animations — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'read', 'save', 'remove', 'installRuntime', 'importRmxp', 'readFile'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-anim:' + n, payload); });
    contextBridge.exposeInMainWorld('pjAnim', api);
  } catch (e) { console.error('[pj-anim] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-anim:main') {
  Backup $index
  $s += "`n/* pj-anim:main */`ntry{require('./pj-anim-main.js')}catch(e){console.error('[pj-anim]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Éditeur Animations installé. Redémarre Pokémon Studio.' -ForegroundColor Green
