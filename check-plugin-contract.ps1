#!/usr/bin/env pwsh
# ============================================================================
# check-plugin-contract.ps1 —— DSH 插件契约合规检查（只读，可进 CI）
#
# 依据（2026-11-10 实测）：
#   - `dsh plugin` 是把余下参数转发给 profile 目录里的 pnpm（= pnpm add/remove/install）
#   - 插件包形态：type=module + main/exports → lib/index.js
#   - 注册方式：package.json 的 `dsh.bundle.patch` → cordis.patch.yml，里面是 `- insert:` 条目
#   - 版本声明：`engines.dsh` 或 `dsh.compatibility.dsh`（+ dshReleases 映射）；
#     也有插件把版本写在 `dsh.engines.dsh`（非标准位置，仅提示）
#   - 客户端插件：有 lib/client.js 时需要 `dsh.client.inject` + `dsh.client.platform`
#
# 用法：
#   pwsh check-plugin-contract.ps1                     # 按 web profile 检查
#   pwsh check-plugin-contract.ps1 -Profile desktop
#   pwsh check-plugin-contract.ps1 -Json               # 机器可读
# 退出码：0=无 FAIL；1=有 FAIL
# ============================================================================
param(
  [string]$Repo = $PSScriptRoot,
  [ValidateSet('web', 'desktop')]
  [string]$Profile = 'web',
  [switch]$Json
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# 允许把脚本放在仓库根或 tools/ 下：向上找含 framework-manifest.json 的目录
if (-not (Test-Path (Join-Path $Repo 'framework-manifest.json'))) {
  $probe = $PSScriptRoot
  for ($i = 0; $i -lt 3 -and $probe; $i++) {
    if (Test-Path (Join-Path $probe 'framework-manifest.json')) { $Repo = $probe; break }
    $probe = Split-Path -Parent $probe
  }
}

$manifestPath = Join-Path $Repo 'framework-manifest.json'
$manifest = $null
if (Test-Path $manifestPath) { $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json }

$dshBase = $null
if ($manifest -and $manifest.tracks.plugins.profiles -and $manifest.tracks.plugins.profiles.$Profile) {
  $dshBase = $manifest.tracks.plugins.profiles.$Profile.dshBase
}

$results = @()
$pluginRoot = Join-Path $Repo 'dsh-config'
$dirs = @(Get-ChildItem $pluginRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'profile-web' })

function Note($list, $level, $msg) { $list.Add([pscustomobject]@{ level = $level; msg = $msg }) | Out-Null }
function DeclaredBase([string]$range) {
  if (-not $range) { return $null }
  $r = $range.Trim()
  $r = $r -replace '^(\^|~|>=|<=|>|<|=)\s*', ''
  if ($r -match '^([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.\-]+)?)') { return $Matches[1] }
  return $r
}
function VerParts([string]$v) {
  if (-not $v) { return $null }
  if ($v -match '^([0-9]+)\.([0-9]+)\.([0-9]+)(?:-([0-9A-Za-z.\-]+))?') {
    return [pscustomobject]@{ major = [int]$Matches[1]; minor = [int]$Matches[2]; patch = [int]$Matches[3]; pre = $Matches[4] }
  }
  return $null
}
# 判断声明的版本范围是否覆盖 profile 版本：
#   >=X  → profile 的 (major,minor,patch) ≥ X 即覆盖（忽略 prerelease 差异，仅告警级）
#   ^X / ~X / =X → 基线相同才算一致
function RangeCovers([string]$range, [string]$profileVer) {
  if (-not $range -or -not $profileVer) { return $true }
  $op = 'eq'
  if ($range -match '^\s*>=') { $op = 'ge' }
  $rb = DeclaredBase $range; $pv = VerParts $profileVer; $rv = VerParts $rb
  if (-not $pv -or -not $rv) { return $true }
  if ($op -eq 'ge') {
    if ($pv.major -ne $rv.major) { return $pv.major -gt $rv.major }
    if ($pv.minor -ne $rv.minor) { return $pv.minor -gt $rv.minor }
    return $pv.patch -ge $rv.patch
  }
  return ($pv.major -eq $rv.major -and $pv.minor -eq $rv.minor -and $pv.patch -eq $rv.patch)
}

