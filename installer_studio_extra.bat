@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
REM Pokémon Studio Extra : réinstalle tout (pages, menus, thème rouge, icône) dans Pokémon Studio.
REM À lancer après chaque mise à jour de Studio, Studio fermé. On peut le relancer sans risque.
REM Détails : tools\studio-extra\LISEZMOI.md
SET NO_COLOR=1
SET PJ_PY=python
WHERE python >NUL 2>&1 || SET PJ_PY=py -3
%PJ_PY% --version >NUL 2>&1
IF ERRORLEVEL 1 (
  ECHO Python est introuvable : installe Python 3 ^(https://www.python.org^) puis relance.
  PAUSE
  EXIT /B 1
)
ECHO Pokémon Studio Extra : réinstallation complète dans Pokémon Studio.
ECHO Ferme Pokémon Studio avant de continuer.
ECHO.
ECHO Une mise à jour automatique de Studio efface Studio Extra ^(il faut alors relancer ce fichier^).
CHOICE /C ON /M "Bloquer les mises à jour automatiques de Studio"
IF ERRORLEVEL 2 (SET PJ_MAJ=--autoriser-maj) ELSE (SET PJ_MAJ=--bloquer-maj)
ECHO.
%PJ_PY% -X utf8 tools\studio-extra\installer_studio_extra.py %PJ_MAJ%
ECHO.
PAUSE
