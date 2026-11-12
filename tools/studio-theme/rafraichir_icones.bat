@ECHO OFF
REM Vide le cache des icones de Windows (Pokemon Studio Extra garde sinon l ancienne icone bleue)
ie4uinit.exe -show
taskkill /f /im explorer.exe
del /a /q "%localappdata%\IconCache.db" 2>NUL
del /a /f /q "%localappdata%\Microsoft\Windows\Explorer\iconcache*" 2>NUL
start explorer.exe
ECHO Cache des icones vide.
PAUSE
