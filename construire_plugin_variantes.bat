@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
IF NOT EXIST "scripts\variantes\config.yml" (
  ECHO Dossier scripts\variantes introuvable.
  PAUSE
  EXIT /B 1
)
REM L'installation (load) réinstalle tous les plugins depuis leurs fichiers .psdkplug :
REM ils sont tous reconstruits d'abord pour que chacun garde ses derniers scripts.
FOR %%P IN (interface_pe pokesmart variantes) DO (
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
