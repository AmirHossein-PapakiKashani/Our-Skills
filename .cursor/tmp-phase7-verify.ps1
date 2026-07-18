$ErrorActionPreference = 'Stop'
$baseUrl = 'http://localhost:5144'

function Login-User($username) {
    $body = @{
        username = $username
        password = 'Test@12345'
        deviceInfo = @{
            deviceID = 'BE2A.250530.026.F3'
            deviceName = 'phase7-verify'
            deviceVersion = '16'
            appVersion = '2.113.0'
            platform = 'android'
        }
    } | ConvertTo-Json -Depth 3
    $r = Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json' -Body $body
    return $r.accessToken
}

function Invoke-Api {
    param($Method, $Uri, $Token, $Body = $null, $Form = $null)
    $headers = @{ Authorization = "Bearer $Token" }
    try {
        if ($Form) {
            $resp = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $headers -Form $Form -UseBasicParsing
        } elseif ($Body) {
            $headers['Content-Type'] = 'application/json'
            $resp = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $headers -Body ($Body | ConvertTo-Json -Depth 5) -UseBasicParsing
        } else {
            $resp = Invoke-WebRequest -Uri $Uri -Method $Method -Headers $headers -UseBasicParsing
        }
        return @{ Status = [int]$resp.StatusCode; Body = $resp.Content }
    } catch {
        $status = 0
        $body = $_.Exception.Message
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode.value__
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $body = $reader.ReadToEnd()
                $reader.Close()
            } catch { $body = $_.Exception.Message }
        }
        return @{ Status = $status; Body = $body }
    }
}

Write-Host "=== CLEANUP: Unblock 2747 as sara ==="
$tokenSara = Login-User 'chattest_sara'
$unblock = Invoke-Api -Method DELETE -Uri "$baseUrl/chat/users/2747/block" -Token $tokenSara
Write-Host "DELETE unblock: $($unblock.Status) $($unblock.Body)"

Write-Host "`n=== TARGETED: P02 invalid user id 0 ==="
$p02 = Invoke-Api -Method POST -Uri "$baseUrl/chat/conversations/pv/0" -Token $tokenSara
Write-Host "P02: $($p02.Status) $($p02.Body)"

Write-Host "`n=== TARGETED: G02 empty name ==="
$g02 = Invoke-Api -Method POST -Uri "$baseUrl/chat/groups" -Token $tokenSara -Form @{
    name = ''
    memberUserIds = '2747'
}
Write-Host "G02: $($g02.Status) $($g02.Body)"

Write-Host "`n=== TARGETED: G03 empty members ==="
$g03 = Invoke-Api -Method POST -Uri "$baseUrl/chat/groups" -Token $tokenSara -Form @{
    name = 'Test Group'
    memberUserIds = ''
}
Write-Host "G03: $($g03.Status) $($g03.Body)"

Write-Host "`n=== TARGETED: C03 invalid handle ==="
$c03 = Invoke-Api -Method POST -Uri "$baseUrl/chat/channels" -Token $tokenSara -Form @{
    name = 'Bad Handle Channel'
    handle = 'INVALID-HANDLE!'
    memberUserIds = '2747'
}
Write-Host "C03: $($c03.Status) $($c03.Body)"

Write-Host "`n=== TARGETED: G01 happy path ==="
$g01 = Invoke-Api -Method POST -Uri "$baseUrl/chat/groups" -Token $tokenSara -Form @{
    name = "Phase7 Group $(Get-Date -Format 'HHmmss')"
    memberUserIds = '2747'
}
Write-Host "G01: $($g01.Status) $($g01.Body.Substring(0, [Math]::Min(200, $g01.Body.Length)))"

$ts = Get-Date -Format 'yyyyMMddHHmmss'
Write-Host "`n=== TARGETED: C01 happy path handle=$ts ==="
$c01 = Invoke-Api -Method POST -Uri "$baseUrl/chat/channels" -Token $tokenSara -Form @{
    name = 'Phase7 Channel'
    handle = "day12_ch_$ts"
    memberUserIds = '2747'
}
Write-Host "C01: $($c01.Status) $($c01.Body.Substring(0, [Math]::Min(200, $c01.Body.Length)))"

Write-Host "`n=== B01 CYCLE ==="
Write-Host "B01 block #1"
$b01a = Invoke-Api -Method POST -Uri "$baseUrl/chat/users/2747/block" -Token $tokenSara
Write-Host "Block1: $($b01a.Status) $($b01a.Body)"

Write-Host "B01 unblock"
$b05 = Invoke-Api -Method DELETE -Uri "$baseUrl/chat/users/2747/block" -Token $tokenSara
Write-Host "Unblock: $($b05.Status) $($b05.Body)"

Write-Host "B01 block #2 (ghost-row regression)"
$b01b = Invoke-Api -Method POST -Uri "$baseUrl/chat/users/2747/block" -Token $tokenSara
Write-Host "Block2: $($b01b.Status) $($b01b.Body)"

# cleanup after cycle
Invoke-Api -Method DELETE -Uri "$baseUrl/chat/users/2747/block" -Token $tokenSara | Out-Null

Write-Host "`n=== M06 non-existent conversation ==="
$m06 = Invoke-Api -Method POST -Uri "$baseUrl/chat/conversations/999999999/messages" -Token $tokenSara -Body @{
    text = 'hello'
    clientMessageId = [guid]::NewGuid().ToString()
}
Write-Host "M06: $($m06.Status) $($m06.Body)"

Write-Host "`n=== Export channel handle suffix for Newman ==="
Write-Host "CHANNEL_HANDLE_SUFFIX=$ts"
