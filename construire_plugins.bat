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
REM Le détail de chaque construction est écrit dans construire_plugins.log (affiché si une construction échoue)
SET PJ_LOG=construire_plugins.log
ECHO Construction des plugins %DATE% %TIME% > "%PJ_LOG%"
SET PJ_PLUGINS=interface_horizon pokesmart variantes advanced_pokedex triple_triad enhanced_battle_ui natures_pv generateur gimmicks personnages statuts quel_pokemon berrydex succes magasins carte_region etui_badges mementos sac_de_frappe poke_recre raids tournoi pokeblocs concours obscurs montures pokeathlon dodrio lance_ball
FOR %%P IN (%PJ_PLUGINS%) DO (
  IF EXIST "scripts\%%P\config.yml" (
    ECHO Construction du plugin %%P...
    ECHO. >> "%PJ_LOG%"
    ECHO === %%P === >> "%PJ_LOG%"
    CALL psdk.bat --util=plugin build %%P >> "%PJ_LOG%" 2>&1
    IF ERRORLEVEL 1 (
      ECHO.
      ECHO La construction de %%P a echoue. Detail ^(aussi dans construire_plugins.log^) :
      TYPE "%PJ_LOG%"
      PAUSE
      EXIT /B 1
    )
  )
)
ECHO Installation des plugins...
CALL psdk.bat --util=plugin load
ECHO.
ECHO Termine : lance le jeu.
PAUSE
