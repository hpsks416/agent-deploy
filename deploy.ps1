#!/usr/bin/env pwsh
# ============================================================================
# agent-deploy —— AGENT 框架跨框架部署器
# 换框架 / 换中间商 / 换模型，一键铺到位。
#
# 用法（在 agent-deploy 仓库根目录运行）：
#   pwsh deploy.ps1 -Framework codex -Provider commandcode -Model deepseek-v4-pro
#   pwsh deploy.ps1 -Framework claude -Provider deepseek -Model deepseek-flash
#   pwsh deploy.ps1 -Framework dsh    -Provider commandcode
#   pwsh deploy.ps1 -Framework codex -Source gitee          # 国内直连
#   pwsh deploy.ps1 -Framework codex -DryRun                # 只预览不写入
#
# 三个维度独立可换：
#   -Framework  codex | claude | dsh          （框架）
#   -Provider   providers.json 里的任意键     （中间商）
#   -Model      该中间商 models 里的任意别名  （模型）
# ============================================================================

param(
  [ValidateSet('codex', 'claude', 'dsh')]
  [string]$Framework = 'codex',
  [string]$Provider = 'commandcode',
  [string]$Model = '',
  [ValidateSet('github', 'gitee')]
  [string]$Source = 'github',
  [switch]$SkipSkills,
  [switch]$SkipConfig,
  [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$owner = 'hpsks416'

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

# ---------- 2. 读核心 skill 清单 ----------
$skills = @()
foreach ($line in Get-Content (Join-Path $scriptRoot 'core-skills.txt')) {
  $t = $line.Trim()
  if ($t -eq '' -or $t.StartsWith('#')) { continue }
  $parts = $t -split '\s*\|\s*'
  $skills += [pscustomobject]@{ name = $parts[0].Trim(); coupling = $parts[1].Trim() }
}

# ---------- 3. 目标目录映射 ----------
$homeDir = $env:USERPROFILE
switch ($Framework) {
  'codex'  { $skillsDir = Join-Path $homeDir '.codex\skills';  $instrPath = Join-Path $homeDir '.codex\AGENTS.md';   $cfgPath = Join-Path $homeDir '.codex\config.toml' }
  'claude' { $skillsDir = Join-Path $homeDir '.claude\skills'; $instrPath = Join-Path $homeDir '.claude\CLAUDE.md';  $cfgPath = Join-Path $homeDir '.claude\claude-env.ps1' }
  'dsh'    { $skillsDir = Join-Path $homeDir '.dsh\skills';    $instrPath = Join-Path $homeDir '.dsh\AGENTS.md';     $cfgPath = Join-Path $homeDir '.dsh\settings.yaml' }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host " agent-deploy  框架=$Framework  中间商=$($p.name)  模型=$Model ($modelId)  源=$Source" -ForegroundColor Cyan
Write-Host " skill 目录 : $skillsDir" -ForegroundColor DarkGray
Write-Host " 指令文件   : $instrPath" -ForegroundColor DarkGray
Write-Host " 配置文件   : $cfgPath" -ForegroundColor DarkGray
if ($DryRun) { Write-Host ' [DRY RUN] 只预览，不实际写入' -ForegroundColor Yellow }
Write-Host '============================================================' -ForegroundColor Cyan

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $homeDir ".agent-deploy_backup_$ts"

# ---------- 4. 铺 skill ----------
if (-not $SkipSkills) {
  Write-Host ''
  Write-Host "[1/3] 铺 $($skills.Count) 个核心 skill" -ForegroundColor Yellow
  New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
  $ok = 0; $skip = 0; $fail = 0
  foreach ($s in $skills) {
    $dst = Join-Path $skillsDir $s.name
    if (Test-Path (Join-Path $dst 'SKILL.md')) { Write-Host "  [已存在] $($s.name)" -ForegroundColor DarkGray; $skip++; continue }
    $url = if ($Source -eq 'github') { "https://github.com/$owner/$($s.name).git" } else { "https://gitee.com/$owner/$($s.name).git" }
    if ($DryRun) { Write-Host "  [DRY] git clone --depth 1 $url -> $dst"; $ok++; continue }
    git clone --depth 1 $url $dst 2>&1 | Out-Null
    if (Test-Path (Join-Path $dst 'SKILL.md')) { Write-Host "  [OK] $($s.name)" -ForegroundColor Green; $ok++ }
    else { Write-Host "  [FAIL] $($s.name)" -ForegroundColor Red; $fail++ }
  }
  Write-Host "  结果: 安装 $ok / 已存在 $skip / 失败 $fail" -ForegroundColor Cyan
} else {
  Write-Host ''
  Write-Host '[1/3] 跳过 skill 铺放（-SkipSkills）' -ForegroundColor DarkGray
}

# ---------- 5 & 6. 铺铁律 + 生成配置 ----------
if (-not $SkipConfig) {
  Write-Host ''
  Write-Host '[2/3] 铺铁律' -ForegroundColor Yellow
  $instr = Get-Content (Join-Path $scriptRoot 'templates\agents-core.md') -Raw
  if ((Test-Path $instrPath) -and (-not $DryRun)) {
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    Copy-Item $instrPath (Join-Path $backupRoot (Split-Path $instrPath -Leaf)) -Force
    Write-Host "  备份旧指令 -> $backupRoot" -ForegroundColor DarkGray
  }
  if ($DryRun) { Write-Host "  [DRY] 写 $instrPath" }
  else {
    New-Item -ItemType Directory -Force -Path (Split-Path $instrPath) | Out-Null
    Set-Content -Path $instrPath -Value $instr -Encoding utf8
    Write-Host "  已写 $instrPath" -ForegroundColor Green
  }

  Write-Host ''
  Write-Host '[3/3] 生成中间商/模型配置' -ForegroundColor Yellow

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
    }
    if ($DryRun) { Write-Host "  [DRY] 写 $cfgPath" -ForegroundColor Yellow; Write-Host $cfgText }
    else {
      New-Item -ItemType Directory -Force -Path (Split-Path $cfgPath) | Out-Null
      Set-Content -Path $cfgPath -Value $cfgText -Encoding utf8
      Write-Host "  已写 $cfgPath" -ForegroundColor Green
    }
  }
} else {
  Write-Host ''
  Write-Host '[2/3][3/3] 跳过铁律 + 配置（-SkipConfig）' -ForegroundColor DarkGray
}

# ---------- 7. 框架耦合清单 ----------
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
Write-Host ' 换框架后请按 FRAMEWORK-COUPLING.md 核对轻/重耦合 skill。' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
