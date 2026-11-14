<#
sync_framework.ps1 — DSH 框架收口套件（单脚本多动作）

用法：
  pwsh sync_framework.ps1                    # = -Action all：部署 AGENTS.md + 补齐缺失 skill 到 live、重建 KB、回填 HANDOFF 数字、打印状态
  pwsh sync_framework.ps1 -Action check      # 只读体检：环境 / live↔repo 差异 / 清单一致性 / CI 静态体检 / KB 数字
  pwsh sync_framework.ps1 -Action skills     # 只报告 live↔repo 的 skill 内容差异（默认）；配 -Direction 才动手
  pwsh sync_framework.ps1 -Action skills -Direction repo2live   # 仓库 -> live（仓库版较新时）
  pwsh sync_framework.ps1 -Action skills -Direction live2repo   # live -> 仓库（live 较新时）
  pwsh sync_framework.ps1 -Action kb         # 重建 KB + 回填 HANDOFF/README 数字 + 复制库到 agent-deployed
  pwsh sync_framework.ps1 -Action push       # 三目标推送（GitHub/Gitee/GitCode；token 运行时解密、免代理）+ 推后校验
  pwsh sync_framework.ps1 -Action all -Push  # 收口全套 + 推送

约定 / 坑：
  - 方向不能靠 mtime 猜：live 与仓库会双向漂移，必须逐文件内容比对（本脚本按行尾归一化比对）。
  - git core.autocrlf=true 时，复制后 git status 会先报一堆 M，看 git diff --stat 才是真实变更。
  - kb / push / skills 需要 danger-full-access（写 ~/.dsh、sqlite unlink、读 G:\KEY 密文）。
  - token 只在本进程内解密进变量，不落盘、不打印；推送失败会打印 git 的错误行（不含 token）。
#>
param(
  [ValidateSet('all', 'check', 'skills', 'kb', 'push')][string]$Action = 'all',
  [ValidateSet('report', 'live2repo', 'repo2live')][string]$Direction = 'report',
  [switch]$SkipStaticCheck,
  [switch]$Push
)

$ErrorActionPreference = 'Continue'
$Repo       = 'G:\CodexDS\DSH\INTRO\agent-deploy'
$Live       = "$env:USERPROFILE\.dsh\skills"
$LiveAgents = "$env:USERPROFILE\.dsh\AGENTS.md"
$Hashrap    = 'G:\CodexDS\DSH\INTRO\HASHRAP'
$KbRepo     = 'G:\CodexDS\DSH\INTRO\framework-kb'
$Handoff    = 'G:\CodexDS\DSH\INTRO\agent-deploy\HANDOFF.md'
$Py         = 'C:\Users\Razer\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
$BuildKb    = "$Hashrap\build_kb.py"
$Dec        = 'G:\CodexDS\DSH\INTRO\secrets-link\decrypt-runtime.py'
$Age        = 'G:\CodexDS\DSH\INTRO\age\age\age.exe'
$Ident      = "$env:USERPROFILE\.dsh\age-identity.txt"

$PushRepos = @(
  @{ Path = $Repo;    Name = 'agent-deploy';   Branch = 'main' },
  @{ Path = $KbRepo;  Name = 'agent-deployed'; Branch = 'master' },
  @{ Path = $Hashrap; Name = 'HASHRAP';        Branch = 'master' }
)
$PushTargets = @(
  @{ Name = 'GitHub';  Url = 'https://github.com/hpsks416/{0}.git';     User = 'hpsks416';     Zip = 'G:\KEY\GITHUB token\416.txt.zip' },
  @{ Name = 'Gitee';   Url = 'https://gitee.com/hpsks416/{0}.git';      User = 'hpsks416';     Zip = 'G:\KEY\GITEE token\416.txt.zip' },
  @{ Name = 'GitCode'; Url = 'https://gitcode.com/qq_60289026/{0}.git'; User = 'qq_60289026';  Zip = 'G:\KEY\ATOMGIT token\416.txt.zip' }
)
$ExcludeFiles = @('*.pyc', '*.bak', '*.bak-*', '*.tmp', '*.orig', '*.old', '*.log', '*.swp')
$ExcludeDirs = @('__pycache__', '.venv', 'node_modules', '.git', 'models')

function Say($m) { Write-Host ">> $m" }
function Nrm($p) {
  $s = [System.IO.File]::ReadAllText($p) -replace "`r`n", "`n"
  $sha = [System.Security.Cryptography.SHA256]::Create()
  (($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))) | ForEach-Object { $_.ToString('x2') }) -join ''
}
function Get-Manifest {
  Get-Content "$Repo\core-skills.txt" | Where-Object { $_ -match '\|' -and -not $_.TrimStart().StartsWith('#') } | ForEach-Object { (($_ -split '\|')[0]).Trim() }
}

