@echo off
rem push-secure.cmd - secure push wrapper: calls secrets.cmd (for /f reads G:\KEY file content),
rem token stays in this process env only, never echoed, never in agent context.
rem usage: push-secure.cmd <RepoPath> <RepoName> <github|gitee> [Branch]
setlocal

set "REPO=%~1"
set "REPONAME=%~2"
set "TARGET=%~3"
set "BRANCH=%~4"
if "%BRANCH%"=="" set "BRANCH=main"

call "C:\Users\Razer\Documents\Codex\2026-09-20\y\acp-studio\secrets.cmd"

cd /d "%REPO%"
if /i "%TARGET%"=="github" (
  git -c http.sslBackend=openssl -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 -c credential.helper= push "https://hpsks416:%GITHUB_TOKEN%@github.com/hpsks416/%REPONAME%.git" %BRANCH%
) else (
  git -c http.sslBackend=openssl -c credential.helper= push "https://%GITEE_USERNAME%:%GITEE_TOKEN%@gitee.com/hpsks416/%REPONAME%.git" %BRANCH%
)
exit /b %ERRORLEVEL%
