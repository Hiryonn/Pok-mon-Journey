# Installe l'éditeur « Gimmicks » (Méga, capacités Z, Dynamax, Téracristal) dans Pokémon Studio
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
function Backup($p) { if (-not (Test-Path "$p.bak-gimmicks")) { Copy-Item $p "$p.bak-gimmicks" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-gimmicks') | Out-Null
Copy-Item (Join-Path $here 'pj-gimmicks-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-gimmicks.js') (Join-Path $renderer 'pj-gimmicks') -Force
Copy-Item (Join-Path $here 'pj-gimmicks.css') (Join-Path $renderer 'pj-gimmicks') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-gimmicks') {
  Backup $html
  $tag = '<!-- pj-gimmicks --><link rel="stylesheet" href="./pj-gimmicks/pj-gimmicks.css"><script defer src="./pj-gimmicks/pj-gimmicks.js"></script><!-- pj-gimmicks -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-gimmicks:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-gimmicks:preload */;(() => {
  // Gimmicks — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readImages', 'save', 'buildPlugin', 'pluginStatus'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-gimmicks:' + n, payload); });
    contextBridge.exposeInMainWorld('pjGimmicks', api);
  } catch (e) { console.error('[pj-gimmicks] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-gimmicks:main') {
  Backup $index
  $s += "`n/* pj-gimmicks:main */`ntry{require('./pj-gimmicks-main.js')}catch(e){console.error('[pj-gimmicks]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Éditeur Gimmicks installé. Redémarre Pokémon Studio.' -ForegroundColor Green
