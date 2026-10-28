@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
ECHO Retrait de l'ancienne copie du smartphone dans interface_pe...
IF EXIST "scripts\interface_pe\scripts\00130 Menu Smartphone PE.rb" DEL "scripts\interface_pe\scripts\00130 Menu Smartphone PE.rb"
IF EXIST "graphics\interface\menu_pe" RMDIR /S /Q "graphics\interface\menu_pe"
ECHO Construction du plugin pokesmart...
CALL psdk.bat --util=plugin build pokesmart
ECHO Reconstruction du plugin interface_pe (sans le smartphone)...
CALL psdk.bat --util=plugin build interface_pe
CALL psdk.bat --util=plugin load
ECHO.
ECHO Termine : lance le jeu.
PAUSE
