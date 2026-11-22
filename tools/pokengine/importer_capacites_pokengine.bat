@echo off
chcp 65001 >nul
setlocal
rem Cree des CAPACITES (attaques) a partir des fiches Pokengine (PDF) du dossier "telechargements_capacites" (a cote de ce fichier).
rem Les effets (stats, statut, chance) sont devines depuis le texte : verifie-les dans Studio. L'animation n'est pas importee.
rem Glisse un autre dossier sur ce .bat pour l'utiliser a la place. Ajoute "essai" apres pour ne rien ecrire :
rem    importer_capacites_pokengine.bat telechargements_capacites essai
rem "refaire" refait une capacite deja importee. Pour corriger un champ : overrides_capacites.json dans le dossier des fiches.

set "HERE=%~dp0"
set "PROJET=%HERE%..\.."
set "SOURCES=%~1"
if "%SOURCES%"=="" set "SOURCES=%HERE%telechargements_capacites"
set "OPTIONS="
if /i "%~2"=="essai" set "OPTIONS=--dry-run"
if /i "%~2"=="refaire" set "OPTIONS=--force"

set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY (
  echo Python 3 est introuvable. Installe-le depuis https://www.python.org/downloads/ en cochant "Add python to PATH".
  goto fin
)

%PY% -c "import PIL" >nul 2>nul || (
  echo Installation de Pillow...
  %PY% -m pip install pillow || goto fin
)
where pdftotext >nul 2>nul || (
  %PY% -c "import pypdf" >nul 2>nul || (
    echo Installation de pypdf pour lire les PDF...
    %PY% -m pip install pypdf || goto fin
  )
)

if not exist "%SOURCES%" (
  mkdir "%SOURCES%"
  echo Le dossier "%SOURCES%" vient d'etre cree.
  echo Mets-y les fiches PDF des capacites ^(imprimees depuis la page de la capacite sur Pokengine^), puis relance ce fichier.
  goto fin
)

%PY% "%HERE%importer_capacites_pokengine.py" "%SOURCES%" "%PROJET%" %OPTIONS%

:fin
echo.
pause
