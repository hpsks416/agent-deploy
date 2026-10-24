@echo off
rem push-secure.cmd - secure push: token read from G:\KEY into env, passed to git via
rem inline bash credential helper ($VAR), so the token NEVER appears in git's argv.
rem usage: push-secure.cmd <RepoPath> <RepoName> <github|gitee> [Branch]
setlocal

set "REPO=%~1"
set "REPONAME=%~2"
set "TARGET=%~3"
set "BRANCH=%~4"
if "%BRANCH%"=="" set "BRANCH=main"

cd /d "%REPO%"
if /i "%TARGET%"=="github" (
  for /f "usebackq delims=" %%i in ("G:\KEY\GITHUB token\github-token.txt") do set "GITHUB_TOKEN=%%i"
  git -c "credential.helper=!f(){ echo username=hpsks416; echo password=$GITHUB_TOKEN; }; f" -c http.sslBackend=openssl -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 push https://github.com/hpsks416/%REPONAME%.git %BRANCH%
) else (
  for /f "usebackq delims=" %%i in ("G:\KEY\GITEE token\gitee-token.txt") do set "GITEE_TOKEN=%%i"
  git -c "credential.helper=!f(){ echo username=hpsks416; echo password=$GITEE_TOKEN; }; f" -c http.sslBackend=openssl push https://gitee.com/hpsks416/%REPONAME%.git %BRANCH%
)
exit /b %ERRORLEVEL%
