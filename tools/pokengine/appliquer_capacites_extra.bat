@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
REM Regle la Fonction des capacites Pokengine (voir appliquer_capacites_extra.py). Option : essai
python "%~dp0appliquer_capacites_extra.py" "%~dp0..\.." %1
PAUSE
