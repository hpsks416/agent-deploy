#!/usr/bin/env pwsh
# ============================================================================
# agent-deploy —— AGENT 框架跨框架部署器（双轨版 v2）
#
# 两条轨（一份清单 framework-manifest.json 管着）：
#   skills  轨：把 skills/<name>/ 拷到目标框架的 skills 目录（跨 codex/claude/dsh）
#   plugins 轨：把 dsh-config/<plugin>/ link 进 ~/.dsh 的 profile bundles（仅 DSH）
#
# 用法（在 agent-deploy 仓库根目录运行）：
#   pwsh deploy.ps1 -Framework dsh -Track all                     # 双轨都铺
#   pwsh deploy.ps1 -Framework dsh -Track plugins -DryRun         # 只预览插件轨
#   pwsh deploy.ps1 -Framework dsh -Track plugins -Profile desktop -DryRun   # 桌面 profile（app 管理）
#   pwsh deploy.ps1 -Framework codex -Track skills                # 只铺 skill（老行为）
#   pwsh deploy.ps1 -Rollback                                     # 回滚最近一次
#   pwsh deploy.ps1 -Framework codex -Provider commandcode -Source gitee   # 换源
# ============================================================================

param(
  [ValidateSet('codex', 'claude', 'dsh')]
  [string]$Framework = 'codex',
  [string]$Provider = 'commandcode',
  [string]$Model = '',
  [ValidateSet('github', 'gitee')]
  [string]$Source = 'github',
  [ValidateSet('web', 'desktop')]
  [string]$Profile = 'web',
  [ValidateSet('skills', 'plugins', 'all')]
  [string]$Track = 'skills',
  [switch]$SkipSkills,
  [switch]$SkipConfig,
  [switch]$Rollback,
  [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$homeDir = $env:USERPROFILE

$doSkills  = (-not $SkipSkills) -and ($Track -in @('skills', 'all'))
$doPlugins = ($Track -in @('plugins', 'all')) -and ($Framework -eq 'dsh')
$doConfig  = (-not $SkipConfig) -and ($Track -ne 'plugins')

# ---------- 0. 清单（双轨的唯一事实源） ----------
$manifestPath = Join-Path $scriptRoot 'framework-manifest.json'
$manifest = $null
if (Test-Path $manifestPath) {
  try { $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json } catch {
    Write-Host "x framework-manifest.json 解析失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
} else {
  Write-Host '! 未找到 framework-manifest.json，回退到旧清单 core-skills.txt（仅 skills 轨）' -ForegroundColor Yellow
}

function Get-ManifestItems([string]$kind, [string]$fw) {
  if (-not $manifest) { return @() }
  return @($manifest.items | Where-Object { $_.kind -eq $kind -and ($_.frameworks -contains $fw) })
}

# ---------- 0.5 回滚 ----------
$stateDir = Join-Path $homeDir '.agent-deploy\state'
if ($Rollback) {
  if (-not (Test-Path $stateDir)) { Write-Host 'x 没有可回滚的状态记录' -ForegroundColor Red; exit 1 }
  $last = Get-ChildItem $stateDir -Filter '*.json' | Sort-Object LastWriteTime | Select-Object -Last 1
  if (-not $last) { Write-Host 'x 状态目录为空' -ForegroundColor Red; exit 1 }
  $st = Get-Content $last.FullName -Raw | ConvertFrom-Json
  Write-Host ''
  Write-Host "回滚 $($st.timestamp) 那次（框架=$($st.framework) 轨=$($st.track)）" -ForegroundColor Yellow
  foreach ($d in @($st.createdSkills) + @($st.createdPlugins)) {
    if ($d -and (Test-Path $d)) {
      if ($DryRun) { Write-Host "  [DRY] 删 $d" } else { Remove-Item $d -Recurse -Force; Write-Host "  已删 $d" -ForegroundColor Green }
    }
  }
  foreach ($b in @($st.backups)) {
    if ($b -and $b.dest -and $b.src -and (Test-Path $b.src)) {
      if ($DryRun) { Write-Host "  [DRY] 恢复 $($b.dest) <- $($b.src)" }
      else {
        New-Item -ItemType Directory -Force -Path (Split-Path $b.dest) | Out-Null
        Copy-Item $b.src $b.dest -Force
        Write-Host "  已恢复 $($b.dest)" -ForegroundColor Green
      }
    }
  }
  Write-Host ''
  Write-Host '提醒：如回滚涉及插件，请到 ~/.dsh/profiles/web 跑 pnpm install 并重启 DSH。' -ForegroundColor Yellow
  exit 0
}

# ---------- 1. 读中间商目录 ----------
$providers = Get-Content (Join-Path $scriptRoot 'providers.json') -Raw | ConvertFrom-Json
if (-not $providers.$Provider) {
  Write-Host "x 未知中间商 '$Provider'（可用: $(($providers.PSObject.Properties.Name) -join ', ')）" -ForegroundColor Red
  exit 1
}
$p = $providers.$Provider
if (-not $Model) { $Model = $p.default_model }
if (-not $p.models.$Model) {
  Write-Host "x 中间商 '$Provider' 无模型 '$Model'（可用: $(($p.models.PSObject.Properties.Name) -join ', ')）" -ForegroundColor Red
  exit 1
}
$modelId = $p.models.$Model

# ---------- 2. skill 清单（清单优先，回退 core-skills.txt） ----------
$skills = @()
if ($manifest) {
  foreach ($it in (Get-ManifestItems 'skill' $Framework)) {
    $skills += [pscustomobject]@{ name = $it.id; coupling = $it.coupling }
  }
} else {
  foreach ($line in Get-Content (Join-Path $scriptRoot 'core-skills.txt')) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    $parts = $t -split '\s*\|\s*'
    $skills += [pscustomobject]@{ name = $parts[0].Trim(); coupling = $parts[1].Trim() }
  }
}

# ---------- 3. 目标目录映射 ----------
switch ($Framework) {
  'codex'  { $skillsDir = Join-Path $homeDir '.codex\skills';  $instrPath = Join-Path $homeDir '.codex\AGENTS.md';   $cfgPath = Join-Path $homeDir '.codex\config.toml' }
  'claude' { $skillsDir = Join-Path $homeDir '.claude\skills'; $instrPath = Join-Path $homeDir '.claude\CLAUDE.md';  $cfgPath = Join-Path $homeDir '.claude\claude-env.ps1' }
  'dsh'    { $skillsDir = Join-Path $homeDir '.dsh\skills';    $instrPath = Join-Path $homeDir '.dsh\AGENTS.md';     $cfgPath = Join-Path $homeDir '.dsh\settings.yaml' }
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $homeDir ".agent-deploy_backup_$ts"
$state = [ordered]@{
  timestamp = (Get-Date).ToString('o'); framework = $Framework; track = $Track
  createdSkills = @(); skippedSkills = @(); createdPlugins = @(); backups = @()
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host " agent-deploy v2  框架=$Framework  轨=$Track  中间商=$($p.name)  模型=$Model ($modelId)" -ForegroundColor Cyan
if ($manifest) {
  Write-Host " 清单 : framework-manifest.json（$(@($manifest.items | Where-Object kind -eq 'skill').Count) skills / $(@($manifest.items | Where-Object kind -eq 'plugin').Count) plugins）" -ForegroundColor DarkGray
} else {
  Write-Host ' 清单 : core-skills.txt（旧）' -ForegroundColor DarkGray
}
Write-Host " skill 目录 : $skillsDir" -ForegroundColor DarkGray
Write-Host " 插件目标   : $homeDir\.dsh\profiles\$Profile（仅 DSH；desktop 由 app 管理）" -ForegroundColor DarkGray
if ($DryRun) { Write-Host ' [DRY RUN] 只预览，不实际写入' -ForegroundColor Yellow }
Write-Host '============================================================' -ForegroundColor Cyan

# ---------- 4. skills 轨 ----------
if ($doSkills) {
  Write-Host ''
  Write-Host "[1/3] skills 轨：铺 $($skills.Count) 个 skill" -ForegroundColor Yellow
  New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
  $ok = 0; $skip = 0; $fail = 0
  foreach ($s in $skills) {
    $srcSkill = Join-Path $scriptRoot "skills\$($s.name)"
    $dst = Join-Path $skillsDir $s.name
    if (-not (Test-Path $srcSkill)) { Write-Host "  [FAIL] $($s.name)（本仓 skills/ 下无此 skill）" -ForegroundColor Red; $fail++; continue }
    if (Test-Path (Join-Path $dst 'SKILL.md')) { Write-Host "  [已存在] $($s.name)" -ForegroundColor DarkGray; $skip++; $state.skippedSkills += $dst; continue }
    if ($DryRun) { Write-Host "  [DRY] Copy-Item $srcSkill -> $dst"; $ok++; continue }
    Copy-Item $srcSkill $dst -Recurse -Force
    if (Test-Path (Join-Path $dst 'SKILL.md')) { Write-Host "  [OK] $($s.name)" -ForegroundColor Green; $ok++; $state.createdSkills += $dst }
    else { Write-Host "  [FAIL] $($s.name)" -ForegroundColor Red; $fail++ }
  }
  Write-Host "  结果: 安装 $ok / 已存在 $skip / 失败 $fail" -ForegroundColor Cyan
} else {
  Write-Host ''
  Write-Host '[1/3] 跳过 skills 轨' -ForegroundColor DarkGray
}

# ---------- 5. plugins 轨（仅 DSH；委托给 dsh-config/install.ps1 单一实现） ----------
if ($doPlugins) {
  Write-Host ''
  $pluginItems = Get-ManifestItems 'plugin' 'dsh'
  Write-Host "[2/3] plugins 轨：$($pluginItems.Count) 个插件（link + profile bundles；profile=$Profile）" -ForegroundColor Yellow

  # 版本/约束断言与安装都在 dsh-config/install.ps1 的单一实现里（-PluginsOnly），此处只做委托。
  $installScript = Join-Path $scriptRoot 'dsh-config\install.ps1'
  if (-not (Test-Path $installScript)) {
    Write-Host '  x 缺 dsh-config/install.ps1，无法安装插件' -ForegroundColor Red
  } else {
    $plArgs = @{ PluginsOnly = $true; Source = $Source; Profile = $Profile }
    if ($DryRun) { $plArgs.DryRun = $true }
    & $installScript @plArgs
    if ($LASTEXITCODE -ne 0) { Write-Host "  ! 插件安装返回 $LASTEXITCODE" -ForegroundColor Yellow }
  }
  foreach ($it in $pluginItems) { $state.createdPlugins += (Join-Path $homeDir $it.id) }
} else {
  Write-Host ''
  if ($Track -in @('plugins', 'all') -and $Framework -ne 'dsh') {
    Write-Host '[2/3] 跳过 plugins 轨（插件契约只在 DSH 生效）' -ForegroundColor DarkGray
  } else {
    Write-Host '[2/3] 跳过 plugins 轨' -ForegroundColor DarkGray
  }
}

# ---------- 6 & 7. 铁律 + 中间商配置（仅非 plugins 轨） ----------
if ($doConfig) {
  Write-Host ''
  Write-Host '[3/3] 铺铁律 + 生成中间商/模型配置' -ForegroundColor Yellow
  $instrSrc = if ($Framework -eq 'dsh') { Join-Path $scriptRoot 'dsh-config\AGENTS.md' } else { Join-Path $scriptRoot 'templates\agents-core.md' }
  $instr = Get-Content $instrSrc -Raw
  if ((Test-Path $instrPath) -and (-not $DryRun)) {
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    Copy-Item $instrPath (Join-Path $backupRoot (Split-Path $instrPath -Leaf)) -Force
    Write-Host "  备份旧指令 -> $backupRoot" -ForegroundColor DarkGray
    $state.backups += [pscustomobject]@{ dest = $instrPath; src = (Join-Path $backupRoot (Split-Path $instrPath -Leaf)) }
  }
  if ($DryRun) { Write-Host "  [DRY] 写 $instrPath" }
  else {
    New-Item -ItemType Directory -Force -Path (Split-Path $instrPath) | Out-Null
    Set-Content -Path $instrPath -Value $instr -Encoding utf8
    Write-Host "  已写 $instrPath" -ForegroundColor Green
  }

  $cfgText = $null
  if ($Framework -eq 'codex') {
    $tpl = @'
# 由 agent-deploy 生成 | 框架: codex | 中间商: {PNAME} | 模型: {MODEL_ALIAS}
model = "{MODEL_ID}"
model_provider = "{PROVIDER}"
model_reasoning_effort = "high"

[model_providers.{PROVIDER}]
name = "{PNAME}"
base_url = "{BASE_URL}"
wire_api = "responses"

[model_providers.{PROVIDER}.auth]
command = "powershell"
args = ["-NoProfile", "-Command", "Write-Output $env:{API_KEY_ENV}"]
'@
    $cfgText = $tpl.Replace('{PNAME}', $p.name).Replace('{MODEL_ALIAS}', $Model).Replace('{MODEL_ID}', $modelId).Replace('{PROVIDER}', $Provider).Replace('{BASE_URL}', $p.openai_base_url).Replace('{API_KEY_ENV}', $p.api_key_env)
  }
  elseif ($Framework -eq 'claude') {
    if (-not $p.anthropic_base_url) {
      Write-Host "  x 中间商 '$Provider' 无 Anthropic 端点，不支持 Claude Code。请在 providers.json 补 anthropic_base_url。" -ForegroundColor Red
    } else {
      $tpl = @'
# 由 agent-deploy 生成 | 框架: claude | 中间商: {PNAME} | 模型: {MODEL_ALIAS}
# 用法: & "<本文件路径>"   或   加入 PowerShell $PROFILE
$env:ANTHROPIC_BASE_URL = "{BASE_URL}"
$env:ANTHROPIC_AUTH_TOKEN = $env:{API_KEY_ENV}
$env:ANTHROPIC_MODEL = "{MODEL_ID}"
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = "{MODEL_ID}"
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "{MODEL_ID}"
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "{MODEL_ID}"
$env:CLAUDE_CODE_SUBAGENT_MODEL = "{MODEL_ID}"
$env:CLAUDE_CODE_EFFORT_LEVEL = "max"
'@
      $cfgText = $tpl.Replace('{PNAME}', $p.name).Replace('{MODEL_ALIAS}', $Model).Replace('{MODEL_ID}', $modelId).Replace('{PROVIDER}', $Provider).Replace('{BASE_URL}', $p.anthropic_base_url).Replace('{API_KEY_ENV}', $p.api_key_env)
    }
  }
  elseif ($Framework -eq 'dsh') {
    $tpl = @'
# 由 agent-deploy 生成 | 框架: dsh | 中间商: {PNAME} | 模型: {MODEL_ALIAS}
llm-pi-ai:
  providers:
    {PROVIDER}:
      displayName: {PNAME}
      api: openai-completions
      baseURL: {BASE_URL}
      apiKeyEnv: {API_KEY_ENV}
      models:
        - id: {MODEL_ID}
agent-default-model:
  provider: {PROVIDER}
  model: {MODEL_ID}
  reasoningEffort: high
'@
    $cfgText = $tpl.Replace('{PNAME}', $p.name).Replace('{MODEL_ALIAS}', $Model).Replace('{MODEL_ID}', $modelId).Replace('{PROVIDER}', $Provider).Replace('{BASE_URL}', $p.openai_base_url).Replace('{API_KEY_ENV}', $p.api_key_env)
  }

  if ($cfgText) {
    if ((Test-Path $cfgPath) -and (-not $DryRun)) {
      New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
      Copy-Item $cfgPath (Join-Path $backupRoot (Split-Path $cfgPath -Leaf)) -Force
      Write-Host "  备份旧配置 -> $backupRoot" -ForegroundColor DarkGray
      $state.backups += [pscustomobject]@{ dest = $cfgPath; src = (Join-Path $backupRoot (Split-Path $cfgPath -Leaf)) }
    }
    if ($DryRun) { Write-Host "  [DRY] 写 $cfgPath"; Write-Host $cfgText }
    else {
      New-Item -ItemType Directory -Force -Path (Split-Path $cfgPath) | Out-Null
      Set-Content -Path $cfgPath -Value $cfgText -Encoding utf8
      Write-Host "  已写 $cfgPath" -ForegroundColor Green
    }
  }
} else {
  Write-Host ''
  Write-Host '[3/3] 跳过铁律/配置' -ForegroundColor DarkGray
}

# ---------- 8. 保存状态（供 -Rollback） ----------
if (-not $DryRun) {
  New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
  $statePath = Join-Path $stateDir "$ts-$Framework-$Track.json"
  $state | ConvertTo-Json -Depth 5 | Set-Content -Path $statePath -Encoding utf8
  Write-Host "  状态已存: $statePath" -ForegroundColor DarkGray
}

# ---------- 9. 框架耦合清单 ----------
Write-Host ''
Write-Host '框架耦合清单（换框架后需人工核对，详见 FRAMEWORK-COUPLING.md）：' -ForegroundColor Yellow
$coupled = $skills | Where-Object { $_.coupling -ne 'none' }
if (-not $coupled) {
  Write-Host '  （本清单全部框架无关）' -ForegroundColor DarkGray
} else {
  foreach ($s in $coupled) {
    $color = switch ($s.coupling) {
      'heavy'    { 'Red' }
      'hardcode' { 'Magenta' }
      'env'      { 'DarkYellow' }
      default    { 'DarkYellow' }
    }
    Write-Host "  [$($s.coupling.PadRight(8))] $($s.name)" -ForegroundColor $color
  }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host " 完成。（备份目录: $backupRoot，如有旧文件）" -ForegroundColor Cyan
if ($doPlugins) {
  if ($Profile -eq 'web') { Write-Host ' 插件轨下一步：cd ~/.dsh/profiles/web; pnpm install; 重启 DSH' -ForegroundColor Yellow }
  else { Write-Host ' 插件轨下一步：重启桌面 app（desktop profile 由 app 加载）' -ForegroundColor Yellow }
}
Write-Host '============================================================' -ForegroundColor Cyan
