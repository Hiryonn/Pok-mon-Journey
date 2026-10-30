@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
IF NOT EXIST "scripts\pokesmart\config.yml" (
  ECHO Dossier scripts\pokesmart introuvable : extrais d abord Plugin_pokesmart.zip a la racine du projet.
  PAUSE
  EXIT /B 1
)
ECHO Retrait des anciens fichiers du smartphone deja installes...
FOR %%F IN ("00130 Menu Smartphone.rb" "00141 App Troupeaux.rb") DO IF EXIST "scripts\00000 Plugins\00001 pokesmart\%%~F" DEL "scripts\00000 Plugins\00001 pokesmart\%%~F"
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
