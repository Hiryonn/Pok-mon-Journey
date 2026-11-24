@ECHO OFF
CHCP 65001 > NUL
POWERSHELL -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer_gimmicks.ps1"
PAUSE
