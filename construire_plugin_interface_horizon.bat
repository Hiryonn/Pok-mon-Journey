@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
IF NOT EXIST "scripts\interface_horizon\config.yml" (
  ECHO Dossier scripts\interface_horizon introuvable.
  PAUSE
  EXIT /B 1
)
REM Ancien nom du plugin (interface_pe) : retire pour ne pas l'installer en double
IF EXIST "scripts\interface_pe.psdkplug" DEL "scripts\interface_pe.psdkplug"
IF EXIST "scripts\interface_pe\config.yml" RMDIR /S /Q "scripts\interface_pe"
IF EXIST "construire_plugin_interface_pe.bat" DEL "construire_plugin_interface_pe.bat"
ECHO Construction du plugin interface_horizon...
CALL psdk.bat --util=plugin build interface_horizon
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
