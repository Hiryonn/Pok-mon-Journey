# Installe les pages de réglages des plugins récents dans Pokémon Studio :
#   Données > Pokédex > Tâches, Données > Baies > Champs de baies, Données > Gimmicks > Styles PLA,
#   Level design > Mini-jeux > Sac de frappe et Poké Récré
# À relancer après chaque mise à jour de Studio. Studio doit être fermé puis rouvert.
# L'éditeur Smartphone doit être installé avant (même style). Les entrées du menu sont ajoutées par
# tools\studio-plugins\installer_pages.bat (lancé ici s'il trouve Python).
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
function Backup($p) { if (-not (Test-Path "$p.bak-reglages")) { Copy-Item $p "$p.bak-reglages" } }

$build = Join-Path $app '.vite\build'
$renderer = Join-Path $app '.vite\renderer\main_window'
if (-not (Test-Path (Join-Path $renderer 'pj-smartphone\pj-smartphone.css'))) {
  Write-Host "Installe d'abord l'éditeur Smartphone (tools\studio-smartphone\installer_smartphone.bat)." -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force (Join-Path $renderer 'pj-reglages') | Out-Null
Copy-Item (Join-Path $here 'pj-reglages-main.js') $build -Force
Copy-Item (Join-Path $here 'pj-reglages.js') (Join-Path $renderer 'pj-reglages') -Force
Copy-Item (Join-Path $here 'pj-reglages.css') (Join-Path $renderer 'pj-reglages') -Force

$html = Join-Path $renderer 'index.html'
$s = Read-Text $html
if ($s -notmatch 'pj-reglages') {
  Backup $html
  $tag = '<!-- pj-reglages --><link rel="stylesheet" href="./pj-reglages/pj-reglages.css"><script defer src="./pj-reglages/pj-reglages.js"></script><!-- pj-reglages -->'
  $s = $s.Replace('  </head>', "    $tag`n  </head>")
  Write-Text $html $s
}

$preload = Join-Path $build 'preload.js'
$s = Read-Text $preload
if ($s -notmatch 'pj-reglages:preload') {
  Backup $preload
  $s = $s.TrimEnd() + @'


/* pj-reglages:preload */;(() => {
  // Réglages des plugins récents — exposition de l'API au rendu (ajouté par l'installateur)
  try {
    const { contextBridge, ipcRenderer } = require('electron');
    const api = {};
    ['getContext', 'save', 'buildPlugin', 'readImages', 'readSound'].forEach((n) => { api[n] = (payload) => ipcRenderer.invoke('pj-reglages:' + n, payload); });
    contextBridge.exposeInMainWorld('pjReglages', api);
  } catch (e) { console.error('[pj-reglages] preload', e); }
})();
'@
  Write-Text $preload $s
}

$index = Join-Path $build 'index.js'
$s = Read-Text $index
if ($s -notmatch 'pj-reglages:main') {
  Backup $index
  $s += "`n/* pj-reglages:main */`ntry{require('./pj-reglages-main.js')}catch(e){console.error('[pj-reglages]',e)}`n"
  Write-Text $index $s
}

# entrées du menu (Données / Level design)
$patch = Join-Path $here '..\studio-plugins\patch_studio_pages.py'
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) { & $python.Source $patch } else { Write-Host "Python introuvable : lance tools\studio-plugins\installer_pages.bat pour ajouter les pages au menu." -ForegroundColor Yellow }
Write-Host 'Pages de réglages installées. Redémarre Pokémon Studio.' -ForegroundColor Green
