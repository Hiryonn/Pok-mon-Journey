@echo off
rem Donnees > Personnages (heros, allies) dans Pokemon Studio Extra (Studio doit etre ferme)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer_personnages.ps1"
pause