# ---------------- check ----------------
function Invoke-Check {
  Say '=== 1. 环境 ==='
  $proxy = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -in 7890, 7897 } | Select-Object -First 1
  Say ("代理 127.0.0.1:7897 监听: " + [bool]$proxy + "（GitHub 直连可用时不需要代理；当前脚本不加代理）")
  Say ("git global sslBackend: " + (git config --global --get http.sslbackend))
  Say ("git global autocrlf: " + (git config --global --get core.autocrlf) + "  # true 时注意 status 的假变更")
  Say ("python 存在: " + (Test-Path $Py) + " | 解密器: " + (Test-Path $Dec) + " | age: " + (Test-Path $Age))

  Say '=== 2. live <-> repo 差异 ==='
  $diffs = Get-SkillDiffs
  Say ("差异文件数: " + $diffs.Count)
  $diffs | Select-Object -First 20 | ForEach-Object { Say "  $_" }

  Say '=== 3. 清单一致性 ==='
  $manifest = @(Get-Manifest)
  $liveNames = @(Get-ChildItem $Live -Directory | ForEach-Object { $_.Name } | Sort-Object)
  $repoNames = @(Get-ChildItem "$Repo\skills" -Directory | ForEach-Object { $_.Name } | Sort-Object)
  Say ("manifest=" + $manifest.Count + " live=" + $liveNames.Count + " repo=" + $repoNames.Count +
       " | live 缺清单项: " + (@($manifest | Where-Object { $_ -notin $liveNames }) -join ',') +
       " | 清单外 live: " + (@($liveNames | Where-Object { $_ -notin $manifest }) -join ','))
  Say ("AGENTS.md 一致: " + ((Nrm $LiveAgents) -eq (Nrm "$Repo\dsh-config\AGENTS.md")))

  if (-not $SkipStaticCheck) {
    $skillN = (Get-ChildItem "$Repo\skills" -Directory).Count
  Say "=== 4. CI 静态体检（$skillN skill） ==="
    $fails = @()
    foreach ($d in (Get-ChildItem "$Repo\skills" -Directory)) {
      $out = ((& $Py "$Repo\skills\skill-evaluator\scripts\static_check.py" --skill $d.FullName 2>&1) -join "`n")
      try { $o = $out | ConvertFrom-Json } catch { $fails += "$($d.Name): JSON 解析失败"; continue }
      $bad = @($o.checks | Where-Object { $_.result -eq 'fail' })
      if ($bad.Count -gt 0) { $fails += "$($d.Name): $(($bad | ForEach-Object { $_.check }) -join ',')" }
    }
    Say ("静态体检 fail: " + $fails.Count)
    $fails | ForEach-Object { Say "  FAIL $_" }
  }

  Say '=== 5. 知识库 ==='
  $db = "$KbRepo\framework_kb.sqlite3"
  if (Test-Path $db) {
    $c = (& $Py -c "import sqlite3,sys;d=sqlite3.connect(r'$db');print(d.execute('SELECT COUNT(*) FROM chunks').fetchone()[0]);print(d.execute('SELECT COUNT(DISTINCT source) FROM chunks').fetchone()[0])" 2>&1) -join ','
    Say ("DB chunks,sources = " + $c + " | 文件 " + (Get-Item $db).Length + " B | 被 git 跟踪: " + [bool](git -C $KbRepo ls-files framework_kb.sqlite3))
  } else { Say "DB 不存在: $db" }
  Say ("HANDOFF: " + ((Get-Content $Handoff -Raw) -split "`n" | Where-Object { $_ -match 'KB chunks' }) -join '')

  Say '=== 6. 各仓库状态 ==='
  foreach ($r in $PushRepos) {
    Say ("$($r.Name): HEAD=" + (git -C $r.Path rev-parse --short HEAD) + " branch=" + (git -C $r.Path rev-parse --abbrev-ref HEAD) + " dirty=" + (git -C $r.Path status --porcelain=v1).Count)
  }
}

