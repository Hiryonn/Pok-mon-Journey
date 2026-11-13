# Range les icônes de graphics/pokedex/pokeicon :
#   icônes chromatiques (iconShiny / iconShinyF des Pokémon de Studio, et les noms en …s) -> graphics/pokedex/pokeiconshiny
#   icônes d'œuf (iconEgg, et les fichiers egg*.png)                   -> graphics/pokedex/pokeiconegg
# Une image aussi utilisée comme icône normale est copiée (pas déplacée). Rien n'est effacé sans copie.
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$icons = Join-Path $root 'graphics\pokedex\pokeicon'
$shinyDir = Join-Path $root 'graphics\pokedex\pokeiconshiny'
$eggDir = Join-Path $root 'graphics\pokedex\pokeiconegg'
$data = Join-Path $root 'Data\Studio\pokemon'
if (-not (Test-Path $icons) -or -not (Test-Path $data)) { Write-Host "Projet introuvable : $root"; exit 1 }
New-Item -ItemType Directory -Force -Path $shinyDir, $eggDir | Out-Null

$normal = @{}; $shiny = @{}; $egg = @{}
Get-ChildItem $data -Filter *.json | ForEach-Object {
  $d = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($f in $d.forms) {
    $r = $f.resources
    if (-not $r) { continue }
    foreach ($k in 'icon', 'iconF') { if ($r.$k) { $normal[$r.$k.ToLower()] = $true } }
    foreach ($k in 'iconShiny', 'iconShinyF') { if ($r.$k) { $shiny[$r.$k.ToLower()] = $true } }
    if ($r.iconEgg) { $egg[$r.iconEgg.ToLower()] = $true }
  }
}
Get-ChildItem $icons -File | Where-Object { $_.BaseName -like 'egg*' } | ForEach-Object { $egg[$_.BaseName.ToLower()] = $true }
# icônes chromatiques non utilisées par Studio, reconnues à leur nom (0025sf, 0003s_30, MissingNo_s…)
Get-ChildItem $icons -File | Where-Object { $_.BaseName.ToLower() -match '^(\d+|missingno)(_\d+)?_?f?sf?(_\d+)?$' } | ForEach-Object { $shiny[$_.BaseName.ToLower()] = $true }

$moved = 0; $copied = 0
function Ranger($names, $dest, $keep) {
  foreach ($n in $names.Keys) {
    foreach ($ext in '.png', '.gif') {
      $src = Join-Path $icons ($n + $ext)
      if (-not (Test-Path $src)) { continue }
      $dst = Join-Path $dest ($n + $ext)
      if ($keep.ContainsKey($n)) { Copy-Item $src $dst -Force; $script:copied++ }
      else { Move-Item $src $dst -Force; $script:moved++ }
    }
  }
}
Ranger $shiny $shinyDir $normal
$keepEgg = $normal.Clone(); foreach ($k in $shiny.Keys) { $keepEgg[$k] = $true }
Ranger $egg $eggDir $keepEgg
Write-Host "Icones rangees : $moved deplacee(s), $copied copiee(s) (aussi utilisees comme icone normale)."
Write-Host "Chromatiques : graphics\pokedex\pokeiconshiny   Oeufs : graphics\pokedex\pokeiconegg"
