@echo off
rem Refait monaco.js / monaco.css (moteur de l editeur de code) : il faut Node.js
cd /d "%~dp0"
call npm install
call npm run build
pause
