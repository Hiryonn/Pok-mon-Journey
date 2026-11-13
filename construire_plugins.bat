@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
REM Reconstruit chaque plugin du projet (dossiers scripts\<plugin>\config.yml) puis les installe tous.
REM L'installation (load) réinstalle tous les plugins depuis leurs fichiers .psdkplug :
REM ils sont tous reconstruits d'abord pour que chacun garde ses derniers scripts.
REM Ancien nom de l'Interface Horizon (interface_pe) : retire pour ne pas l'installer en double
IF EXIST "scripts\interface_pe.psdkplug" DEL "scripts\interface_pe.psdkplug"
IF EXIST "scripts\interface_horizon\config.yml" IF EXIST "scripts\interface_pe\config.yml" RMDIR /S /Q "scripts\interface_pe"
IF EXIST "construire_plugin_interface_pe.bat" DEL "construire_plugin_interface_pe.bat"
SET PJ_PLUGINS=interface_horizon pokesmart variantes advanced_pokedex triple_triad enhanced_battle_ui natures_pv generateur gimmicks personnages statuts quel_pokemon
REM Les anciens fichiers .psdkplug de ces plugins sont retires avant de tout reconstruire :
REM sinon PSDK les recharge a chaque construction et peut chercher une dependance qui n'existe plus.
REM PSDK demande alors s'il faut supprimer les fichiers de ces plugins : on repond toujours N (on les garde).
(FOR /L %%I IN (1,1,60) DO @ECHO N) > "%TEMP%\pj_plugins_non.txt"
FOR %%P IN (%PJ_PLUGINS%) DO IF EXIST "scripts\%%P\config.yml" IF EXIST "scripts\%%P.psdkplug" DEL "scripts\%%P.psdkplug"
FOR %%P IN (%PJ_PLUGINS%) DO (
  IF EXIST "scripts\%%P\config.yml" (
    ECHO Construction du plugin %%P...
    CALL psdk.bat --util=plugin build %%P < "%TEMP%\pj_plugins_non.txt"
    IF ERRORLEVEL 1 (
      ECHO La construction de %%P a echoue : regarde Error.log.
      PAUSE
      EXIT /B 1
    )
  )
)
ECHO Installation des plugins...
CALL psdk.bat --util=plugin load < "%TEMP%\pj_plugins_non.txt"
ECHO.
ECHO Termine : lance le jeu.
PAUSE
