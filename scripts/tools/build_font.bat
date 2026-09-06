@echo off
setlocal

set "FFPYTHON=C:\Program Files\FontForgeBuilds\bin\ffpython.exe"

if not exist "%FFPYTHON%" (
    echo ERROR: FontForge Python interpreter not found at:
    echo   %FFPYTHON%
    echo Please verify FontForge is installed.
    exit /b 1
)

"%FFPYTHON%" "%~dp0build_custom_font.py" %*
