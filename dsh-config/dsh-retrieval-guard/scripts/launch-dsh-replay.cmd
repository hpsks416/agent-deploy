@echo off
chcp 65001 >nul
title DSH Session Replay
node "G:\CodexDS\DSH\INTRO\dsh-replay-web.mjs"
if errorlevel 1 goto err
exit /b 0
:err
echo.
echo [START FAILED] press any key to exit...
pause >nul