# ---------------- live <-> repo 差异 ----------------
function Get-SkillDiffs {
  $out = @()
  foreach ($nm in (Get-ChildItem $Live -Directory | ForEach-Object { $_.Name })) {
    $lp = Join-Path $Live $nm
    $rp = Join-Path "$Repo\skills" $nm
    if (-not (Test-Path $rp)) { $out += "live-only: $nm"; continue }
    foreach ($f in (Get-ChildItem $lp -Recurse -File | Where-Object { $_.Name -notmatch '\.pyc$' -and $_.FullName -notmatch '__pycache__' -and $_.Name -notmatch '\.bak' })) {
      $rel = $f.FullName.Substring($lp.Length + 1)
      $rf = Join-Path $rp $rel
      if (-not (Test-Path $rf)) { $out += "live-only: $nm/$rel" }
      elseif ((Nrm $f.FullName) -ne (Nrm $rf)) { $out += "diff: $nm/$rel" }
    }
  }
  foreach ($nm in (Get-ChildItem "$Repo\skills" -Directory | ForEach-Object { $_.Name })) {
    $rp = Join-Path "$Repo\skills" $nm
    $lp = Join-Path $Live $nm
    if (-not (Test-Path $lp)) { $out += "repo-only: $nm"; continue }
    foreach ($f in (Get-ChildItem $rp -Recurse -File | Where-Object { $_.Name -notmatch '\.pyc$' -and $_.FullName -notmatch '__pycache__' })) {
      $rel = $f.FullName.Substring($rp.Length + 1)
      if (-not (Test-Path (Join-Path $lp $rel))) { $out += "repo-only: $nm/$rel" }
    }
  }
  return $out
}

# ---------------- skills：双向归一 ----------------
function Invoke-Skills {
  $diffs = Get-SkillDiffs
  Say ("当前差异: " + $diffs.Count)
  $diffs | Select-Object -First 30 | ForEach-Object { Say "  $_" }
  if ($Direction -eq 'report') {
    Say '仅报告。要动手加 -Direction repo2live（仓库版较新）或 -Direction live2repo（live 较新）。'
    return
  }
  if ($Direction -eq 'repo2live') {
    foreach ($nm in @(Get-Manifest)) {
      $src = Join-Path "$Repo\skills" $nm
      if (-not (Test-Path $src)) { Say "  [跳过] 仓库无 $nm"; continue }
      robocopy $src (Join-Path $Live $nm) /E /NFL /NDL /NJH /NJS /NP /XF $ExcludeFiles /XD $ExcludeDirs | Out-Null
    }
    Copy-Item "$Repo\dsh-config\AGENTS.md" $LiveAgents -Force
    Say 'repo -> live 完成（按 core-skills.txt 清单）'
  }
  else {
    foreach ($d in (Get-ChildItem $Live -Directory)) {
      robocopy $d.FullName (Join-Path "$Repo\skills" $d.Name) /E /NFL /NDL /NJH /NJS /NP /XF $ExcludeFiles /XD $ExcludeDirs | Out-Null
    }
    Say 'live -> repo 完成（全部 live skill）'
  }
  Say ("操作后差异: " + (Get-SkillDiffs).Count)
}

# ---------------- kb：重建 + 回填数字 ----------------
function Invoke-Kb {
  Push-Location $Hashrap
  $chunks = -1; $sources = -1
  for ($i = 1; $i -le 8; $i++) {
    $json = (& $Py $BuildKb --lexical-only 2>$null) | Select-Object -Last 1
    $o = $json | ConvertFrom-Json
    $chunks = $o.chunks; $sources = $o.sources
    $txt = Get-Content $Handoff -Raw
    $m1 = [regex]::Match($txt, 'KB chunks:\s*(\d+)'); $m2 = [regex]::Match($txt, '源:\s*(\d+)')
    $s1 = if ($m1.Success) { [int]$m1.Groups[1].Value } else { -1 }
    $s2 = if ($m2.Success) { [int]$m2.Groups[1].Value } else { -1 }
    Say ("KB build #$i -> chunks=$chunks sources=$sources（HANDOFF 现值 $s1/$s2）")
    if ($s1 -eq $chunks -and $s2 -eq $sources) { break }
    $txt = [regex]::Replace($txt, 'KB chunks:\s*\d+', "KB chunks: $chunks")
    $txt = [regex]::Replace($txt, '源:\s*\d+', "源: $sources")
    $txt = $txt.Replace('{{KBCHUNKS}}', "$chunks").Replace('{{KBSOURCES}}', "$sources")
    Set-Content $Handoff $txt -NoNewline -Encoding utf8
  }
  Pop-Location
  Copy-Item "$Hashrap\framework_kb.sqlite3" "$KbRepo\framework_kb.sqlite3" -Force
  $rd = "$KbRepo\README.md"
  if (Test-Path $rd) {
    $r = Get-Content $rd -Raw
    $r = [regex]::Replace($r, '源文档\s*\d+\s*个、chunks\s*\d+\s*个', "源文档 $sources 个、chunks $chunks 个")
    Set-Content $rd $r -NoNewline -Encoding utf8
  }
  Say ("KB 完成: chunks=$chunks sources=$sources | 库 " + (Get-Item "$KbRepo\framework_kb.sqlite3").Length + " B")
  return @{ chunks = $chunks; sources = $sources }
}

