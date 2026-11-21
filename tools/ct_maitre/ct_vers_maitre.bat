@echo off
chcp 65001 >nul
setlocal
rem Verifie tous les JSON de Data\Studio\pokemon : les capacites de l'onglet "Technique" qui n'ont PAS de vrai objet CT/CS
rem (ex. Abime, Aurore) passent dans "Maitre des capacites". Les vraies CT restent dans "Technique".
rem Le "Maitre des capacites" n'est PAS vide : on y ajoute seulement ce qui manque.
rem Options : "essai" = ne rien ecrire, "copier" = laisser aussi les capacites dans "Technique", "vider" = vider d'abord le Maitre des creatures concernees, "viderTout" = vider le Maitre de TOUTES les formes.  Ex : ct_vers_maitre.bat essai
rem Ferme Pokemon Studio avant de lancer, puis rouvre-le apres.

set "HERE=%~dp0"
set "PROJET=%HERE%..\.."
set "OPT="
if /i "%~1"=="essai" set "OPT=--essai"
if /i "%~1"=="copier" set "OPT=--copier"
if /i "%~1"=="vider" set "OPT=--vider"
if /i "%~2"=="vider" set "OPT=%OPT% --vider"
if /i "%~1"=="viderTout" set "OPT=--vider-tout"
if /i "%~2"=="viderTout" set "OPT=%OPT% --vider-tout"
if /i "%~2"=="essai" set "OPT=%OPT% --essai"
if /i "%~2"=="copier" set "OPT=%OPT% --copier"

where py >nul 2>nul && (set "PY=py -3") || (set "PY=python")
%PY% "%HERE%ct_vers_maitre.py" "%PROJET%" %OPT%
echo.
pause
