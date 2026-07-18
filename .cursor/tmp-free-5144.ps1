$conns = Get-NetTCPConnection -LocalPort 5144 -ErrorAction SilentlyContinue
foreach ($c in $conns) {
  $procId = $c.OwningProcess
  Write-Output "Killing PID $procId"
  Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2
$left = Get-NetTCPConnection -LocalPort 5144 -ErrorAction SilentlyContinue
if ($left) { Write-Output 'STILL_IN_USE' } else { Write-Output 'PORT_FREE' }
