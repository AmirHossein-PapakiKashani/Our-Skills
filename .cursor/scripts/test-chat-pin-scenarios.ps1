# Chat Pin Message — Scenario Contract Test Runner
# Run from repo root: powershell -File .cursor/scripts/test-chat-pin-scenarios.ps1

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
            deviceID = "pin-scenario-test"
            deviceName = "pin-scenario"
            deviceVersion = "16"
            appVersion = "2.113.0"
            platform = "android"
        }
    } | ConvertTo-Json -Depth 3
    return (Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType "application/json" -Body $body -TimeoutSec 60).accessToken
}

function Invoke-Api($Method, $Uri, $Token, $Body = $null, $Form = $null) {
    $headers = @{ Authorization = "Bearer $Token" }
    try {
        if ($Form) {
            return @{ Ok = $true; Status = 200; Data = (Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -Form $Form -TimeoutSec 60) }
        }
        if ($Body) {
            return @{ Ok = $true; Status = 200; Data = (Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -Body $Body -ContentType "application/json" -TimeoutSec 60) }
        }
        return @{ Ok = $true; Status = 200; Data = (Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -TimeoutSec 60) }
    }
    catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        $detail = $_.ErrorDetails.Message
        if (-not $detail) { $detail = $_.Exception.Message }
        return @{ Ok = $false; Status = $status; Detail = $detail }
    }
}

function Send-Message($ConversationId, $Token, $Text = "Pin scenario test message") {
    $form = @{ text = $Text }
    return Invoke-Api POST "$baseUrl/chat/conversations/$ConversationId/messages" $Token $null $form
}

Write-Host "=== Chat Pin Scenario Tests ===" -ForegroundColor Cyan

$tokenU1 = Login "chattest_sara"
$tokenU2 = Login "chattest_reza"
$tokenU3 = Login "chattest_nima"
$tokenU4 = Login "chattest_kian"

$h1 = @{ Authorization = "Bearer $tokenU1" }
$h2 = @{ Authorization = "Bearer $tokenU2" }
$h3 = @{ Authorization = "Bearer $tokenU3" }
$userIdU1 = (Invoke-RestMethod -Uri "$baseUrl/chat/profile" -Method GET -Headers $h1 -TimeoutSec 60).userId
$userIdU2 = (Invoke-RestMethod -Uri "$baseUrl/chat/profile" -Method GET -Headers $h2 -TimeoutSec 60).userId
$userIdU3 = (Invoke-RestMethod -Uri "$baseUrl/chat/profile" -Method GET -Headers $h3 -TimeoutSec 60).userId
$h4 = @{ Authorization = "Bearer $tokenU4" }
$userIdU4 = (Invoke-RestMethod -Uri "$baseUrl/chat/profile" -Method GET -Headers $h4 -TimeoutSec 60).userId
Write-Host "Users: U1=$userIdU1 U2=$userIdU2 U3=$userIdU3 U4=$userIdU4"

# Setup PV
$pv = Invoke-Api POST "$baseUrl/chat/conversations/pv/$userIdU2" $tokenU1
if (-not $pv.Ok) { Add-Result "SETUP" "Create PV" $false $pv.Detail; throw "Setup failed: $($pv.Detail)" }
$convPv = $pv.Data.id

$msgPv = Send-Message $convPv $tokenU1
if (-not $msgPv.Ok) { Add-Result "SETUP" "Send PV message" $false $msgPv.Detail; throw "Setup failed: $($msgPv.Detail)" }
$msgPvId = $msgPv.Data.id

# Setup Group (U1 admin)
$grpForm = @{
    name = "Pin Test Group $(Get-Date -Format 'HHmmss')"
    memberUserIds = "$userIdU3,$userIdU4"
}
$grp = Invoke-Api POST "$baseUrl/chat/groups" $tokenU1 $null $grpForm
if (-not $grp.Ok) { Add-Result "SETUP" "Create Group" $false $grp.Detail }
else {
    $convGrp = $grp.Data.id
    $msgGrp = Send-Message $convGrp $tokenU3 "Group pin test"
    if ($msgGrp.Ok) { $msgGrpId = $msgGrp.Data.id }
}

# Setup Channel (U1 admin) — add U3 as member (non-admin)
$chHandle = "pintest$(Get-Random -Maximum 99999)"
$chForm = @{
    name = "Pin Test Channel $(Get-Date -Format 'HHmmss')"
    handle = $chHandle
    memberUserIds = "$userIdU3"
}
$ch = Invoke-Api POST "$baseUrl/chat/channels" $tokenU1 $null $chForm
if (-not $ch.Ok) { Add-Result "SETUP" "Create Channel" $false $ch.Detail }
else {
    $convCh = $ch.Data.id
    $msgCh = Send-Message $convCh $tokenU1 "Channel pin test"
    if ($msgCh.Ok) { $msgChId = $msgCh.Data.id }
}

