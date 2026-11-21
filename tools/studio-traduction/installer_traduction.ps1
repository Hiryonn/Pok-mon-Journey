# Installe le bouton « Traduire automatiquement » (onglet Traduction de la page Textes) dans Pokémon Studio
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
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
function Backup($p) { if (-not (Test-Path "$p.bak-traduction")) { Copy-Item $p "$p.bak-traduction" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-traduction') | Out-Null
Copy-Item (Join-Path $here 'pj-traduction-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-traduction.js') (Join-Path $renderer 'pj-traduction') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-traduction') {
  Backup $html
  $tag = '<!-- pj-traduction --><script defer src="./pj-traduction/pj-traduction.js"></script><!-- pj-traduction -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-traduction:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-traduction:preload */;(() => {
  // Traduction automatique — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['translate'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-traduction:' + n, payload); });
    contextBridge.exposeInMainWorld('pjTraduction', api);
  } catch (e) { console.error('[pj-traduction] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-traduction:main') {
  Backup $index
  $s += "`n/* pj-traduction:main */`ntry{require('./pj-traduction-main.js')}catch(e){console.error('[pj-traduction]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Bouton de traduction automatique installé. Redémarre Pokémon Studio.' -ForegroundColor Green
