$ErrorActionPreference = 'Stop'
$baseUrl = 'http://localhost:5144'
$deviceJson = '{"deviceID":"BE2A.250530.026.F3","deviceName":"postman-test-device","deviceVersion":"16","appVersion":"2.113.0","platform":"android"}'
$body = "{`"username`":`"chattest_sara`",`"password`":`"Test@12345`",`"deviceInfo`":$deviceJson}"
$login = Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json' -Body $body
$token = [string]$login.accessToken
$headers = @{ Authorization = "Bearer $token" }
$page = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/59/messages?pageSize=50" -Method GET -Headers $headers
$tombstone = $false
$systemLog = $false
foreach ($m in @($page.messages)) {
  if (($m.id -eq 237) -and ($m.isDeleted -eq $true)) { $tombstone = $true }
  if ((-not $m.isDeleted) -and $m.text -and ($m.text -like '*Nima*')) { $systemLog = $true }
}
$pinned = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/59/pinned-messages" -Method GET -Headers $headers
$pinReload = (@($pinned | ForEach-Object { $_.id }) -contains 239)
Write-Output "TOMBSTONE=$tombstone"
Write-Output "SYSTEM_LOG=$systemLog"
Write-Output "PIN_RELOAD=$pinReload"
Write-Output ("OVERALL_PASS=" + (($tombstone) -and ($systemLog) -and ($pinReload)))
