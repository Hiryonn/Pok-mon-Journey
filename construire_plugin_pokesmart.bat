@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
IF NOT EXIST "scripts\pokesmart\config.yml" (
  ECHO Dossier scripts\pokesmart introuvable : extrais d abord Plugin_pokesmart.zip a la racine du projet.
  PAUSE
  EXIT /B 1
)
ECHO Retrait de l ancienne version du smartphone (un seul fichier)...
IF EXIST "scripts\00000 Plugins\00001 pokesmart\00130 Menu Smartphone.rb" DEL "scripts\00000 Plugins\00001 pokesmart\00130 Menu Smartphone.rb"
ECHO Construction du plugin pokesmart...
CALL psdk.bat --util=plugin build pokesmart
IF ERRORLEVEL 1 (
  ECHO La construction a echoue : regarde Error.log.
  PAUSE
  EXIT /B 1
)
ECHO Installation du plugin...
CALL psdk.bat --util=plugin load
ECHO.
ECHO Termine : lance le jeu.
PAUSE
