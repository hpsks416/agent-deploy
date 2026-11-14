#!/usr/bin/env pwsh
# ============================================================================
# publish-plugins.ps1 —— 把随仓 DSH 插件以 @hpsks416/* 发布到 npm
#
# 用法：
#   pwsh tools/publish-plugins.ps1 -DryRun        # 只预检（名称占用/pack 产物/token 是否存在）
#   pwsh tools/publish-plugins.ps1               # 真正发布（需要 secrets-link 里的 NPM_TOKEN）
#   pwsh tools/publish-plugins.ps1 -Only dsh-retrieval-guard -DryRun
#
# token：secrets-link 的 G:\KEY\NPM token\416.txt.zip（运行时解密进 NODE_AUTH_TOKEN，不落盘）
# 约定：scoped 包发布必须 --access public；发布不可逆（同名同版本不能再发），所以默认先 -DryRun。
# ============================================================================
param(
  [switch]$DryRun,
  [string[]]$Only = @(),
  [string]$NpmTokenZip = 'G:\KEY\NPM token\416.txt.zip',
  [string]$Registry = 'https://registry.npmjs.org/'
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$repo = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repo 'framework-manifest.json'
$decrypt = 'C:\Users\Razer\.dsh\skills\acp-studio\scripts\secrets-link\decrypt-runtime.py'
$age = 'G:\CodexDS\DSH\INTRO\age\age\age.exe'
$ident = Join-Path $env:USERPROFILE '.dsh\age-identity.txt'
$pnpm = (Get-Command pnpm -ErrorAction SilentlyContinue).Source
if (-not $pnpm) { $pnpm = 'C:\Users\Razer\Documents\Codex\pnpm-global\bin\pnpm.cmd' }

if (-not (Test-Path $manifestPath)) { Write-Host "x 缺 manifest: $manifestPath" -ForegroundColor Red; exit 2 }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

$targets = @($manifest.items | Where-Object {
  $_.kind -eq 'plugin' -and $_.source -and $_.source -notlike 'npm:*' -and (-not $Only -or $Only -contains $_.id)
})

$token = $null
if (-not $DryRun) {
  if (-not (Test-Path $NpmTokenZip)) { Write-Host "x 缺 NPM token：$NpmTokenZip（见 DUAL-TRACK §11 的添加步骤）" -ForegroundColor Red; exit 3 }
  $token = (& python $decrypt $NpmTokenZip $age $ident).Trim()
  if (-not $token) { Write-Host 'x NPM token 解密为空' -ForegroundColor Red; exit 3 }
  $env:NODE_AUTH_TOKEN = $token
  Write-Host ("token 已解密（len {0}），不落盘" -f $token.Length) -ForegroundColor DarkGray
}

$tmp = Join-Path $env:TEMP ("publish-plugins-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$results = @()

foreach ($it in $targets) {
  $dir = Join-Path $repo ($it.source -replace '/', '\')
  $pkg = if ($it.package) { $it.package } else { $it.id }
  $ver = $it.version
  Write-Host ''
  Write-Host "[$pkg@$ver]" -ForegroundColor Cyan

  # 1) 名称/版本占用检查（存在则不能再发这个版本）
  $viewOut = & $pnpm view $pkg version --registry $Registry 2>&1
  $exists = $LASTEXITCODE -eq 0
  Write-Host ("  registry: " + $(if ($exists) { "已存在（$($viewOut -join ' ')）" } else { '未发布' })) -ForegroundColor DarkGray

  # 2) 打包检查（必须在包目录里跑）
  Push-Location $dir
  try { $packOut = & $pnpm pack --pack-destination $tmp 2>&1 } finally { Pop-Location }
  $tgz = Get-ChildItem $tmp -Filter '*.tgz' | Sort-Object LastWriteTime | Select-Object -Last 1
  if (-not $tgz) { Write-Host "  x pack 失败：$($packOut -join ' ')" -ForegroundColor Red; $results += "FAIL $pkg pack"; continue }
  Write-Host ("  pack: {0}（{1} KB）" -f $tgz.Name, [math]::Round($tgz.Length / 1KB, 1)) -ForegroundColor DarkGray
  Remove-Item $tgz.FullName -Force

  if ($DryRun) { $results += "DRYRUN $pkg@$ver (exists=$exists)"; continue }

  # 3) 发布（不可逆）
  Push-Location $dir
  try { $pub = & $pnpm publish --access public --no-git-checks --tag latest --registry $Registry 2>&1 } finally { Pop-Location }
  if ($LASTEXITCODE -eq 0) { $results += "OK $pkg@$ver"; Write-Host '  已发布' -ForegroundColor Green }
  else { $results += "FAIL ${pkg}: $($pub -join ' ' | Select-Object -First 1)"; Write-Host ("  x 发布失败：" + ($pub -join ' ')) -ForegroundColor Red }
}

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
Write-Host '=== 汇总 ===' -ForegroundColor Cyan
$results | ForEach-Object { Write-Host "  $_" }
if ($DryRun) { Write-Host '（DryRun：未发布任何包）' -ForegroundColor Yellow }
