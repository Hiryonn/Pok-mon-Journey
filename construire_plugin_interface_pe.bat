@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
IF NOT EXIST "scripts\interface_pe\config.yml" (
  ECHO Dossier scripts\interface_pe introuvable.
  PAUSE
  EXIT /B 1
)
ECHO Retrait de l ancien plugin combat_pj (maintenant dans interface_pe)...
IF EXIST "scripts\combat_pj" RMDIR /S /Q "scripts\combat_pj"
IF EXIST "construire_plugin_combat.bat" DEL "construire_plugin_combat.bat"
ECHO Construction du plugin interface_pe...
CALL psdk.bat --util=plugin build interface_pe
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
