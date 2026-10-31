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
ECHO Retrait des anciens fichiers (remplaces par les dossiers Pokedex / Resume / Sac / Combat)...
FOR %%F IN ("00100 Pokedex PE.rb" "00110 Resume Pokemon PE.rb" "00120 Sac PE.rb" "00125 Combat Configuration.rb" "00126 Boites infos.rb" "00127 Choix action.rb" "00128 Choix attaque.rb" "00129 Boite de message.rb") DO IF EXIST "scripts\interface_pe\scripts\%%~F" DEL "scripts\interface_pe\scripts\%%~F"
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
