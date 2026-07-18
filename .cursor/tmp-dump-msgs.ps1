$ErrorActionPreference = 'Stop'
$baseUrl = 'http://localhost:5144'
$deviceJson = '{"deviceID":"BE2A.250530.026.F3","deviceName":"postman-test-device","deviceVersion":"16","appVersion":"2.113.0","platform":"android"}'
$body = "{`"username`":`"chattest_sara`",`"password`":`"Test@12345`",`"deviceInfo`":$deviceJson}"
$login = Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json' -Body $body
$token = $login.accessToken
$headers = @{ Authorization = "Bearer $token" }
$page = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/59/messages?pageSize=50" -Method GET -Headers $headers
$page | ConvertTo-Json -Depth 6 | Set-Content -Path 'd:\Elay_Backend-master\.cursor\tmp-messages59.json' -Encoding UTF8
Write-Output ("COUNT=" + @($page.messages).Count)
foreach ($m in @($page.messages)) {
  Write-Output ("ID=$($m.id); DEL=$($m.isDeleted); TEXT=$($m.text)")
}
