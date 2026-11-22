@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
SET PJ_PY=python
WHERE python >NUL 2>&1 || SET PJ_PY=py -3
REM Ecrit resume_capacites.md (capacites ajoutees + leurs effets reels) a envoyer a Claude
%PJ_PY% -X utf8 resume_capacites.py "%~dp0..\.."
PAUSE
