$ErrorActionPreference = 'Continue'
Stop-Process -Id 27368 -Force -ErrorAction SilentlyContinue
Stop-Process -Id 30904 -Force -ErrorAction SilentlyContinue
Get-NetTCPConnection -LocalPort 5144 -ErrorAction SilentlyContinue |
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
Write-Output 'cleaned'
