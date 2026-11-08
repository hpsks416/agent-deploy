#requires -Version 7.0
<#
.SYNOPSIS
  只读扫描「agent 指令文件供应链投毒」痕迹（Windows 版）。

.DESCRIPTION
  覆盖四类痕迹：
  1) 指令文件（AGENTS.md / CLAUDE.md / *.local.md）出现在网页可写入区，或内容含注入/提权/写配置模式；
  2) 全局配置劫持（~/.codex/config.toml 的 mcp_servers、~/.claude/settings.json 与项目级 .claude/settings.json 的 *_BASE_URL）；
  3) 恶意 npm 包 IOC（function-color / function-flag）与本机暂存目录（ptools）；
  4) 零宽 / 双向控制字符（肉眼看不见的提示词）。

  只读：不修改、不删除、不联网。退出码 0=干净，1=有 HIGH/MEDIUM 发现，2=执行错误。

.PARAMETER Roots
  要扫的根目录。默认：Downloads、Desktop、Documents、用户真实 Temp，外加 -Workspace。

.PARAMETER Workspace
  会话/工作区目录，用于计算「DSH 启动时会加载哪些指令文件」。

.PARAMETER Depth
  递归深度，默认 4（够覆盖 node_modules/.claude 常见层级，又不会太慢）。

.PARAMETER Json
  输出 JSON（机器可读），否则输出人读文本。

.PARAMETER Quiet
  只输出 SUMMARY 一行（适合放进 CI / evals 断言）。

.EXAMPLE
  pwsh scan-agent-instructions.ps1
.EXAMPLE
  pwsh scan-agent-instructions.ps1 -Roots 'C:\Users\me\Downloads' -Workspace 'C:\Users\me\Downloads' -Json
