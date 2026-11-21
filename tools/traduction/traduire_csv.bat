@ECHO OFF
CHCP 65001 > NUL
CD /D "%~dp0"
REM Traduction automatique des cases vides des CSV de textes (depuis l'anglais). Studio doit etre ferme.
REM Options : essai (compte sans traduire), fr / de / es / it / ko / kana (une seule langue)
REM Details et autres moteurs (DeepL, LibreTranslate) : python traduire_csv.py --help
SET PJ_PY=python
WHERE python >NUL 2>&1 || SET PJ_PY=py -3
SET OPT=
IF /I "%1"=="essai" SET OPT=--essai
IF /I "%1"=="fr" SET OPT=--langues fr
IF /I "%1"=="de" SET OPT=--langues de
IF /I "%1"=="es" SET OPT=--langues es
IF /I "%1"=="it" SET OPT=--langues it
IF /I "%1"=="ko" SET OPT=--langues ko
IF /I "%1"=="kana" SET OPT=--langues kana
%PJ_PY% -X utf8 traduire_csv.py "%~dp0..\.." %OPT%
PAUSE