# ---------------- push：三目标 ----------------
function Invoke-Push {
  $env:GIT_TERMINAL_PROMPT = '0'
  function DecryptToken($zip) {
    $t = ((& $Py $Dec $zip $Age $Ident 2>$null) -join '').Trim()
    if (-not $t) { throw "解密失败: $zip" }
    return $t
  }
  function B64($u, $t) { [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${u}:${t}")) }

  $tokens = @{}
  foreach ($t in $PushTargets) { $tokens[$t.Name] = DecryptToken $t.Zip }
  Say ("token 已解密: " + (($PushTargets | ForEach-Object { "$($_.Name)=$($tokens[$_.Name].Length)" }) -join ' '))

  $fails = 0
  foreach ($r in $PushRepos) {
    $local = (git -C $r.Path rev-parse --short HEAD)
    foreach ($t in $PushTargets) {
      $url = $t.Url -f $r.Name
      $hdr = 'http.extraheader=Authorization: Basic ' + (B64 $t.User $tokens[$t.Name])
      $out = git -C $r.Path -c http.sslBackend=openssl -c $hdr push $url $r.Branch 2>&1
      $code = $LASTEXITCODE
      if ($code -ne 0) { $fails++ }
      $detail = ($out | Where-Object { $_ -match '->|error|fatal|rejected|remote:' } | Select-Object -Last 2) -join ' / '
      Say ("$($r.Name) [$($r.Branch) $local] -> $($t.Name): " + $(if ($code -eq 0) { 'OK' } else { "FAIL($code)" }) + "  $detail")
    }
  }
  Say '=== 推后校验 ==='
  foreach ($r in $PushRepos) {
    $local = (git -C $r.Path rev-parse HEAD)
    foreach ($t in $PushTargets) {
      $rem = (git ls-remote ($t.Url -f $r.Name) ("refs/heads/" + $r.Branch) 2>$null | ForEach-Object { ($_ -split "\s+")[0] } | Select-Object -First 1)
      Say ("$($r.Name) @ $($t.Name): " + $(if ($rem -eq $local) { 'MATCH' } else { 'MISMATCH' }))
    }
  }
  Say ("失败目标数: $fails")
}

# ---------------- all：收口三件套 ----------------
function Invoke-All {
  Say '=== [1/3] 部署：AGENTS.md + 缺失 skill -> live ==='
  Copy-Item "$Repo\dsh-config\AGENTS.md" $LiveAgents -Force
  $manifest = @(Get-Manifest)
  foreach ($nm in $manifest) {
    $src = Join-Path "$Repo\skills" $nm
    $dst = Join-Path $Live $nm
    if (-not (Test-Path $src)) { Say "  [跳过] 仓库无 $nm"; continue }
    if (Test-Path (Join-Path $dst 'SKILL.md')) { continue }
    robocopy $src $dst /E /NFL /NDL /NJH /NJS /NP /XF $ExcludeFiles /XD $ExcludeDirs | Out-Null
    Say "  [补齐] $nm"
  }
  Say '  AGENTS.md 已部署（已有 skill 不覆盖：方向问题走 -Action skills）'

  Say '=== [2/3] 重建 deployed 知识库 ==='
  $kb = Invoke-Kb

  Say '=== [3/3] 状态 ==='
  Say ("skill 数: " + (Get-ChildItem "$Repo\skills" -Directory).Count + " | live: " + (Get-ChildItem $Live -Directory).Count + " | manifest: " + $manifest.Count)
  Say ("KB chunks: " + $kb.chunks + " | sources: " + $kb.sources)
  Say ("diff(live vs repo): " + (Get-SkillDiffs).Count)
  Say '-> 把「已完成 / 待办」写进 HANDOFF.md 第一节；脚本只同步可检测状态。'
  Say '-> 要发布：git commit 后在三个仓库跑 -Action push。'
}

switch ($Action) {
  'check'  { Invoke-Check }
  'skills' { Invoke-Skills }
  'kb'     { Invoke-Kb | Out-Null }
  'push'   { Invoke-Push }
  'all'    {
    Invoke-All
    if ($Push) { Invoke-Push }
  }
}