# --- PIN PV ---
$r = Invoke-Api POST "$baseUrl/chat/conversations/$convPv/messages/$msgPvId/pin" $tokenU1
Add-Result "PIN-PV-H01" "Pin in PV (U1)" ($r.Ok -and $r.Status -eq 200) $(if ($r.Ok) { "200" } else { $r.Detail })

$r = Invoke-Api POST "$baseUrl/chat/conversations/$convPv/messages/$msgPvId/pin" $tokenU2
Add-Result "PIN-PV-H02" "Idempotent pin (U2)" ($r.Ok -and $r.Status -eq 200) $(if ($r.Ok) { "200" } else { $r.Detail })

$r = Invoke-Api POST "$baseUrl/chat/conversations/999999/messages/$msgPvId/pin" $tokenU1
Add-Result "PIN-PV-E02" "Wrong conversation" ($r.Status -eq 400) $r.Detail

$r = Invoke-Api POST "$baseUrl/chat/conversations/$convPv/messages/999999/pin" $tokenU1
Add-Result "PIN-PV-E04" "Message not found" ($r.Status -eq 400) $r.Detail

# --- PIN Group ---
if ($convGrp -and $msgGrpId) {
    $r = Invoke-Api POST "$baseUrl/chat/conversations/$convGrp/messages/$msgGrpId/pin" $tokenU3
    Add-Result "PIN-GRP-H01" "Group member pins" ($r.Ok -and $r.Status -eq 200) $(if ($r.Ok) { "200" } else { $r.Detail })

    $r = Invoke-Api GET "$baseUrl/chat/conversations/$convGrp/pins" $tokenU1
    $hasPin = $r.Ok -and ($r.Data | Where-Object { $_.message.id -eq $msgGrpId })
    Add-Result "PIN-GRP-H02" "Shared pin visible to U1" ($null -ne $hasPin) "pins count: $($r.Data.Count)"
}

# --- PIN Channel ---
if ($convCh -and $msgChId) {
    $r = Invoke-Api POST "$baseUrl/chat/conversations/$convCh/messages/$msgChId/pin" $tokenU1
    Add-Result "PIN-CH-H01" "Channel admin pins" ($r.Ok -and $r.Status -eq 200) $(if ($r.Ok) { "200" } else { $r.Detail })

    $r = Invoke-Api POST "$baseUrl/chat/conversations/$convCh/messages/$msgChId/pin" $tokenU3
    Add-Result "PIN-CH-E01" "Channel member cannot pin" ($r.Status -eq 400) $r.Detail
}

# --- UNPIN ---
$r = Invoke-Api DELETE "$baseUrl/chat/conversations/$convPv/messages/$msgPvId/pin" $tokenU2
Add-Result "UNPIN-H01" "Any participant unpins (U2)" ($r.Ok -and $r.Status -eq 200) $(if ($r.Ok) { "200" } else { $r.Detail })

$r = Invoke-Api DELETE "$baseUrl/chat/conversations/$convPv/messages/$msgPvId/pin" $tokenU1
Add-Result "UNPIN-E01" "Unpin when not pinned" ($r.Status -eq 400) $r.Detail

# Re-pin for GET
Invoke-Api POST "$baseUrl/chat/conversations/$convPv/messages/$msgPvId/pin" $tokenU1 | Out-Null

# --- GET PINS ---
$r = Invoke-Api GET "$baseUrl/chat/conversations/$convPv/pins" $tokenU1
$found = $r.Ok -and ($r.Data | Where-Object { $_.message.id -eq $msgPvId -and $_.message.isPinned -eq $true })
Add-Result "GET-H01" "List pinned messages" ($null -ne $found) "count=$($r.Data.Count)"

$r = Invoke-Api GET "$baseUrl/chat/conversations/$convPv/messages?pageSize=20" $tokenU1
$inList = $r.Ok -and ($r.Data.messages | Where-Object { $_.id -eq $msgPvId -and $_.isPinned -eq $true })
Add-Result "GET-H02" "isPinned in message list" ($null -ne $inList) ""

$r = Invoke-Api GET "$baseUrl/chat/conversations/999999/pins" $tokenU1
Add-Result "GET-E01" "Not a participant" ($r.Status -eq 400) $r.Detail

Write-Host ""
Write-Host "=== Results ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize
$passed = ($results | Where-Object { $_.Pass }).Count
$total = $results.Count
Write-Host "Passed: $passed / $total" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })
if ($passed -ne $total) { exit 1 }
