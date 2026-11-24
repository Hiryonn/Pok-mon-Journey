@ECHO OFF
CHCP 65001 > NUL
POWERSHELL -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer_pots_baies.ps1"
PAUSE
