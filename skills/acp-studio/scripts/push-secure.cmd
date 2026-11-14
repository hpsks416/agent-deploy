@echo off
rem push-secure.cmd - push a repo to github|gitee|atomgit WITHOUT putting the token in git's argv.
rem
rem usage: push-secure.cmd <RepoPath> <RepoName> <github|gitee|atomgit> [Branch]
rem
rem The token is read from the environment (secrets.cmd decrypts it at runtime) and is
rem referenced as $VAR inside git's credential helper - a shell variable, so the value
rem never appears on a command line, in .git/config, or in `git remote -v`.
setlocal

set "REPO=%~1"
set "REPONAME=%~2"
set "TARGET=%~3"
set "BRANCH=%~4"
if "%BRANCH%"=="" set "BRANCH=main"
if "%REPO%"=="" goto :usage
if "%REPONAME%"=="" goto :usage
if "%TARGET%"=="" goto :usage

rem secrets.cmd only references encrypted token files (never plaintext tokens).
rem Override the location with SECRETS_CMD; default = acp-studio/secrets.cmd one level up.
if not defined SECRETS_CMD set "SECRETS_CMD=%~dp0..\secrets.cmd"
if exist "%SECRETS_CMD%" call "%SECRETS_CMD%"
if not exist "%SECRETS_CMD%" echo [push-secure] note: no secrets.cmd at "%SECRETS_CMD%" - relying on existing env vars

if not defined GITHUB_USER set "GITHUB_USER=hpsks416"
if not defined GITEE_USERNAME set "GITEE_USERNAME=%GITHUB_USER%"
if not defined ATOMGIT_USER set "ATOMGIT_USER=%GITHUB_USER%"
if not defined ATOMGIT_HOST set "ATOMGIT_HOST=atomgit.com"

set "HTTP_OPTS=-c http.sslBackend=openssl"
set "PROXY_OPTS="
if defined GIT_HTTP_PROXY set "PROXY_OPTS=-c http.proxy=%GIT_HTTP_PROXY% -c https.proxy=%GIT_HTTP_PROXY%"

cd /d "%REPO%"
if errorlevel 1 echo [push-secure] repo not found: %REPO% & exit /b 2

if /i "%TARGET%"=="github" goto :github
if /i "%TARGET%"=="gitee" goto :gitee
if /i "%TARGET%"=="atomgit" goto :atomgit
goto :usage

:github
if not defined GITHUB_TOKEN echo [push-secure] GITHUB_TOKEN is not set & exit /b 3
git %HTTP_OPTS% %PROXY_OPTS% -c credential.helper= -c "credential.helper=!f(){ echo username=$GITHUB_USER; echo password=$GITHUB_TOKEN; }; f" push https://github.com/%GITHUB_USER%/%REPONAME%.git %BRANCH%
exit /b %ERRORLEVEL%

:gitee
if not defined GITEE_TOKEN echo [push-secure] GITEE_TOKEN is not set & exit /b 3
git %HTTP_OPTS% -c credential.helper= -c "credential.helper=!f(){ echo username=$GITEE_USERNAME; echo password=$GITEE_TOKEN; }; f" push https://gitee.com/%GITEE_USERNAME%/%REPONAME%.git %BRANCH%
exit /b %ERRORLEVEL%

:atomgit
if not defined ATOMGIT_TOKEN echo [push-secure] ATOMGIT_TOKEN is not set & exit /b 3
git %HTTP_OPTS% -c credential.helper= -c "credential.helper=!f(){ echo username=$ATOMGIT_USER; echo password=$ATOMGIT_TOKEN; }; f" push https://%ATOMGIT_HOST%/%ATOMGIT_USER%/%REPONAME%.git %BRANCH%
exit /b %ERRORLEVEL%

:usage
echo usage: push-secure.cmd ^<RepoPath^> ^<RepoName^> ^<github^|gitee^|atomgit^> [Branch]
echo.
echo   RepoPath   absolute path of the local git repository
echo   RepoName   remote repository name (slug) on the target platform
echo   TARGET     github / gitee / atomgit
echo   Branch     branch to push (default: main)
echo.
echo env: SECRETS_CMD (path to secrets.cmd), GIT_HTTP_PROXY (e.g. http://127.0.0.1:7897),
echo      GITHUB_USER / GITEE_USERNAME / ATOMGIT_USER / ATOMGIT_HOST overrides.
exit /b 1
