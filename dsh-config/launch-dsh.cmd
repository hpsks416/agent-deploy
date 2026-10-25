@echo off
rem launch-dsh.cmd - DSH web launcher that avoids multi-process conflict:
rem if 3080 is already listening, open the existing instance instead of starting a second one.
netstat -ano | findstr ":3080 " | findstr "LISTENING" >nul 2>&1
if %errorlevel%==0 (
  echo DSH web already running on 3080 - opening existing instance
  start "" http://127.0.0.1:3080
) else (
  echo starting DSH web...
  cd /d "C:\Users\Razer\Documents\Codex"
  dsh web
)
