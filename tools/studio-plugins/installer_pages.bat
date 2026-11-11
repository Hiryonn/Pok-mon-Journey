@echo off
rem Onglet Plugins, pages des editeurs et dossiers des icones dans Pokemon Studio (Studio doit etre ferme)
cd /d "%~dp0"
python patch_studio_pages.py
python patch_studio_icons.py
pause
