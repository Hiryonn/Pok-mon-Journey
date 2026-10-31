@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
IF NOT EXIST "scripts\combat_pj\config.yml" (
  ECHO Dossier scripts\combat_pj introuvable.
  PAUSE
  EXIT /B 1
)
ECHO Construction du plugin combat_pj...
CALL psdk.bat --util=plugin build combat_pj
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
