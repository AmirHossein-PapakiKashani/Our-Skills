$ErrorActionPreference = 'Stop'
$openapi = Invoke-RestMethod -Uri 'http://localhost:5144/openapi/v1.json' -TimeoutSec 15
$openapi.paths.PSObject.Properties.Name | Where-Object { $_ -match 'pin|Pin|group|message' } | Sort-Object
