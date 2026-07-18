$baseUrl = 'http://localhost:5144'
$body = @{
    username = 'chattest_sara'
    password = 'Test@12345'
    deviceInfo = @{
        deviceID = 'test'
        deviceName = 'test'
        deviceVersion = '16'
        appVersion = '1'
        platform = 'android'
    }
} | ConvertTo-Json -Depth 3
try {
    Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json' -Body $body
} catch {
    Write-Output "Status: $($_.Exception.Response.StatusCode.value__)"
    Write-Output $_.ErrorDetails.Message
}
