@echo off
chcp 65001 >nul
setlocal
rem Cree dans la base de donnees les talents Pokengine (collections HUB et Uranium) : fichiers Studio + noms et descriptions.
rem Les effets sont dans le plugin extra_abilities_additions (construire_plugins.bat). Option : essai
rem Ferme Studio avant de lancer ce fichier.
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
%PY% "%HERE%creer_talents_pokengine.py" "%HERE%..\.." %OPTIONS%
:fin
pause
