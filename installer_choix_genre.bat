@echo off
rem Installe la section "Choix du genre" dans scripts\generateur\LISEZMOI.md
rem A placer a la racine du projet (dossier de Game.exe), puis double-clic.
set "BAT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ((Get-Content -Raw -LiteralPath '%~f0') -split ('#PS1'+'START'))[1]"
echo.
pause
exit /b
#PS1START
$ErrorActionPreference = 'Stop'
$cible = Join-Path $env:BAT_DIR 'scripts\generateur\LISEZMOI.md'
if (-not (Test-Path -LiteralPath $cible)) { Write-Host 'ERREUR : scripts\generateur\LISEZMOI.md est introuvable. Place ce fichier a la racine du projet.'; exit 1 }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$texte = [IO.File]::ReadAllText($cible, $utf8)
if ($texte.Contains('## Choix du genre')) { Write-Host 'Deja installe : rien a faire.'; exit 0 }
$ajout = $utf8.GetString([Convert]::FromBase64String('IyMgQ2hvaXggZHUgZ2VucmUKClN1ciBsJ8OpY3JhbiBkZSBjcsOpYXRpb24sIGxlIGpvdWV1ciBjaG9pc2l0IGxlIGdlbnJlIGRlIHNvbiBwZXJzb25uYWdlICgqKkdhcsOnb24qKiBvdSAqKkZpbGxlKiosIHByZW1pZXIgcsOpZ2xhZ2UgZGUgbGEKcGFnZSDCqyBjb3JwcyDCuykuIExlcyBjb2lmZnVyZXMsIHRlbnVlcyBldCBhY2Nlc3NvaXJlcyBwcm9wb3PDqXMgcydhZGFwdGVudCBlbnN1aXRlIGF1IGdlbnJlIGNob2lzaSwgZXQgbGVzIGNob2l4IHF1aSBuZQpzb250IHBsdXMgdmFsYWJsZXMgc29udCBjb3JyaWfDqXMgYXV0b21hdGlxdWVtZW50LiBMZSBnZW5yZSBjaG9pc2kgbWV0IMOgIGpvdXIgbCdpbnRlcnJ1cHRldXIgZGUgZ2VucmUgZGUgUFNESwooYFl1a2k6OlN3OjpHZW5kZXJgLCBhY3RpdsOpIHBvdXIgdW5lIGZpbGxlKS4KCkF2ZWMgYHBlcnNvbm5hZ2Vfam91ZXVyX2F1X2hhc2FyZGAsIGxlIGdlbnJlIGVzdCB0aXLDqSBhdSBzb3J0IDsgYHBlcnNvbm5hZ2Vfam91ZXVyX2F1X2hhc2FyZCgnbScpYCBvdQpgcGVyc29ubmFnZV9qb3VldXJfYXVfaGFzYXJkKCdmJylgIGwnaW1wb3NlLgoKIyMgU3ByaXRlcwoK'))
$nl = "`n"
if ($texte.Contains("`r`n")) { $nl = "`r`n" }
$ajout = $ajout.Replace("`r`n", "`n").Replace("`n", $nl)
$cle = 'Le personnage utilise le charset'
$i = $texte.IndexOf($cle)
if ($i -ge 0) {
  $texte = $texte.Insert($i, $ajout)
} else {
  $ajout = [regex]::Replace($ajout, '(?s)## Sprites\s*$', '')
  $texte = $texte.TrimEnd() + $nl + $nl + $ajout.TrimEnd() + $nl
}
[IO.File]::WriteAllText($cible, $texte, $utf8)
Write-Host 'OK : la section "Choix du genre" a ete ajoutee a scripts\generateur\LISEZMOI.md'
