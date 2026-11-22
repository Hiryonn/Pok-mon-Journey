@echo off
chcp 65001 >nul
setlocal
rem Ajoute les noms et descriptions des objets crees par les plugins (Studio : "Unable to find text ... in dialog file 100012").
rem Ferme Studio avant. Option : essai
set "HERE=%~dp0"
set "OPTIONS="
if /i "%~1"=="essai" set "OPTIONS=--essai"
set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY (
  echo Python 3 est introuvable. Installe-le depuis https://www.python.org/downloads/ en cochant "Add python to PATH".
  goto fin
)
%PY% "%HERE%corriger_textes_objets.py" "%HERE%..\.." %OPTIONS%
:fin
pause
