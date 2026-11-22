@ECHO OFF
CHCP 65001 > NUL
POWERSHELL -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer_triple_triad.ps1"
PAUSE
