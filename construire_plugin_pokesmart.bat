@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
ECHO Construction du plugin pokesmart...
CALL psdk.bat --util=plugin build pokesmart
ECHO Reconstruction du plugin interface_pe (sans le smartphone)...
CALL psdk.bat --util=plugin build interface_pe
CALL psdk.bat --util=plugin load
ECHO.
ECHO Termine : lance le jeu.
PAUSE
