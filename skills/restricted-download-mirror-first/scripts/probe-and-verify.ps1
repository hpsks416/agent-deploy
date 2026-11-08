# probe-and-verify.ps1 — 官方源探测 + 下载物校验（确定性机械判定，不做止损决策）
# 用法：
#   -Url  <url>  [-RangeBytes 1024]                探测是否公开可下：状态码/长度/ETag=MD5/拦截页识别
#   -File <path> [-ExpectMd5 <md5>] [-ExpectSha256 <sha256>]   校验本地文件
# 退出码：0 正常 / 1 疑似被拦（命中拦截特征） / 2 校验不符 / 3 参数错误
param(
    [string]$Url,
    [string]$File,
    [long]$RangeBytes = 1024,
    [string]$ExpectMd5,
    [string]$ExpectSha256
)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'

function Out-Line([string]$k, $v) { "{0}={1}" -f $k, $v }

if ($Url) {
    $h = (curl.exe -sS -I -L --max-time 25 -A $ua $Url 2>&1) -join "`n"
    $code = ([regex]::Match($h, 'HTTP/[\d.]+ (\d{3})')).Groups[1].Value
    $len  = ([regex]::Match($h, '(?im)content-length:\s*(\d+)')).Groups[1].Value
    $ctype= ([regex]::Match($h, '(?im)content-type:\s*([^\r\n]+)')).Groups[1].Value.Trim()
    $etag = ([regex]::Match($h, '(?im)^etag:\s*"?([0-9a-fA-F]{32})"?')).Groups[1].Value
    Out-Line 'url' $Url
    Out-Line 'status' $code
    Out-Line 'content_length' $len
    Out-Line 'content_type' $ctype
    Out-Line 'etag_as_md5' $etag
    $suspicious = ($ctype -match 'text/html') -or ($len -and [int64]$len -lt 50000)
    Out-Line 'looks_like_block_page' $suspicious
    if ($suspicious) {
        "note=命中拦截特征（HTML 或非安装包大小），按 R3 计入同一次失败"
        exit 1
    }
    "note=匿名可探测；若实际下载仍在中途被重置，按 R3 计入失败"
    exit 0
}

if ($File) {
    if (-not (Test-Path $File)) { "error=文件不存在: $File"; exit 3 }
    $fi = Get-Item $File
    Out-Line 'file' $fi.FullName
    Out-Line 'size' $fi.Length
    $md5 = (Get-FileHash -Path $File -Algorithm MD5).Hash.ToLower()
    $sha = (Get-FileHash -Path $File -Algorithm SHA256).Hash.ToLower()
    Out-Line 'md5' $md5
    Out-Line 'sha256' $sha
    if ($fi.Extension -eq '.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        try {
            $z = [System.IO.Compression.ZipFile]::OpenRead($fi.FullName)
            Out-Line 'zip_entries' $z.Entries.Count
            $z.Dispose()
        } catch { "zip_error=$($_.Exception.Message)" }
    }
    $bad = 0
    if ($ExpectMd5)    { $ok = ($md5 -eq $ExpectMd5.ToLower());  Out-Line 'expect_md5_match' $ok;     if (-not $ok) { $bad = 1 } }
    if ($ExpectSha256) { $ok = ($sha -eq $ExpectSha256.ToLower()); Out-Line 'expect_sha256_match' $ok; if (-not $ok) { $bad = 1 } }
    if ($bad) { exit 2 }
    exit 0
}

"error=需要 -Url 或 -File"
exit 3
