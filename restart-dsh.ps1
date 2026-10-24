# Independent DSH web restart (robust):
#   1. kill whoever listens on 3080
#   2. poll until the port is TRULY free (avoid EADDRINUSE)
#   3. boot a fresh dsh web detached
#   4. poll until 3080 is bound again, else report failure
# Runs detached from the current session process tree via Start-Process.

function Get-Port3080Pid {
  $l = netstat -ano | Select-String "LISTENING" | Select-String ":3080\s"
  if ($l) {
    $portPid = ($l[0].ToString() -split '\s+')[-1]
    if ($portPid -match '^\d+$') { return [int]$portPid }
  }
  return $null
}

# 1. kill current 3080 owner
$old = Get-Port3080Pid
if ($old) {
  Stop-Process -Id $old -Force -ErrorAction SilentlyContinue
  Write-Output "killed PID $old on 3080"
}

# 2. poll until port is free (max 30s)
$waited = 0
while ($waited -lt 30) {
  Start-Sleep -Seconds 1
  $waited++
  if (-not (Get-Port3080Pid)) { break }
}
if (Get-Port3080Pid) {
  Write-Output "ERROR: port 3080 still occupied after ${waited}s, aborting"
  exit 1
}
Write-Output "port 3080 free after ${waited}s"

# 3. boot fresh dsh web (detached so this script can verify the bind)
Start-Process -FilePath "powershell.exe" -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
  "Set-Location 'C:\Users\Razer\.dsh\profiles\web'; & 'C:\Users\Razer\Documents\Codex\pnpm-global\bin\dsh.ps1' web"
) -WindowStyle Hidden

# 4. poll until 3080 is bound (max 40s)
$waited = 0
while ($waited -lt 40) {
  Start-Sleep -Seconds 1
  $waited++
  if (Get-Port3080Pid) {
    Write-Output "dsh web bound 3080 after ${waited}s (PID $(Get-Port3080Pid))"
    exit 0
  }
}
Write-Output "ERROR: dsh web failed to bind 3080 after ${waited}s"
exit 1
