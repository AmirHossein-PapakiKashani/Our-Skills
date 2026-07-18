[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8
$baseUrl = "http://localhost:5144"
$loginBody = @{
    username = "chattest_sara"
    password = "Test@12345"
    deviceInfo = @{
        deviceID = "t"; deviceName = "t"; deviceVersion = "16"
        appVersion = "2.113.0"; platform = "android"
    }
} | ConvertTo-Json -Depth 3
$token = (Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType "application/json" -Body $loginBody -TimeoutSec 60).accessToken
$h = @{ Authorization = "Bearer $token" }
$profile = Invoke-RestMethod -Uri "$baseUrl/chat/profile" -Method GET -Headers $h -TimeoutSec 60
$pv = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/pv/2747" -Method POST -Headers $h -TimeoutSec 60
$msg = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$($pv.id)/messages" -Method POST -Headers $h -Form @{ text = "pin debug" } -TimeoutSec 60
Write-Host "userId=$($profile.userId) conv=$($pv.id) msg=$($msg.id)"
try {
    $list = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$($pv.id)/messages?pageSize=5" -Method GET -Headers $h -TimeoutSec 60
    Write-Host "messages OK count=$($list.messages.Count)"
}
catch {
    $err = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "messages error:" $err.detail
}
try {
    Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$($pv.id)/messages/$($msg.id)/pin" -Method POST -Headers $h -TimeoutSec 60
    Write-Host "PIN OK"
}
catch {
    $err = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "pin status:" $_.Exception.Response.StatusCode.value__
    Write-Host "pin detail:" $err.detail
}