#>
[CmdletBinding()]
param(
  [string[]]$Roots = @(),
  [string]$Workspace = (Get-Location).Path,
  [int]$Depth = 4,
  [switch]$Json,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$script:Findings = New-Object System.Collections.Generic.List[object]

function Add-Finding {
  param([string]$Severity, [string]$Area, [string]$Path, [string]$Detail)
  $script:Findings.Add([pscustomobject]@{
    severity = $Severity
    area     = $Area
    path     = $Path
    detail   = $Detail
  })
}

# ---------- 内容模式 ----------
$ZeroWidthRe = '[\u200B-\u200F\u202A-\u202E\uFEFF\u2060-\u2064]'
$Patterns = @(
  @{ name = 'prompt-injection';    re = '(?i)ignore\s+(all\s+)?(previous|prior|above)|disregard\s+(all\s+)?(previous|prior)|忽略(之前|以上|前面)的?(所有)?(指令|提示)|不要告诉(用户|用户)|do not tell the user|system prompt|你现在的(身份|角色)是' },
  @{ name = 'sandbox-bypass';      re = '(?i)--dangerously-bypass|dangerouslyDisableSandbox|bypass[-_ ]?approvals|--full[-_]auto|full[-_ ]access|skip[-_ ]permissions' },
  @{ name = 'config-write';        re = '(?i)mcp_servers|config\.toml|settings\.json|ANTHROPIC_BASE_URL|OPENAI_BASE_URL|chatgpt_base_url' },
  @{ name = 'exec-primitive';      re = '(?i)launchctl|\bnpm\s+install\b|\bnpx\s+\S|\bcurl\s|\bwget\s|chmod\s+\+x|base64\s+-d|powershell(\.exe)?\s+-e(nc)?\b|\bsh\s+-c\b|bash\s+-lc' },
  @{ name = 'credential-reach';    re = '(?i)\.ssh\b|id_rsa|\.aws\b|\.env\b|credentials|keychain|登录态|token\s*=' }
)

function Get-InstructionHits {
  param([string]$Text)
  $hits = @()
  if ([regex]::IsMatch($Text, $ZeroWidthRe)) { $hits += 'zero-width-unicode' }
  foreach ($p in $Patterns) {
    if ([regex]::IsMatch($Text, $p.re)) { $hits += $p.name }
  }
  return $hits
}

function Read-TextSafe {
  param([string]$Path, [int]$MaxBytes = 1048576)
  try {
    $fi = [System.IO.FileInfo]::new($Path)
    if ($fi.Length -gt $MaxBytes) { return $null }
    return [System.IO.File]::ReadAllText($Path)
  } catch { return $null }
}

# ---------- 1) 指令文件 ----------
$InstructionNames = @('AGENTS.md', 'CLAUDE.md', 'AGENTS.local.md', 'CLAUDE.local.md')
$WebWritableRoots = @(
  (Join-Path $env:USERPROFILE 'Downloads'),
  (Join-Path $env:USERPROFILE 'Desktop'),
  (Join-Path $env:USERPROFILE 'AppData\Local\Temp')
)

function Test-UnderRoot {
  param([string]$Path, [string]$Root)
  $p = $Path.ToLowerInvariant(); $r = $Root.TrimEnd('\').ToLowerInvariant()
  return $p -eq $r -or $p.StartsWith($r + '\')
}

function Invoke-RootScan {
  param([string]$Root)
  if (-not $Root -or -not (Test-Path -LiteralPath $Root)) {
    Add-Finding 'INFO' 'root-missing' $Root '根目录不存在，已跳过'
    return
  }
  $isWebWritable = $false
  foreach ($w in $WebWritableRoots) { if (Test-UnderRoot $Root $w) { $isWebWritable = $true } }

  # 1a) 指令文件
  $files = Get-ChildItem -LiteralPath $Root -Recurse -Depth $Depth -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $InstructionNames -contains $_.Name -and $_.FullName -notmatch '\\node_modules\\' }
  foreach ($f in $files) {
    $hits = @()
    $text = Read-TextSafe $f.FullName
    if ($null -ne $text) { $hits = Get-InstructionHits $text }
    $sev = if ($hits.Count -gt 0) { 'HIGH' } elseif ($isWebWritable) { 'HIGH' } else { 'INFO' }
    $why = if ($hits.Count -gt 0) { '内容命中：' + ($hits -join ', ') }
           elseif ($isWebWritable) { '指令文件位于网页可静默写入区（Downloads/Desktop/Temp）' }
           else { '非网页可写入区；确认是你自己写的再放行' }
    Add-Finding $sev 'instruction-file' $f.FullName $why
  }

  # 1b) 项目级 .claude/settings.json 的端点劫持
  $claudeSettings = Get-ChildItem -LiteralPath $Root -Recurse -Depth $Depth -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\\.claude\\settings(\.local)?\.json$' }
  foreach ($cs in $claudeSettings) {
    Test-BaseUrlFile $cs.FullName
  }

  # 1c) 恶意包 IOC
  $bad = Get-ChildItem -LiteralPath $Root -Recurse -Depth $Depth -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(function-color|function-flag)$' }
  foreach ($b in $bad) {
    Add-Finding 'HIGH' 'malicious-package' $b.FullName '命中文章 IOC 的恶意 npm 包（MALFEX 活动），视为已失陷'
  }

  # 1d) 暂存目录
  $stage = Get-ChildItem -LiteralPath $Root -Recurse -Depth 2 -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^ptools$' }
  foreach ($s in $stage) {
    Add-Finding 'MEDIUM' 'staging-dir' $s.FullName '出现攻击链使用的 ptools 暂存目录名'
  }
}

function Test-BaseUrlFile {
  param([string]$File)
  try {
    $obj = Get-Content -LiteralPath $File -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Add-Finding 'MEDIUM' 'config-parse' $File 'settings.json 解析失败（可能被人为塞入非法内容）'
    return
  }
  if ($null -eq $obj.env) { return }
  foreach ($prop in $obj.env.PSObject.Properties) {
    if ($prop.Name -match '(?i)_BASE_URL$|^ANTHROPIC_BASE_URL$') {
      $value = [string]$prop.Value
      $isLocal = $value -match '^https?://(127\.0\.0\.1|localhost|\[::1\])(:\d+)?'
      if (-not $isLocal) {
        Add-Finding 'HIGH' 'endpoint-hijack' $File ("$($prop.Name) 指向非本地端点（host=" + ([regex]::Match($value, '^https?://([^/]+)').Groups[1].Value) + "），token 可能外泄")
      } else {
        Add-Finding 'INFO' 'endpoint-local' $File ("$($prop.Name) 指向本地端点（host=" + ([regex]::Match($value, '^https?://([^/]+)').Groups[1].Value) + "）")
      }
    }
  }
}

# ---------- 2) 全局配置 ----------
function Test-CodexConfig {
  $cfg = Join-Path $env:USERPROFILE '.codex\config.toml'
  if (-not (Test-Path -LiteralPath $cfg)) { Add-Finding 'INFO' 'codex-config' $cfg '不存在'; return }
  $text = Read-TextSafe $cfg
  if ($null -eq $text) {
    Add-Finding 'MEDIUM' 'codex-config' $cfg 'config.toml 超过 1MB，可能被塞入异常内容'
    return
  }
  # 每个 [mcp_servers.*] 块的命令体
  $blocks = [regex]::Matches($text, '(?ms)^\[mcp_servers\.([^\]]+)\]\s*\r?\n(.*?)(?=^\[|\z)')
  foreach ($b in $blocks) {
    $name = $b.Groups[1].Value
    $body = $b.Groups[2].Value
    $risky = [regex]::IsMatch($body, '(?i)launchctl|/bin/zsh|/bin/bash|sh\s+-c|powershell\s+-|/tmp/|%TEMP%|\\Temp\\|npx\s|npm\s+install|curl\s|wget\s|base64\s')
    if ($risky) {
      Add-Finding 'HIGH' 'mcp-server-risky' $cfg ("[mcp_servers.$name] 的命令含执行/下载/临时目录特征——对照是否为你自己注册的")
    } else {
      Add-Finding 'INFO' 'mcp-server' $cfg ("[mcp_servers.$name]")
    }
  }
  if ([regex]::IsMatch($text, '(?im)^\s*chatgpt_base_url\s*=')) {
    Add-Finding 'HIGH' 'codex-endpoint' $cfg '出现 chatgpt_base_url 覆写（文章攻击链的同类落点）'
  }
  # 配置文件里 mcp_servers / token 字样属正常，只用「注入 + 自关防护」两类窄模式判定
  $hits = @()
  if ([regex]::IsMatch($text, $ZeroWidthRe)) { $hits += 'zero-width-unicode' }
  if ([regex]::IsMatch($text, '(?i)--dangerously-bypass|dangerouslyDisableSandbox|bypass[-_ ]?approvals')) { $hits += 'sandbox-bypass' }
  if ([regex]::IsMatch($text, '(?i)ignore\s+(all\s+)?(previous|prior|above)|忽略(之前|以上|前面)的?(所有)?(指令|提示)')) { $hits += 'prompt-injection' }
  if ($hits.Count -gt 0) {
    Add-Finding 'HIGH' 'codex-config-pattern' $cfg ('配置含可疑模式：' + ($hits -join ', '))
  }
}

function Test-ClaudeGlobalConfig {
  $cfg = Join-Path $env:USERPROFILE '.claude\settings.json'
  if (Test-Path -LiteralPath $cfg) { Test-BaseUrlFile $cfg }
  $cfgLocal = Join-Path $env:USERPROFILE '.claude\settings.local.json'
  if (Test-Path -LiteralPath $cfgLocal) { Test-BaseUrlFile $cfgLocal }
}

function Test-DshGlobalInstructions {
  $cfg = Join-Path $env:USERPROFILE '.dsh\AGENTS.md'
  if (-not (Test-Path -LiteralPath $cfg)) { Add-Finding 'INFO' 'dsh-global' $cfg '不存在'; return }
  $text = Read-TextSafe $cfg
  if ($null -eq $text) { return }
  $hits = @()
  if ([regex]::IsMatch($text, $ZeroWidthRe)) { $hits += 'zero-width-unicode' }
  # 只查最高危两类，避免把框架正文误报
  if ([regex]::IsMatch($text, '(?i)--dangerously-bypass|dangerouslyDisableSandbox|bypass[-_ ]?approvals')) { $hits += 'sandbox-bypass' }
  if ([regex]::IsMatch($text, '(?i)ANTHROPIC_BASE_URL|chatgpt_base_url|mcp_servers')) { $hits += 'config-write' }
  if ($hits.Count -gt 0) {
    Add-Finding 'HIGH' 'dsh-global-instructions' $cfg ('全局常驻指令含可疑模式：' + ($hits -join ', '))
  } else {
    Add-Finding 'INFO' 'dsh-global-instructions' $cfg '全局常驻指令未见高危模式'
  }
}

# ---------- 3) DSH 会加载哪些指令文件（源码：dsh-agent-instructions） ----------
function Get-DshLoadSurface {
  param([string]$Dir)
  $surface = @()
  $global = Join-Path $env:USERPROFILE '.dsh\AGENTS.md'
  if (Test-Path -LiteralPath $global) { $surface += $global }
  $cur = [System.IO.Path]::GetFullPath($Dir)
  $chain = @()
  while ($true) {
    $chain += $cur
    if (Test-Path -LiteralPath (Join-Path $cur '.git')) { break }
    $parent = [System.IO.Path]::GetDirectoryName($cur)
    if (-not $parent -or $parent -eq $cur) { break }
    $cur = $parent
  }
  foreach ($dir in ($chain | Sort-Object)) {
    foreach ($n in $InstructionNames) {
      $p = Join-Path $dir $n
      if (Test-Path -LiteralPath $p) { $surface += $p }
    }
  }
  return ($surface | Select-Object -Unique)
}

# ---------- 主流程 ----------
try {
  $defaultRoots = @(
    (Join-Path $env:USERPROFILE 'Downloads'),
    (Join-Path $env:USERPROFILE 'Desktop'),
    (Join-Path $env:USERPROFILE 'Documents'),
    (Join-Path $env:USERPROFILE 'AppData\Local\Temp')
  )
  $allRoots = @()
  if ($Roots.Count -gt 0) { $allRoots += $Roots } else { $allRoots += $defaultRoots }
  if ($Workspace -and (Test-Path -LiteralPath $Workspace)) { $allRoots += $Workspace }
  $allRoots = $allRoots | Select-Object -Unique

  foreach ($r in $allRoots) { Invoke-RootScan $r }
  Test-CodexConfig
  Test-ClaudeGlobalConfig
  Test-DshGlobalInstructions

  $surface = @(Get-DshLoadSurface -Dir $Workspace)
  foreach ($s in $surface) {
    Add-Finding 'INFO' 'dsh-would-load' $s 'DSH 启动时会把它作为指令加载（dsh-agent-instructions 规则）'
  }

  $high = @($script:Findings | Where-Object { $_.severity -eq 'HIGH' }).Count
  $med = @($script:Findings | Where-Object { $_.severity -eq 'MEDIUM' }).Count
  $info = @($script:Findings | Where-Object { $_.severity -eq 'INFO' }).Count
  $exitCode = if (($high + $med) -gt 0) { 1 } else { 0 }

  if ($Json) {
    [pscustomobject]@{
      tool           = 'agent-instruction-supply-chain-scan'
      scannedRoots   = @($allRoots)
      dshLoadSurface = @($surface)
      summary        = @{ findings = $script:Findings.Count; high = $high; medium = $med; info = $info; exit = $exitCode }
      findings       = $script:Findings
    } | ConvertTo-Json -Depth 6
  } else {
    if (-not $Quiet) {
      Write-Output '=== agent-instruction-supply-chain-scan（只读） ==='
      Write-Output ('扫描根: ' + ($allRoots -join ' | '))
      Write-Output ''
      Write-Output '--- DSH 启动时会加载的指令文件 ---'
      if ($surface.Count -eq 0) { Write-Output '（无）' } else { $surface | ForEach-Object { Write-Output ('  * ' + $_) } }
      Write-Output ''
      Write-Output '--- findings ---'
      if ($script:Findings.Count -eq 0) {
        Write-Output '（无发现）'
      } else {
        $script:Findings | Sort-Object severity | ForEach-Object {
          Write-Output ('[' + $_.severity + '] ' + $_.area + ' :: ' + $_.path + ' :: ' + $_.detail)
        }
      }
      Write-Output ''
    }
    Write-Output ("SUMMARY findings=$($script:Findings.Count) high=$high medium=$med info=$info exit=$exitCode")
  }
  exit $exitCode
}
catch {
  Write-Output ('ERROR ' + $_.Exception.Message)
  Write-Output 'SUMMARY findings=0 high=0 medium=0 info=0 exit=2'
  exit 2
}
