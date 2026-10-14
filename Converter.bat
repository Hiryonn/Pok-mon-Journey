@echo off
setlocal enabledelayedexpansion

REM Set the delay in hundredths of a second (e.g., 10 for 1/10th of a second)
set "delay=12"

REM Loop through each PNG file in the current directory
FOR %%i IN (*.png) DO (
    REM Get the height of the image
    for /f %%j in ('magick identify -ping -format "%%h" "%%i"') do set "height=%%j"

    REM Convert the PNG to a GIF with specified options and delay
    magick convert -dispose 3 -delay !delay! -loop 0 "%%i" -crop !height!x!height! +repage "%%~ni.gif"
)
endlocal