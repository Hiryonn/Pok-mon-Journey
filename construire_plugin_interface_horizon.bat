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
REM gimmicks dependait de interface_pe : son ancien .psdkplug est retire (construire_plugins.bat le refait)
IF EXIST "scripts\gimmicks.psdkplug" DEL "scripts\gimmicks.psdkplug"
(FOR /L %%I IN (1,1,60) DO @ECHO N) > "%TEMP%\pj_plugins_non.txt"
ECHO Construction du plugin interface_horizon...
CALL psdk.bat --util=plugin build interface_horizon < "%TEMP%\pj_plugins_non.txt"
IF ERRORLEVEL 1 (
  ECHO La construction a echoue : regarde Error.log.
  PAUSE
  EXIT /B 1
)
ECHO Installation du plugin...
CALL psdk.bat --util=plugin load < "%TEMP%\pj_plugins_non.txt"
ECHO.
ECHO Termine : lance le jeu.
PAUSE
