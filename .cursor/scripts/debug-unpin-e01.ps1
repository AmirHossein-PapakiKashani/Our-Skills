[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8
$baseUrl = "http://localhost:5144"
function Login($u) {
    $b = @{ username=$u; password="Test@12345"; deviceInfo=@{deviceID="t";deviceName="t";deviceVersion="16";appVersion="2.113.0";platform="android"} } | ConvertTo-Json -Depth 3
    return (Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType "application/json" -Body $b).accessToken
}
$t1 = Login "chattest_sara"
$t2 = Login "chattest_reza"
$h1 = @{ Authorization = "Bearer $t1" }
$h2 = @{ Authorization = "Bearer $t2" }
$pv = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/pv/2747" -Method POST -Headers $h1
$msg = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$($pv.id)/messages" -Method POST -Headers $h1 -Form @{ text = "unpin test2" }
Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$($pv.id)/messages/$($msg.id)/pin" -Method POST -Headers $h1 | Out-Null
$r1 = Invoke-WebRequest -Uri "$baseUrl/chat/conversations/$($pv.id)/messages/$($msg.id)/pin" -Method DELETE -Headers $h2 -SkipHttpErrorCheck
$r2 = Invoke-WebRequest -Uri "$baseUrl/chat/conversations/$($pv.id)/messages/$($msg.id)/pin" -Method DELETE -Headers $h1 -SkipHttpErrorCheck
Write-Host "unpin1 status=$($r1.StatusCode)"
Write-Host "unpin2 status=$($r2.StatusCode) body=$($r2.Content)"
