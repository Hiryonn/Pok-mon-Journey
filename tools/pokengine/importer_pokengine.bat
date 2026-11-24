@echo off
chcp 65001 >nul
setlocal
rem Importe les creatures Pokengine du dossier "telechargements" (a cote de ce fichier) dans le projet.
rem Glisse un autre dossier sur ce .bat pour l'utiliser a la place. Ajoute "essai" apres pour ne rien ecrire :
rem    importer_pokengine.bat telechargements essai
rem "images" refait seulement les images des creatures deja importees (JSON et textes intacts), "refaire" refait tout.

set "HERE=%~dp0"
set "PROJET=%HERE%..\.."
set "SOURCES=%~1"
if "%SOURCES%"=="" set "SOURCES=%HERE%telechargements"
set "OPTIONS="
if /i "%~2"=="essai" set "OPTIONS=--dry-run"
if /i "%~2"=="images" set "OPTIONS=--images-seulement"
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
%PY% -c "import pypdf" >nul 2>nul || (
  echo Installation de pypdf pour lire les PDF et leurs barres ^(capture, genre, effort^)...
  %PY% -m pip install pypdf || goto fin
)

if not exist "%SOURCES%" (
  mkdir "%SOURCES%"
  echo Le dossier "%SOURCES%" vient d'etre cree.
  echo Mets-y, pour chaque creature : la fiche PDF et ses images ^(code.webp, code_1.webp, code_2.webp, et code_3.webp pour le follower^), puis relance ce fichier.
  goto fin
)

%PY% "%HERE%importer_pokengine.py" "%SOURCES%" "%PROJET%" %OPTIONS%

:fin
echo.
pause
