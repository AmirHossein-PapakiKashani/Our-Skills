$ErrorActionPreference = 'Stop'
$baseUrl = 'http://localhost:5144'

function Login-User($username) {
    $body = @{
        username = $username
        password = 'Test@12345'
        deviceInfo = @{
            deviceID = 'BE2A.250530.026.F3'
            deviceName = 'phase10-verify'
            deviceVersion = '16'
            appVersion = '2.113.0'
            platform = 'android'
        }
    } | ConvertTo-Json -Depth 3
    return (Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json' -Body $body).accessToken
}

function Curl-Check($label, $args) {
    Write-Host "`n=== $label ==="
    $out = & curl.exe -s -w "`nHTTP:%{http_code}" @args
    Write-Host $out
}

$token = Login-User 'chattest_sara'

# Fix 1 PR03 - empty multipart PUT profile
Curl-Check 'PR03 empty profile form' @(
    '-X','PUT',"$baseUrl/chat/profile",
    '-H',"Authorization: Bearer $token",
    '-F','displayName=',
    '-F','avatar='
)
# Also truly empty multipart (boundary only)
Curl-Check 'PR03 empty profile (no fields)' @(
    '-X','PUT',"$baseUrl/chat/profile",
    '-H',"Authorization: Bearer $token",
    '-H','Content-Type: multipart/form-data; boundary=----empty',
    '--data-binary',"------empty--`r`n"
)

# Fix 1 M05 - empty multipart message (need valid conv id - get from PV create)
$pv = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/pv/2747" -Method POST -Headers @{ Authorization = "Bearer $token" }
$convId = $pv.id
Curl-Check 'M05 empty message form' @(
    '-X','POST',"$baseUrl/chat/conversations/$convId/messages",
    '-H',"Authorization: Bearer $token",
    '-H','Content-Type: multipart/form-data; boundary=----empty',
    '--data-binary',"------empty--`r`n"
)

# Fix 2 M06
Curl-Check 'M06 nonexistent conversation' @(
    '-X','POST',"$baseUrl/chat/conversations/999999/messages",
    '-H',"Authorization: Bearer $token",
    '-F','text=ghost'
)

# Fix 3 P04
Curl-Check 'P04 nonexistent user PV' @(
    '-X','POST',"$baseUrl/chat/conversations/pv/999999",
    '-H',"Authorization: Bearer $token"
)

# Fix 4 PG01 - no pageSize
Curl-Check 'PG01 no pageSize param' @(
    '-X','GET',"$baseUrl/chat/conversations/$convId/messages",
    '-H',"Authorization: Bearer $token"
)

# Fix 6 block cycle
Write-Host "`n=== B01 block/unblock/re-block cycle ==="
foreach ($step in @('block1','unblock','block2')) {
    if ($step -match 'block') {
        $r = curl.exe -s -w "`nHTTP:%{http_code}" -X POST "$baseUrl/chat/users/2747/block" -H "Authorization: Bearer $token"
    } else {
        $r = curl.exe -s -w "`nHTTP:%{http_code}" -X DELETE "$baseUrl/chat/users/2747/block" -H "Authorization: Bearer $token"
    }
    Write-Host "$step : $r"
}
curl.exe -s -X DELETE "$baseUrl/chat/conversations/2747/block" -H "Authorization: Bearer $token" | Out-Null
curl.exe -s -X DELETE "$baseUrl/chat/users/2747/block" -H "Authorization: Bearer $token" | Out-Null
