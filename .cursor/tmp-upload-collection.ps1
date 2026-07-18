$batLine = Get-Content 'C:/Users/kasha/postman-mcp.bat' | Select-String 'set POSTMAN_API_KEY='
$key = $batLine.Line -replace 'set POSTMAN_API_KEY=',''
$body = [System.IO.File]::ReadAllText('d:\Elay_Backend-master\.cursor\chat-day12-upload-body.json')
$headers = @{ 'X-Api-Key' = $key; 'Content-Type' = 'application/json' }
$resp = Invoke-RestMethod -Uri 'https://api.getpostman.com/collections?workspace=8f8205b4-1f6e-4b7b-8b73-1397399bbabc' -Method POST -Headers $headers -Body $body
$resp | ConvertTo-Json -Depth 5
