@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
REM Reconstruit chaque plugin du projet (dossiers scripts\<plugin>\config.yml) puis les installe tous.
REM L'installation (load) réinstalle tous les plugins depuis leurs fichiers .psdkplug :
REM ils sont tous reconstruits d'abord pour que chacun garde ses derniers scripts.
FOR %%P IN (extra_moves_additions extra_abilities_additions interface_pe pokesmart variantes advanced_pokedex triple_triad enhanced_battle_ui natures_pv generateur gimmicks icone_pss casino_jp insignes poffin tele wardrobe overworld_pokemon options_plus modes_jeu base_secrete meteo_saisons combats_speciaux pique_nique echange_miracle peche failles online) DO (
  IF EXIST "scripts\%%P\config.yml" (
    ECHO Construction du plugin %%P...
    CALL psdk.bat --util=plugin build %%P
    IF ERRORLEVEL 1 (
      ECHO La construction de %%P a echoue : regarde Error.log.
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
