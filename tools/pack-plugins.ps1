#!/usr/bin/env pwsh
# ============================================================================
# pack-plugins.ps1 —— 把随仓 DSH 插件打成可分发的 tarball（不发 npm 的官方分发方式）
#
# 用法：
#   pwsh tools/pack-plugins.ps1                 # 全部打到 dist/
#   pwsh tools/pack-plugins.ps1 -Only dsh-retrieval-guard
#   pwsh tools/pack-plugins.ps1 -OutDir G:\tmp\pkgs
#
# 产出的 tgz 可直接：
#   dsh plugin --profile web add file:<绝对路径>.tgz
#   或 dsh plugin --profile web add file:<相对路径>/<包名>-<版本>.tgz
# 注意：tarball 安装 = 复制一份到 profile 的 node_modules，改代码后要重新 pack 再装。
# ============================================================================
param(
  [string]$OutDir = 'dist',
  [string[]]$Only = @()
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$repo = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repo 'framework-manifest.json'
$pnpm = (Get-Command pnpm -ErrorAction SilentlyContinue).Source
if (-not $pnpm) { $pnpm = 'C:\Users\Razer\Documents\Codex\pnpm-global\bin\pnpm.cmd' }

$out = if ([System.IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repo $OutDir }
New-Item -ItemType Directory -Force -Path $out | Out-Null

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$targets = @($manifest.items | Where-Object {
  $_.kind -eq 'plugin' -and $_.source -and $_.source -notlike 'npm:*' -and (-not $Only -or $Only -contains $_.id)
})

$rows = @()
foreach ($it in $targets) {
  $dir = Join-Path $repo ($it.source -replace '/', '\')
  $pkg = if ($it.package) { $it.package } else { $it.id }
  Write-Host "[$pkg@$($it.version)]" -ForegroundColor Cyan
  Push-Location $dir
  try { $packOut = & $pnpm pack --pack-destination $out 2>&1 } finally { Pop-Location }
  $tgz = Get-ChildItem $out -Filter '*.tgz' | Sort-Object LastWriteTime | Select-Object -Last 1
  if (-not $tgz) { Write-Host ("  x 失败：" + ($packOut -join ' ')) -ForegroundColor Red; $rows += "FAIL $pkg"; continue }
  $rows += ("{0}@{1}  {2}  {3} KB" -f $pkg, $it.version, $tgz.Name, [math]::Round($tgz.Length / 1KB, 1))
  Write-Host ("  -> {0}（{1} KB）" -f $tgz.Name, [math]::Round($tgz.Length / 1KB, 1)) -ForegroundColor Green
}

# 生成安装说明
$md = @(
  "# 插件 tarball（$(Get-Date -Format 'yyyy-MM-dd HH:mm')）",
  "",
  "本目录由 `tools/pack-plugins.ps1` 生成，**不提交到 git**。安装方式：",
  "",
  "```powershell",
  "dsh plugin --profile web add file:<本目录绝对路径>\<包名>-<版本>.tgz",
  "# 桌面端：",
  "dsh plugin --profile desktop add file:<...>",
  "```",
  "",
  "## 包清单",
  ""
) + ($rows | ForEach-Object { "- ``$_``" })
$md | Set-Content (Join-Path $out 'INSTALL.md') -Encoding utf8
Write-Host ''
Write-Host "输出目录：$out" -ForegroundColor Yellow
$rows | ForEach-Object { Write-Host "  $_" }
