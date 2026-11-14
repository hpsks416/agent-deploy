#!/usr/bin/env pwsh
# ============================================================================
# thirdparty-gate.ps1 —— 第三方 DSH 插件/技能「装前门禁」（带超时）
#
# 契约（SkillSpector v2.12.0，来自其 docs/DEVELOPMENT.md）：
#   exit 0 = 扫描完成且 risk_score <= 50；exit 1 = risk_score > 50；exit 2 = 出错
#   JSON：findings / filtered_findings / risk_score / risk_severity(LOW|MEDIUM|HIGH|CRITICAL)
#         / risk_recommendation(SAFE|CAUTION|DO_NOT_INSTALL) / analysis_completeness.is_complete
# Windows 注意：**不能传 --output**（平台不支持安全落盘），必须抓 stdout。
#
# 判定策略（实测校准）：
#   BLOCK：DO_NOT_INSTALL / HIGH|CRITICAL / exit 1 / 超时 / 扫描器缺失或出错 /（-StrictIncomplete 时）分析不完整
#   PASS ：其余（分析不完整默认只 WARN + 标注，因为「插件目录」不是 skill 目录，静态扫描天然不完整；
#          且 OSV 联网查询可能慢——用 -TimeoutSec 兜住）
#
# 用法：
#   pwsh thirdparty-gate.ps1 -Path <目录> [-TimeoutSec 300] [-StrictIncomplete] [-Json]
# 退出码：0=通过 / 3=拦截 / 4=扫描器缺失或出错
# ============================================================================
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$SkillSpector = 'G:\CodexDS\DSH\INTRO\SkillSpector\.venv\Scripts\skillspector.exe',
  [int]$TimeoutSec = 300,
  [switch]$StrictIncomplete,
  [switch]$Json
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Result($verdict, $exitCode, $detail) {
  if ($Json) {
    [pscustomobject]@{ path = $Path; verdict = $verdict; exitCode = $exitCode; detail = $detail } | ConvertTo-Json -Depth 4
  } else {
    $color = switch ($verdict) { 'PASS' { 'Green' } 'BLOCK' { 'Red' } default { 'Yellow' } }
    Write-Host ("[{0}] {1}" -f $verdict, $Path) -ForegroundColor $color
    Write-Host ("      {0}" -f $detail) -ForegroundColor DarkGray
  }
  exit $exitCode
}

if (-not (Test-Path $Path)) { Result 'ERROR' 4 "路径不存在: $Path" }
if (-not (Test-Path $SkillSpector)) { Result 'ERROR' 4 "缺 SkillSpector: $SkillSpector（fail-closed）" }

$guid = [guid]::NewGuid().ToString('N')
$tmpOut = Join-Path $env:TEMP "sp-scan-$guid.json"
$tmpErr = Join-Path $env:TEMP "sp-scan-$guid.err"
$proc = $null
try {
  $proc = Start-Process -FilePath $SkillSpector `
          -ArgumentList @('scan', $Path, '--no-llm', '--format', 'json') `
          -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr `
          -NoNewWindow -PassThru
  $finished = $proc.WaitForExit($TimeoutSec * 1000)
  if (-not $finished) {
    try { $proc.Kill($true) } catch { try { $proc.Kill() } catch {} }
    Result 'BLOCK' 3 "扫描超时（${TimeoutSec}s，多半卡在 OSV 联网查询）→ fail-closed；确认可信后可 -SkipSupplyChain，或调大 -TimeoutSec"
  }
  $code = $proc.ExitCode
} catch {
  Result 'ERROR' 4 "启动扫描器失败: $($_.Exception.Message)"
}

$raw = if (Test-Path $tmpOut) { Get-Content $tmpOut -Raw } else { '' }
$err = if (Test-Path $tmpErr) { (Get-Content $tmpErr -Raw) } else { '' }
$rep = $null
try { if ($raw.Trim()) { $rep = $raw | ConvertFrom-Json } } catch { $rep = $null }

if ($code -eq 2 -or -not $rep) {
  $e = ($err.Trim() -replace '\s+', ' ')
  Result 'ERROR' 4 ("扫描器退出码 $code；stderr: " + $e.Substring(0, [Math]::Min(200, $e.Length)))
}

$rec = $rep.risk_recommendation
$sev = $rep.risk_severity
$score = $rep.risk_score
$maxSev = $null
if ($rep.risk_assessment -and $rep.risk_assessment.max_issue_severity) { $maxSev = $rep.risk_assessment.max_issue_severity }
$complete = $null
if ($rep.analysis_completeness) { $complete = $rep.analysis_completeness.is_complete }
$findings = @($rep.findings)
$blockers = @($findings | Where-Object { $_.severity -in @('HIGH', 'CRITICAL') })

$detail = "score=$score sev=$sev rec=$rec maxIssue=$maxSev findings=$($findings.Count) high/critical=$($blockers.Count) complete=$complete"

if ($rec -eq 'DO_NOT_INSTALL') { Result 'BLOCK' 3 "推荐 DO_NOT_INSTALL — $detail" }
if ($sev -in @('HIGH', 'CRITICAL') -or $maxSev -in @('HIGH', 'CRITICAL')) { Result 'BLOCK' 3 "最高严重度 HIGH/CRITICAL — $detail" }
if ($code -eq 1) { Result 'BLOCK' 3 "risk_score > 50（exit 1）— $detail" }
if ($complete -eq $false) {
  if ($StrictIncomplete) { Result 'BLOCK' 3 "分析不完整（-StrictIncomplete）— $detail" }
  Write-Host "      ! 分析不完整（插件目录不是 skill 目录，静态覆盖天然不全；未发现 HIGH/CRITICAL）" -ForegroundColor DarkYellow
}
Result 'PASS' 0 "通过 — $detail"
