@echo off
title A Vampyre Story - Fix and Play
setlocal
set "SCRIPT=%~dp0A_Vampyre_Story_Fix_and_Play.ps1"
if not exist "%SCRIPT%" (
    echo [ERROR] A_Vampyre_Story_Fix_and_Play.ps1 not found next to this batch file.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "RC=%ERRORLEVEL%"
echo.
echo Exit code: %RC%
if not "%RC%"=="0" pause
exit /b %RC%