foreach ($d in $dirs) {
  $issues = New-Object System.Collections.ArrayList
  $pj = Join-Path $d.FullName 'package.json'
  if (-not (Test-Path $pj)) { Note $issues 'FAIL' '缺 package.json'; }
  $j = $null
  if (Test-Path $pj) {
    try { $j = Get-Content $pj -Raw | ConvertFrom-Json } catch { Note $issues 'FAIL' "package.json 解析失败: $($_.Exception.Message)" }
  }
  $name = if ($j) { $j.name } else { $d.Name }

  if ($j) {
    foreach ($f in @('name', 'version')) { if (-not $j.$f) { Note $issues 'FAIL' "缺 $f" } }
    if ($j.type -ne 'module') { Note $issues 'WARN' "type=$($j.type)（DSH 插件惯例是 module）" }
    $mainEntry = if ($j.main) { $j.main } elseif ($j.exports -and $j.exports.'.') { $j.exports.'.' } else { $null }
    if (-not $mainEntry) { Note $issues 'FAIL' '缺 main/exports[''.'']' }
    elseif (-not (Test-Path (Join-Path $d.FullName $mainEntry))) { Note $issues 'FAIL' "入口文件不存在: $mainEntry" }

    # 注册：dsh.bundle.patch
    $patchRel = $null
    if ($j.dsh -and $j.dsh.bundle -and $j.dsh.bundle.patch) { $patchRel = $j.dsh.bundle.patch }
    if (-not $patchRel) { Note $issues 'FAIL' '缺 dsh.bundle.patch（无法注册进 profile bundles）' }
    else {
      $patchPath = Join-Path $d.FullName $patchRel.TrimStart('.', '/', '\')
      if (-not (Test-Path $patchPath)) { Note $issues 'FAIL' "dsh.bundle.patch 指向的文件不存在: $patchRel" }
      else {
        $txt = Get-Content $patchPath -Raw
        if ($txt -notmatch 'insert:') { Note $issues 'WARN' 'cordis.patch.yml 里没有 insert 条目（只有覆盖/禁用？）' }
      }
    }

    # files 是否包含 patch（npm 打包别漏）
    if ($j.files) {
      $files = @($j.files)
      $hasPatch = $files -contains 'cordis.patch.yml'
      if (-not $hasPatch) { Note $issues 'WARN' 'files 未包含 cordis.patch.yml（npm 打包会漏）' }
    } else { Note $issues 'WARN' '缺 files 字段（npm 打包范围不明确）' }

    # 版本声明
    $eng = $null; $compat = $null; $dshEng = $null
    if ($j.engines -and $j.engines.dsh) { $eng = $j.engines.dsh }
    if ($j.dsh -and $j.dsh.compatibility -and $j.dsh.compatibility.dsh) { $compat = $j.dsh.compatibility.dsh }
    if ($j.dsh -and $j.dsh.engines -and $j.dsh.engines.dsh) { $dshEng = $j.dsh.engines.dsh }
    if (-not ($eng -or $compat -or $dshEng)) { Note $issues 'FAIL' '没有任何 DSH 版本声明（engines.dsh / dsh.compatibility.dsh）' }
    if ($dshEng -and -not $eng) { Note $issues 'WARN' '版本写在 dsh.engines（非标准位置），建议提到顶层 engines.dsh' }

    $declared = if ($eng) { $eng } elseif ($compat) { $compat } else { $dshEng }
    if ($declared -and $dshBase) {
      if (-not (RangeCovers $declared $dshBase)) {
        Note $issues 'WARN' "声明 $declared 不覆盖 profile=$Profile 的 $dshBase（跨 profile 需确认）"
      }
    }

    # 客户端插件
    $hasClient = Test-Path (Join-Path $d.FullName 'lib\client.js')
    if ($hasClient -and -not ($j.dsh -and $j.dsh.client -and $j.dsh.client.inject)) {
      Note $issues 'WARN' '有 lib/client.js 但缺 dsh.client.inject'
    }

    # 分发元数据
    if (-not $j.license) { Note $issues 'WARN' '缺 license 字段' }
    if (-not $j.description) { Note $issues 'WARN' '缺 description' }

    # 与 manifest 一致性
    if ($manifest) {
      $mit = @($manifest.items | Where-Object { $_.kind -eq 'plugin' -and $_.id -eq $j.name })
      if ($mit.Count -eq 0) { Note $issues 'WARN' "manifest 里没有这个插件（id=$($j.name)）" }
      elseif ($mit[0].version -ne $j.version) { Note $issues 'FAIL' "manifest 版本 $($mit[0].version) ≠ package.json $($j.version)" }
      if ($mit.Count -gt 0 -and $mit[0].profiles -and -not ($mit[0].profiles -contains $Profile)) {
        Note $issues 'WARN' "manifest 标注 profiles=$($mit[0].profiles -join ','), 不含 $Profile"
      }
    }
  }

  $worst = 'PASS'
  if ($issues | Where-Object { $_.level -eq 'FAIL' }) { $worst = 'FAIL' }
  elseif ($issues | Where-Object { $_.level -eq 'WARN' }) { $worst = 'WARN' }
  $results += [pscustomobject]@{
    plugin = $name; dir = $d.Name; verdict = $worst
    issues = @($issues | ForEach-Object { "[$($_.level)] $($_.msg)" })
  }
}

if ($Json) {
  $results | ConvertTo-Json -Depth 5
} else {
  Write-Host ''
  Write-Host "DSH 插件契约检查（profile=$Profile, dshBase=$(if($dshBase){$dshBase}else{'未知'})）" -ForegroundColor Cyan
  Write-Host ('-' * 78) -ForegroundColor DarkGray
  foreach ($r in $results) {
    $color = switch ($r.verdict) { 'PASS' { 'Green' } 'WARN' { 'Yellow' } default { 'Red' } }
    Write-Host ("{0,-28} {1,-6}" -f $r.plugin, $r.verdict) -ForegroundColor $color -NoNewline
    if ($r.issues.Count -eq 0) { Write-Host '（全部通过）' -ForegroundColor DarkGray }
    else { Write-Host ''; foreach ($i in $r.issues) { Write-Host "    $i" -ForegroundColor DarkGray } }
  }
  Write-Host ('-' * 78) -ForegroundColor DarkGray
  $p = @($results | Where-Object verdict -eq 'PASS').Count
  $w = @($results | Where-Object verdict -eq 'WARN').Count
  $f = @($results | Where-Object verdict -eq 'FAIL').Count
  Write-Host "SUMMARY: $($results.Count) 个插件 | PASS $p | WARN $w | FAIL $f" -ForegroundColor Cyan
}

if (@($results | Where-Object verdict -eq 'FAIL').Count -gt 0) { exit 1 } else { exit 0 }
