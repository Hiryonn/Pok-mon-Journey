@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
ECHO Nettoyage des anciens fichiers BW...
IF EXIST "scripts\00100 Pokedex BW.rb" DEL "scripts\00100 Pokedex BW.rb"
IF EXIST "scripts\00110 Resume Pokemon BW.rb" DEL "scripts\00110 Resume Pokemon BW.rb"
IF EXIST "scripts\00120 Sac BW.rb" DEL "scripts\00120 Sac BW.rb"
IF EXIST "graphics\pokedex\bw" RMDIR /S /Q "graphics\pokedex\bw"
IF EXIST "graphics\interface\summary_bw" RMDIR /S /Q "graphics\interface\summary_bw"
IF EXIST "graphics\interface\bag_bw" RMDIR /S /Q "graphics\interface\bag_bw"
ECHO Construction du plugin interface_pe...
CALL psdk.bat --util=plugin build interface_pe
ECHO.
ECHO Termine : lance le jeu pour que PSDK installe scripts\interface_pe.psdkplug
PAUSE
