# Chat Saved Messages — Scenario Contract Test Runner
# Usage: pwsh -File .cursor/scripts/test-chat-saved-scenarios.ps1

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:5144"
$results = @()

function Add-Result($Id, $Name, $Pass, $Detail) {
    $script:results += [PSCustomObject]@{ Id = $Id; Name = $Name; Pass = $Pass; Detail = $Detail }
}

function Login($username) {
    $body = @{
        username = $username
        password = "Test@12345"
        deviceInfo = @{
            deviceID = "saved-scenario-test"
            deviceName = "saved-scenario"
            deviceVersion = "16"
            appVersion = "2.113.0"
            platform = "android"
        }
    } | ConvertTo-Json -Depth 3
    return (Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType "application/json" -Body $body -TimeoutSec 60).accessToken
}

function Invoke-Api($Method, $Uri, $Token, $Form = $null) {
    $headers = @{}
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    try {
        if ($Form) {
            return @{ Ok = $true; Status = 200; Data = (Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -Form $Form -TimeoutSec 60) }
        }
        return @{ Ok = $true; Status = 200; Data = (Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -TimeoutSec 60) }
    }
    catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ Ok = $false; Status = $status; Detail = $_.ErrorDetails.Message }
    }
}

function Send-Message($ConversationId, $Token, $Text) {
    return Invoke-Api POST "$baseUrl/chat/conversations/$ConversationId/messages" $Token @{ text = $Text }
}

Write-Host "=== Chat Saved Messages Scenario Tests ===" -ForegroundColor Cyan

try {
    $tokenU1 = Login "chattest_sara"
    $tokenU2 = Login "chattest_reza"
    $tokenU3 = Login "chattest_nima"
    $tokenU4 = Login "chattest_kian"
}
catch {
    Write-Host "FATAL: API not reachable at $baseUrl" -ForegroundColor Red
    exit 2
}

$h2 = @{ Authorization = "Bearer $tokenU2" }
$userIdU2 = (Invoke-RestMethod -Uri "$baseUrl/chat/profile" -Method GET -Headers $h2 -TimeoutSec 60).userId

# Setup PV
$pv = Invoke-Api POST "$baseUrl/chat/conversations/pv/$userIdU2" $tokenU1
if (-not $pv.Ok) { throw "PV setup failed: $($pv.Detail)" }
$convPv = $pv.Data.id
$msgPv = Send-Message $convPv $tokenU1 "Saved scenario PV message"
if (-not $msgPv.Ok) { throw "PV message failed: $($msgPv.Detail)" }
$msgPvId = $msgPv.Data.id

# Setup Group
$grpForm = @{ name = "Saved Test Group $(Get-Date -Format 'HHmmss')"; memberUserIds = "2748,2749" }
$grp = Invoke-Api POST "$baseUrl/chat/groups" $tokenU1 $grpForm
if ($grp.Ok) {
    $convGrp = $grp.Data.id
    $msgGrp = Send-Message $convGrp $tokenU3 "Saved scenario group message"
    $msgGrpId = $msgGrp.Data.id
}

# --- SAVE ---
$r = Invoke-Api POST "$baseUrl/chat/messages/$msgPvId/save" $tokenU1
Add-Result "SAVE-H01" "Save PV message" ($r.Ok -and $r.Status -eq 200) $(if ($r.Ok) { "200" } else { $r.Detail })

$r = Invoke-Api POST "$baseUrl/chat/messages/$msgPvId/save" $tokenU1
Add-Result "SAVE-H04" "Idempotent save" ($r.Ok -and $r.Status -eq 200) ""

if ($msgGrpId) {
    $r = Invoke-Api POST "$baseUrl/chat/messages/$msgGrpId/save" $tokenU3
    Add-Result "SAVE-H02" "Save group message" ($r.Ok -and $r.Status -eq 200) ""
}

$r = Invoke-Api POST "$baseUrl/chat/messages/999999/save" $tokenU1
Add-Result "SAVE-E01" "Message not found" ($r.Status -eq 400) $r.Detail

# Non-participant: U4 saves U1's PV message
$r = Invoke-Api POST "$baseUrl/chat/messages/$msgPvId/save" $tokenU4
Add-Result "SAVE-E03" "Not a participant" ($r.Status -eq 400) $r.Detail

$r = Invoke-Api POST "$baseUrl/chat/messages/$msgPvId/save" $null
Add-Result "SAVE-E04" "No auth" ($r.Status -eq 401) "status=$($r.Status)"

