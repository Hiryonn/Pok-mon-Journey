@ECHO OFF
CHCP 65001 > NUL
POWERSHELL -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer_egg_groups.ps1"
PAUSE
