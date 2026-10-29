@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
ECHO Construction du plugin pokesmart...
CALL psdk.bat --util=plugin build pokesmart
CALL psdk.bat --util=plugin load
ECHO.
ECHO Termine : lance le jeu.
PAUSE
