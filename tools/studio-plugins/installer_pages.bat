@echo off
rem Onglet Plugins + pages des editeurs dans Pokemon Studio (Studio doit etre ferme)
cd /d "%~dp0"
python patch_studio_pages.py
pause