# Re-save after unsave
Invoke-Api DELETE "$baseUrl/chat/messages/$msgPvId/save" $tokenU1 | Out-Null
$r = Invoke-Api POST "$baseUrl/chat/messages/$msgPvId/save" $tokenU1
Add-Result "SAVE-H05" "Re-save after unsave" ($r.Ok -and $r.Status -eq 200) ""

# isSavedByMe ripple
Invoke-Api POST "$baseUrl/chat/messages/$msgPvId/save" $tokenU1 | Out-Null
$r = Invoke-Api GET "$baseUrl/chat/conversations/$convPv/messages?pageSize=20" $tokenU1
$found = $r.Ok -and ($r.Data.messages | Where-Object { $_.id -eq $msgPvId -and $_.isSavedByMe -eq $true })
Add-Result "SAVE-R01" "isSavedByMe true in message list" ($null -ne $found) ""

# --- UNSAVE ---
$r = Invoke-Api DELETE "$baseUrl/chat/messages/$msgPvId/save" $tokenU1
Add-Result "UNSAVE-H01" "Unsave happy path" ($r.Ok -and $r.Status -eq 200) ""

$r = Invoke-Api DELETE "$baseUrl/chat/messages/$msgPvId/save" $tokenU1
Add-Result "UNSAVE-E02" "Double unsave" ($r.Status -eq 400) $r.Detail

Invoke-Api POST "$baseUrl/chat/messages/$msgPvId/save" $tokenU1 | Out-Null
Invoke-Api DELETE "$baseUrl/chat/messages/$msgPvId/save" $tokenU1 | Out-Null
$r = Invoke-Api GET "$baseUrl/chat/conversations/$convPv/messages?pageSize=20" $tokenU1
$cleared = $r.Ok -and ($r.Data.messages | Where-Object { $_.id -eq $msgPvId -and $_.isSavedByMe -eq $false })
Add-Result "UNSAVE-R01" "isSavedByMe false after unsave" ($null -ne $cleared) ""

# --- GET SAVED ---
Invoke-Api POST "$baseUrl/chat/messages/$msgPvId/save" $tokenU1 | Out-Null
if ($msgGrpId) { Invoke-Api POST "$baseUrl/chat/messages/$msgGrpId/save" $tokenU1 | Out-Null }

$r = Invoke-Api GET "$baseUrl/chat/messages/saved?PageIndex=0&PageSize=20" $tokenU1
$hasPv = $r.Ok -and ($r.Data.data | Where-Object { $_.message.id -eq $msgPvId })
Add-Result "GET-H01" "List contains saved PV" ($null -ne $hasPv) "total=$($r.Data.totalCount)"

$r = Invoke-Api GET "$baseUrl/chat/messages/saved?PageIndex=0&PageSize=1" $tokenU1
Add-Result "GET-P01" "Pagination page size 1" ($r.Ok -and $r.Data.count -eq 1) "total=$($r.Data.totalCount)"

$r = Invoke-Api GET "$baseUrl/chat/messages/saved?PageIndex=99&PageSize=10" $tokenU1
Add-Result "GET-P02" "Page past end" ($r.Ok -and $r.Data.data.Count -eq 0) ""

$r = Invoke-Api GET "$baseUrl/chat/messages/saved" $null
Add-Result "GET-E01" "No auth on list" ($r.Status -eq 401) ""

# User isolation
$rU2 = Invoke-Api GET "$baseUrl/chat/messages/saved?PageIndex=0&PageSize=50" $tokenU2
$leak = $rU2.Ok -and ($rU2.Data.data | Where-Object { $_.message.id -eq $msgPvId })
Add-Result "GET-R01" "U2 list excludes U1 bookmark" (-not $leak) ""

Invoke-Api DELETE "$baseUrl/chat/messages/$msgPvId/save" $tokenU1 | Out-Null
$r = Invoke-Api GET "$baseUrl/chat/messages/saved?PageIndex=0&PageSize=50" $tokenU1
$gone = $r.Ok -and -not ($r.Data.data | Where-Object { $_.message.id -eq $msgPvId })
Add-Result "GET-S01" "Unsaved excluded from list" $gone ""

Write-Host ""
Write-Host "=== Results ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize
$passed = ($results | Where-Object { $_.Pass }).Count
$total = $results.Count
Write-Host "Passed: $passed / $total" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })
if ($passed -ne $total) { exit 1 }
