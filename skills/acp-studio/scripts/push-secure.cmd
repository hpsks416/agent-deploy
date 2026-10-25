@echo off
rem push-secure.cmd - secure push: token from secrets.cmd (not hardcoded),
rem passed to git via inline bash credential helper ($VAR), so the token NEVER appears in git's argv.
rem usage: push-secure.cmd <RepoPath> <RepoName> <github|gitee> [Branch]
setlocal

set "REPO=%~1"
set "REPONAME=%~2"
set "TARGET=%~3"
set "BRANCH=%~4"
if "%BRANCH%"=="" set "BRANCH=main"

rem token location lives only in secrets.cmd; call it for env vars instead of hardcoding G:\KEY
call "C:\Users\Razer\Documents\Codex\2026-09-20\y\acp-studio\secrets.cmd"

cd /d "%REPO%"
if /i "%TARGET%"=="github" (
  git -c "credential.helper=!f(){ echo username=hpsks416; echo password=$GITHUB_TOKEN; }; f" -c http.sslBackend=openssl -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 push https://github.com/hpsks416/%REPONAME%.git %BRANCH%
) else (
  git -c "credential.helper=!f(){ echo username=%GITEE_USERNAME%; echo password=%GITEE_TOKEN%; }; f" -c http.sslBackend=openssl push https://gitee.com/hpsks416/%REPONAME%.git %BRANCH%
)
exit /b %ERRORLEVEL%
