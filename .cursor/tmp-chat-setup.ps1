$baseUrl = 'http://localhost:5144'
$deviceInfo = @{
    deviceID = 'BE2A.250530.026.F3'
    deviceName = 'postman-test-device'
    deviceVersion = '16'
    appVersion = '2.113.0'
    platform = 'android'
}
$users = @('chattest_sara','chattest_reza','chattest_nima','chattest_kian')
$results = @()
foreach ($u in $users) {
    $body = @{
        username = $u
        password = 'Test@12345'
        deviceInfo = $deviceInfo
    } | ConvertTo-Json -Depth 3
    try {
        $resp = Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json' -Body $body
        $profileHeaders = @{ Authorization = "Bearer $($resp.accessToken)" }
        $profile = Invoke-RestMethod -Uri "$baseUrl/chat/profile" -Headers $profileHeaders -Method GET
        $results += [PSCustomObject]@{ Username = $u; Status = 'OK'; UserId = $profile.userId; TokenPrefix = $resp.accessToken.Substring(0,20) }
    } catch {
        $err = $_.ErrorDetails.Message
        if (-not $err) { $err = $_.Exception.Message }
        $results += [PSCustomObject]@{ Username = $u; Status = 'FAIL'; UserId = $null; TokenPrefix = $err }
    }
}
$results | Format-Table -AutoSize | Out-String | Write-Output
