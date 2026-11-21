# Installe le "Generateur d'icones PSS" (onglet Generateurs) dans Pokemon Studio.
# A relancer apres chaque mise a jour de Studio. Studio doit etre ferme puis rouvert.
# Il faut aussi l'onglet Generateurs : tools\studio-plugins\installer_pages.bat
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
function Backup($p) { if (-not (Test-Path "$p.bak-pss")) { Copy-Item $p "$p.bak-pss" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-pss') | Out-Null
Copy-Item (Join-Path $here 'pj-pss-main.js') $build -Force
foreach ($f in 'pj-pss-logic.js', 'pj-pss.js', 'pj-pss.css') {
  Copy-Item (Join-Path $here $f) (Join-Path $renderer 'pj-pss') -Force
}

# page : feuille de style + scripts (la logique d'assemblage avant la page)
$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-pss/pj-pss.js') {
  Backup $html
  $tag = '<!-- pj-pss --><link rel="stylesheet" href="./pj-pss/pj-pss.css"><script defer src="./pj-pss/pj-pss-logic.js"></script><script defer src="./pj-pss/pj-pss.js"></script><!-- pj-pss -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

# preload : expose l'API au rendu
$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-pss:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-pss:preload */;(() => {
  // Generateur d'icones PSS - exposition de l'API au rendu (ajoute par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'readPieces', 'saveIcon', 'forgetIcon'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-pss:' + n, payload); });
    contextBridge.exposeInMainWorld('pjPss', api);
  } catch (e) { console.error('[pj-pss] preload', e); }
})();
'@
  Write-Text $preload $s
}

# processus principal : canaux IPC
$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-pss:main') {
  Backup $index
  $s += "`n/* pj-pss:main */`ntry{require('./pj-pss-main.js')}catch(e){console.error('[pj-pss]',e)}`n"
  Write-Text $index $s
}
Write-Host 'Generateur d''icones PSS installe. Redemarre Pokemon Studio (Generateurs > Icones PSS).' -ForegroundColor Green
