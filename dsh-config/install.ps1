#!/usr/bin/env pwsh
# ============================================================================
# DSH 本机架构一键恢复脚本（换机 / 迁移用）—— 双轨版 v2
#
# 从本仓库恢复：全局指令、配置、web profile、插件（link 进 profile bundles），
# 并批量恢复 skill（清单来自 framework-manifest.json，回退旧硬编码列表）。
#
# 用法（在本仓库根目录运行）：
#   pwsh dsh-config/install.ps1                     # 配置 + skill + 插件（全量）
#   pwsh dsh-config/install.ps1 -PluginsOnly        # 只装/重接插件（deploy.ps1 -Track plugins 用）
#   pwsh dsh-config/install.ps1 -PluginsOnly -Profile desktop   # 桌面 profile（app 管理，仅重接 link）
#   pwsh dsh-config/install.ps1 -DryRun             # 只预览
#   pwsh dsh-config/install.ps1 -SkipSkills         # 只恢复配置
#   pwsh dsh-config/install.ps1 -SkipConfig         # 只装 skill
#
# 幂等：已存在的 skill 目录会被跳过（不覆盖本地修改）。
# 安全：覆盖前先备份到 ~/.dsh/_backup_<时间戳>/。
# ============================================================================

param(
  [ValidateSet('github', 'gitee')]
  [string]$Source = 'github',
  [ValidateSet('web', 'desktop')]
  [string]$Profile = 'web',
  [string[]]$Only = @(),
  [switch]$SkipSkills,
  [switch]$SkipConfig,
  [switch]$PluginsOnly,
  [switch]$SkipSupplyChain,
  [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$script:pluginOk = $true
$dshHome = Join-Path $env:USERPROFILE '.dsh'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$owner = 'hpsks416'

# ---------- 清单（唯一事实源） ----------
$manifestPath = Join-Path $repoRoot 'framework-manifest.json'
$manifest = $null
if (Test-Path $manifestPath) {
  try { $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json } catch {
    Write-Host "! framework-manifest.json 解析失败，回退旧硬编码列表：$($_.Exception.Message)" -ForegroundColor Yellow
  }
}

# 旧硬编码列表（仅在无清单时兜底；hatch-pet 已退役，不参与迁移）
$legacySkills = @(
  'acp-studio', 'agent-workflow-orchestration', 'agents-md-skill-layering',
  'browser-viz-local-scripts', 'dsh-plugin-lazy-adapter-resolution', 'github-ready-packager',
  'homophone-pun-analysis', 'hpsks416', 'long-sentence-structurizer',
  'migrate-conversation-prompt', 'open-source-scout', 'resume-conversation-brief',
  'resume-conversation-full', 'rust-refactor-local-projects', 'secret-scan',
  'secure-push-workflow', 'skill-evaluator', 'skill-lifecycle-manager', 'skill-optimizer',
  'web-3d-asset-pipeline', 'windows-node-spawn-cli'
)
$legacyPlugins = [ordered]@{
  'dsh-skill-studio'       = 'dsh-skill-studio-patched'
  'dsh-goat-vision'        = 'dsh-goat-vision'
  'dsh-retrieval-guard'    = 'dsh-retrieval-guard'
  'dsh-secure-push-guard'  = 'dsh-secure-push-guard'
  'dsh-session-sync-flush' = 'dsh-session-sync-flush'
}

$skills = $legacySkills
$linkedPlugins = $legacyPlugins
$npmPlugins = @()
$onlyIds = @($Only | Where-Object { $_ })
if ($manifest) {
  $skills = @($manifest.items | Where-Object { $_.kind -eq 'skill' -and ($_.frameworks -contains 'dsh') } | ForEach-Object { $_.id })
  $linkedPlugins = [ordered]@{}
  $npmPlugins = @()
  foreach ($it in @($manifest.items | Where-Object { $_.kind -eq 'plugin' -and ($_.frameworks -contains 'dsh') })) {
    $profs = @($it.profiles)
    if ($profs.Count -gt 0 -and -not ($profs -contains $Profile)) { continue }
    if ($onlyIds.Count -gt 0 -and -not ($onlyIds -contains $it.id)) { continue }
    if ($it.install -and $it.install.mode -eq 'npm') { $npmPlugins += $it; continue }
    $linkedPlugins[$it.id] = (Split-Path $it.source -Leaf)
  }
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $dshHome "_backup_$ts"

function Backup-And-Restore-File {
  param([string]$Src, [string]$Dst)
  if (Test-Path $Dst) {
    $rel = $Dst.Replace($dshHome + '\', '')
    $bak = Join-Path $backupRoot $rel
    if (-not $DryRun) {
      New-Item -ItemType Directory -Force -Path (Split-Path $bak) | Out-Null
      Copy-Item $Dst $bak -Force
    }
    Write-Host "    备份旧文件 -> ~/.dsh/_backup_$ts\$rel" -ForegroundColor DarkGray
  }
  if ($DryRun) { Write-Host "    [DRY] 恢复 $Dst" -ForegroundColor Yellow; return }
  New-Item -ItemType Directory -Force -Path (Split-Path $Dst) | Out-Null
  Copy-Item $Src $Dst -Force
  Write-Host "    恢复 ~/.dsh/$($Dst.Replace($dshHome + '\', ''))" -ForegroundColor Green
}

function Install-LinkedPlugins {
  Write-Host ''
  Write-Host "[$($label)] 插件轨：$($linkedPlugins.Count) 个 link + $($npmPlugins.Count) 个 npm -> profile=$Profile" -ForegroundColor Yellow

  # 版本/约束断言（只看仓库内的 link 插件；npm 插件的版本由 manifest 钉死）
  if ($manifest) {
    foreach ($it in @($manifest.items | Where-Object { $_.kind -eq 'plugin' -and ($_.frameworks -contains 'dsh') -and $_.source -notlike 'npm:*' })) {
      $pj = Join-Path $repoRoot (Join-Path $it.source 'package.json')
      if (-not (Test-Path $pj)) { Write-Host "    [FAIL] $($it.id) 缺 package.json" -ForegroundColor Red; continue }
      $actual = Get-Content $pj -Raw | ConvertFrom-Json
      if ($actual.version -ne $it.version) {
        Write-Host "    [WARN] $($it.id) 清单 $($it.version) ≠ package.json $($actual.version)" -ForegroundColor Yellow
      }
      $dshReq = if ($actual.engines -and $actual.engines.dsh) { $actual.engines.dsh } else { $null }
      if ($dshReq) { Write-Host ("    [约束] {0} {1} 要求 dsh {2}" -f $it.id, $it.version, $dshReq) -ForegroundColor DarkGray }
      else { Write-Host ("    [约束] {0} {1} 未声明 engines.dsh（建议补）" -f $it.id, $it.version) -ForegroundColor DarkYellow }
    }
  }

  $pkgPath = Join-Path $dshHome "profiles\$Profile\package.json"
  if (-not (Test-Path $pkgPath)) {
    Write-Host "    x 缺 $pkgPath（先恢复 profile-web 配置）" -ForegroundColor Red
    $script:pluginOk = $false
    return
  }
  $fsHome = $env:USERPROFILE.Replace('\', '/')
  $pkgText = Get-Content $pkgPath -Raw

  foreach ($dep in $linkedPlugins.Keys) {
    $srcDir = $linkedPlugins[$dep]
    $src = Join-Path $scriptRoot $srcDir
    $dstDir = Join-Path $dshHome $srcDir
    if (-not (Test-Path $src)) { Write-Host "    [FAIL] $dep（缺 dsh-config/$srcDir）" -ForegroundColor Red; continue }
    if (-not $DryRun) {
      if (Test-Path $dstDir) {
        $bak = Join-Path $backupRoot $srcDir
        New-Item -ItemType Directory -Force -Path $bak | Out-Null
        Copy-Item $dstDir $bak -Recurse -Force
        Write-Host "    备份旧 $srcDir" -ForegroundColor DarkGray
      }
      Copy-Item $src $dstDir -Recurse -Force
      Write-Host "    恢复 ~/.dsh/$srcDir" -ForegroundColor Green
    } else {
      Write-Host "    [DRY] Copy-Item $src -> $dstDir" -ForegroundColor Yellow
    }
    # 重接 link 路径（字符串级，保留其它依赖不动）
    $pkgText = $pkgText -replace ('"' + [regex]::Escape($dep) + '"\s*:\s*"link:[^"]*"'), ("`"$dep`": `"link:$fsHome/.dsh/$srcDir`"")
  }

  if ($DryRun) { Write-Host '    [DRY] 重接 profile-web/package.json 的 link 路径' -ForegroundColor Yellow }
  else {
    Set-Content -Path $pkgPath -Value $pkgText -Encoding utf8
    Write-Host '    重接 package.json 的 link 插件路径' -ForegroundColor Green
  }

  # npm 分发的外部插件（manifest: install.mode = npm）：pnpm add 固定版本 + 追加 bundle
  if ($npmPlugins.Count -gt 0) {
    $pnpmCmd = (Get-Command pnpm -ErrorAction SilentlyContinue)
    if (-not $pnpmCmd) {
      Write-Host '    x 找不到 pnpm，跳过 npm 分发插件（先装 pnpm 再跑）' -ForegroundColor Red
    } else {
      foreach ($it in $npmPlugins) {
        $spec = "$($it.package)@$($it.version)"
        Write-Host "    [npm] $spec（$($it.note)）" -ForegroundColor DarkGray
        if ($DryRun) { Write-Host "      [DRY] pnpm add $spec → 跑 thirdparty-gate（供应链扫描）→ 追加 bundle $($it.package)" -ForegroundColor Yellow; continue }
        Push-Location (Split-Path $pkgPath -Parent)
        try { & $pnpmCmd.Source add $spec --ignore-scripts 2>&1 | Out-Null } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { Write-Host "      [FAIL] pnpm add 退出码 $LASTEXITCODE" -ForegroundColor Red; continue }

        # 第三方插件装前门禁：SkillSpector 供应链扫描（fail-closed，P6）
        if (-not $SkipSupplyChain) {
          $gate = Join-Path (Split-Path $scriptRoot -Parent) 'thirdparty-gate.ps1'
          $instDir = Join-Path (Split-Path $pkgPath -Parent) ("node_modules\" + $it.package)
          if (-not (Test-Path $gate)) {
            Write-Host "      [BLOCK] 缺门禁脚本 thirdparty-gate.ps1（fail-closed，不注册 bundle）" -ForegroundColor Red
            $script:pluginOk = $false
            continue
          }
          & $gate -Path $instDir
          $gateCode = $LASTEXITCODE
          if ($gateCode -ne 0) {
            Write-Host "      [BLOCK] 供应链扫描未通过（exit $gateCode）→ 不注册 bundle；确认可信后重跑加 -SkipSupplyChain" -ForegroundColor Red
            $script:pluginOk = $false
            continue
          }
        } else {
          Write-Host '      ! 已跳过供应链扫描（-SkipSupplyChain，风险自负）' -ForegroundColor Yellow
        }
        $j = Get-Content $pkgPath -Raw | ConvertFrom-Json
        $bs = @($j.dsh.profile.bundles)
        if ($bs -notcontains $it.package) {
          $j.dsh.profile.bundles = @($bs + $it.package)
          ($j | ConvertTo-Json -Depth 10) | Set-Content $pkgPath -Encoding utf8
          Write-Host "      已装并注册 bundle $($it.package)" -ForegroundColor Green
        } else {
          Write-Host "      已装；bundle 已存在 $($it.package)" -ForegroundColor DarkGray
        }
      }
    }
  }

  $otherLinks = [regex]::Matches($pkgText, '"([^"]+)"\s*:\s*"link:[^"]*"') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $linkedPlugins.Keys -notcontains $_ }
  if ($otherLinks) {
    Write-Host ''
    Write-Host '    ! 以下依赖仍是本地 link、未包含在本仓库中，需手动恢复：' -ForegroundColor Magenta
    foreach ($l in $otherLinks) { Write-Host "       - $l" -ForegroundColor Magenta }
  }
}

# ---------- PluginsOnly：只做插件轨 --------------------------------
if ($PluginsOnly) {
  $label = '1/1'
  Write-Host ''
  Write-Host '============================================================' -ForegroundColor Cyan
  Write-Host " DSH 插件轨（manifest: $(if ($manifest) { 'framework-manifest.json' } else { 'legacy' })）profile=$Profile" -ForegroundColor Cyan
  if ($DryRun) { Write-Host ' [DRY RUN] 只预览，不写入' -ForegroundColor Yellow }
  Write-Host '============================================================' -ForegroundColor Cyan
  if ($Profile -eq 'desktop') {
    Write-Host ' 注意：desktop profile 由桌面 app 管理（Plugins 面板/插件市场），这里只重接 link；' -ForegroundColor Yellow
    Write-Host '       装/卸插件请优先用 app 的 Plugins 面板，改完需重启 app。' -ForegroundColor Yellow
  }
  Install-LinkedPlugins
  Write-Host ''
  if ($Profile -eq 'web') {
    Write-Host '下一步（必须）：cd ~/.dsh/profiles/web; pnpm install; 重启 DSH' -ForegroundColor Yellow
  } else {
    Write-Host '下一步（必须）：重启桌面 app（desktop profile 由 app 加载）' -ForegroundColor Yellow
  }
  Write-Host '若启动失败，日志：~/.dsh/logs/startup-*.log / ~/.dsh/storages/session_projcache/sessions/session-*.json' -ForegroundColor DarkGray
  if (-not $script:pluginOk) { Write-Host 'x 插件轨未完成（见上方错误），不要执行 pnpm/重启' -ForegroundColor Red; exit 2 }
  exit 0
}

# ---------- 全量 ------------------------------------------------
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' DSH 本机架构一键恢复（双轨版）' -ForegroundColor Cyan
Write-Host " 脚本目录: $scriptRoot" -ForegroundColor DarkGray
Write-Host " 目标目录: $dshHome" -ForegroundColor DarkGray
Write-Host " 清单    : $(if ($manifest) { "$($skills.Count) skills / $($linkedPlugins.Count) plugins" } else { "$($skills.Count) skills（legacy）" })" -ForegroundColor DarkGray
Write-Host " skill 源: $Source" -ForegroundColor DarkGray
if ($DryRun) { Write-Host ' [DRY RUN] 只预览，不写入' -ForegroundColor Yellow }
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

# ---- 1. 配置 + 插件 ---------------------------------------------
if (-not $SkipConfig) {
  Write-Host '[1/3] 恢复配置 + 插件' -ForegroundColor Yellow
  if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $dshHome | Out-Null }

  Backup-And-Restore-File (Join-Path $scriptRoot 'AGENTS.md') (Join-Path $dshHome 'AGENTS.md')
  Backup-And-Restore-File (Join-Path $scriptRoot 'settings.yaml') (Join-Path $dshHome 'settings.yaml')
  Backup-And-Restore-File (Join-Path $scriptRoot 'profile-web\cordis.patch.yml') (Join-Path $dshHome "profiles\$Profile\cordis.patch.yml")
  Backup-And-Restore-File (Join-Path $scriptRoot 'profile-web\cordis.yml') (Join-Path $dshHome "profiles\$Profile\cordis.yml")
  Backup-And-Restore-File (Join-Path $scriptRoot 'profile-web\pnpm-workspace.yaml') (Join-Path $dshHome "profiles\$Profile\pnpm-workspace.yaml")
  Backup-And-Restore-File (Join-Path $scriptRoot 'profile-web\package.json') (Join-Path $dshHome "profiles\$Profile\package.json")

  $label = '1/3'
  Install-LinkedPlugins
} else {
  Write-Host '[1/3] 跳过配置恢复（-SkipConfig）' -ForegroundColor DarkGray
}

# ---- 2. 安装 skill ----------------------------------------------
if (-not $SkipSkills) {
  Write-Host ''
  Write-Host "[2/3] 安装 $($skills.Count) 个 skill" -ForegroundColor Yellow
  $skillsDir = Join-Path $dshHome 'skills'
  if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null }

  $okCount = 0; $skipCount = 0; $failCount = 0
  foreach ($s in $skills) {
    $dst = Join-Path $skillsDir $s
    if (Test-Path (Join-Path $dst 'SKILL.md')) {
      Write-Host "    [已存在] $s" -ForegroundColor DarkGray
      $skipCount++
      continue
    }
    if ($DryRun) { Write-Host "    [DRY] 安装 $s"; $okCount++; continue }
    if ($Source -eq 'github') { $url = "https://github.com/$owner/$s.git" }
    else { $url = "https://gitee.com/$owner/$s.git" }
    git clone --depth 1 $url $dst 2>&1 | Out-Null
    if (Test-Path (Join-Path $dst 'SKILL.md')) {
      Write-Host "    [OK] $s" -ForegroundColor Green
      $okCount++
    } else {
      Write-Host "    [FAIL] $s" -ForegroundColor Red
      $failCount++
    }
  }
  Write-Host "  结果: 安装 $okCount / 已存在 $skipCount / 失败 $failCount" -ForegroundColor Cyan
} else {
  Write-Host ''
  Write-Host '[2/3] 跳过 skill 安装（-SkipSkills）' -ForegroundColor DarkGray
}

# ---- 3. 收尾提醒 -------------------------------------------------
Write-Host ''
Write-Host '[3/3] 需要你手动补齐的密钥（本仓库不含任何密钥）' -ForegroundColor Yellow
Write-Host '  1. 环境变量（settings.yaml 引用，无明文）：' -ForegroundColor White
Write-Host '       COMMANDCODE_API_KEY  DEEPSEEK_API_KEY' -ForegroundColor White
Write-Host '  2. ~/.dsh/.credentials.yaml        —— DSH 凭据' -ForegroundColor White
Write-Host '  3. ~/.dsh/dsh-skill-studio/extractor.json —— 提取器 LLM 配置' -ForegroundColor White
Write-Host '  4. secrets.cmd（推送 GitHub/Gitee 用，若需双推）' -ForegroundColor White
Write-Host ''
Write-Host '恢复完成后：' -ForegroundColor Yellow
if ($Profile -eq 'web') {
  Write-Host '  cd ~/.dsh/profiles/web  &&  pnpm install  &&  重启 DSH' -ForegroundColor White
} else {
  Write-Host '  重启桌面 app（desktop profile 由 app 加载；装/卸插件优先用 Plugins 面板）' -ForegroundColor White
}
Write-Host '  启动失败日志：~/.dsh/logs/startup-*.log / ~/.dsh/sessions/<工作区>/<session-id>/session.v3.jsonl.zstd' -ForegroundColor DarkGray
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host " 完成。备份目录: ~/.dsh/_backup_$ts/（如有）" -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
