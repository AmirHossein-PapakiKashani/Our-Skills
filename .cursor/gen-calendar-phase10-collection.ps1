$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-phase10-collection.json'

function Make-Request {
    param(
        [string]$Name, [string]$Method, [string]$Path,
        [string[]]$HeaderVars = @('token_u1'),
        [string]$BodyMode = $null, [string]$BodyRaw = $null,
        [string]$TestScript = ''
    )
    $headers = @()
    if ($HeaderVars -and $HeaderVars[0] -ne 'NONE') {
        foreach ($hv in $HeaderVars) { $headers += @{ key = 'Authorization'; value = "Bearer {{$hv}}" } }
    }
    $pathParts = @($Path.TrimStart('/') -split '/' | Where-Object { $_ -ne '' })
    $query = @(); $rawPath = $Path
    if ($Path -match '\?') {
        $rawPath = ($Path -split '\?')[0]
        foreach ($pair in (($Path -split '\?', 2)[1] -split '&')) {
            if ($pair -match '^([^=]+)=(.*)$') { $query += @{ key = $Matches[1]; value = $Matches[2] } }
        }
        $pathParts = @($rawPath.TrimStart('/') -split '/' | Where-Object { $_ -ne '' })
    }
    $url = @{ raw = "{{baseUrl}}$Path"; host = @('{{baseUrl}}'); path = $pathParts }
    if ($query.Count -gt 0) { $url.query = $query }
    $req = @{ method = $Method; header = $headers; url = $url }
    if ($BodyMode -eq 'raw') {
        $req.body = @{ mode = 'raw'; raw = $BodyRaw; options = @{ raw = @{ language = 'json' } } }
        $req.header += @{ key = 'Content-Type'; value = 'application/json' }
    }
    $events = @()
    if ($TestScript) {
        $events += @{ listen = 'test'; script = @{ type = 'text/javascript'; exec = ($TestScript -split "`n") } }
    }
    return @{ name = $Name; request = $req; event = $events }
}

$helpers = @'
function assertStatus(code) { pm.response.to.have.status(code); }
function assertConflictDetail() {
  const body = pm.response.json();
  const d = body.detail || "";
  pm.expect(d.length).to.be.above(10);
  // "کاربر" via unicode escapes — avoids PowerShell/JSON mojibake in scripts
  pm.expect(d).to.include("\u06a9\u0627\u0631\u0628\u0631");
}
'@

$device = '{"deviceID":"BE2A.250530.026.F3","deviceName":"postman-test-device","deviceVersion":"16","appVersion":"2.113.0","platform":"android"}'
function Login-User($label,$username,$tokenVar,$userIdVar) {
    $loginBody = "{`"username`":`"$username`",`"password`":`"Test@12345`",`"deviceInfo`":$device}"
    @(
        (Make-Request -Name "Login $label" -Method POST -Path '/Auth/Login' -HeaderVars @('NONE') -BodyMode raw -BodyRaw $loginBody -TestScript ($helpers + "pm.test('Login $label',()=>assertStatus(200)); pm.collectionVariables.set('$tokenVar', pm.response.json().accessToken);")),
        (Make-Request -Name "Profile $label" -Method GET -Path '/chat/profile' -HeaderVars @($tokenVar) -TestScript ($helpers + "pm.test('Profile $label',()=>assertStatus(200)); pm.collectionVariables.set('$userIdVar', pm.response.json().userId.toString());"))
    )
}

$now = [DateTime]::UtcNow
# Unique far-future base so re-runs don't collide with leftover events
$base = $now.AddDays(40).AddMinutes(([DateTime]::UtcNow.Ticks % 20000))
$slotStart = $base.AddDays(0).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slotEnd = $base.AddDays(0).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slot2Start = $base.AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slot2End = $base.AddDays(1).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slot3Start = $base.AddDays(2).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slot3End = $base.AddDays(2).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slot4Start = $base.AddDays(3).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slot4End = $base.AddDays(3).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slot5Start = $base.AddDays(4).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slot5End = $base.AddDays(4).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slotFreeStart = $base.AddDays(5).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slotFreeEnd = $base.AddDays(5).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slotFree2Start = $base.AddDays(6).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$slotFree2End = $base.AddDays(6).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

$auth = @()
$auth += Login-User 'U1' 'chattest_sara' 'token_u1' 'userId_u1'
$auth += Login-User 'U2' 'chattest_reza' 'token_u2' 'userId_u2'
$auth += Login-User 'U3' 'chattest_nima' 'token_u3' 'userId_u3'
$auth += Login-User 'U4' 'chattest_kian' 'token_u4' 'userId_u4'

$setup = @(
    (Make-Request -Name 'Setup List calendars U1' -Method GET -Path '/Calendar/List' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('calendars 200', () => assertStatus(200));
const list = pm.response.json();
const personal = list.find(c => c.type === 'Personal' || c.Type === 'Personal') || list[0];
pm.collectionVariables.set('calendarId', (personal.id || personal.Id).toString());
"@)),
    (Make-Request -Name 'Setup List calendars U2' -Method GET -Path '/Calendar/List' -HeaderVars @('token_u2') -TestScript ($helpers + @"
pm.test('U2 calendars 200', () => assertStatus(200));
const list = pm.response.json();
const personal = list.find(c => c.type === 'Personal' || c.Type === 'Personal') || list[0];
pm.collectionVariables.set('calendarIdU2', (personal.id || personal.Id).toString());
"@)),
    (Make-Request -Name 'Setup List calendars U4' -Method GET -Path '/Calendar/List' -HeaderVars @('token_u4') -TestScript ($helpers + @"
pm.test('U4 calendars 200', () => assertStatus(200));
const list = pm.response.json();
const personal = list.find(c => c.type === 'Personal' || c.Type === 'Personal') || list[0];
pm.collectionVariables.set('calendarIdU4', (personal.id || personal.Id).toString());
"@)),
    (Make-Request -Name 'Setup U2 busy creator slot1' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarIdU2}},"title":"P10 U2 busy","type":"Meeting","startAt":"{{slotStart}}","endAt":"{{slotEnd}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + "pm.test('U2 busy event 200', () => assertStatus(200));")),
    (Make-Request -Name 'Setup U3 busy as invitee slot2' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"P10 U3 invited busy","type":"Meeting","startAt":"{{slot2Start}}","endAt":"{{slot2End}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[{{userId_u3}}]}
'@ -TestScript ($helpers + "pm.test('U3 invite event 200', () => assertStatus(200));")),
    (Make-Request -Name 'Setup U1 busy creator slot3' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"P10 U1 self busy","type":"Meeting","startAt":"{{slot3Start}}","endAt":"{{slot3End}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + "pm.test('U1 busy event 200', () => assertStatus(200));")),
    (Make-Request -Name 'Setup U1 editable event slot4' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"P10 editable","type":"Meeting","startAt":"{{slot4Start}}","endAt":"{{slot4End}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[{{userId_u2}}]}
'@ -TestScript ($helpers + @"
pm.test('editable event 200', () => assertStatus(200));
pm.collectionVariables.set('editableEventId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'Setup U2 busy slot5 for meeting request' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarIdU2}},"title":"P10 U2 slot5 busy","type":"Meeting","startAt":"{{slot5Start}}","endAt":"{{slot5End}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + "pm.test('U2 slot5 busy 200', () => assertStatus(200));")),
    (Make-Request -Name 'Setup U4 host for D1 at slot2' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u4') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarIdU4}},"title":"P10 D1 host","type":"Meeting","startAt":"{{slot2Start}}","endAt":"{{slot2End}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + @"
pm.test('D1 host event 200', () => assertStatus(200));
pm.collectionVariables.set('d1HostEventId', pm.response.json().toString());
"@))
)

$tests = @(
    (Make-Request -Name 'B1-HP create no conflict' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"P10 B1 happy","type":"Info","startAt":"{{slotFreeStart}}","endAt":"{{slotFreeEnd}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + @"
pm.test('B1-HP 200', () => assertStatus(200));
pm.collectionVariables.set('happyEventId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'B1-C1 invitee conflict 409' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"P10 B1 invitee conflict","type":"Meeting","startAt":"{{slotStart}}","endAt":"{{slotEnd}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[{{userId_u2}}]}
'@ -TestScript ($helpers + @"
pm.test('B1-C1 409', () => assertStatus(409));
pm.test('B1-C1 detail', () => assertConflictDetail());
"@)),
    (Make-Request -Name 'B1-C2 creator self conflict 409' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"P10 B1 self conflict","type":"Meeting","startAt":"{{slot3Start}}","endAt":"{{slot3End}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + @"
pm.test('B1-C2 409', () => assertStatus(409));
pm.test('B1-C2 detail', () => assertConflictDetail());
"@)),
    (Make-Request -Name 'B2-C1 time change invitee conflict 409' -Method PUT -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"id":{{editableEventId}},"calendarId":{{calendarId}},"title":"P10 editable conflict","type":"Meeting","startAt":"{{slotStart}}","endAt":"{{slotEnd}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[{{userId_u2}}],"editScope":"All"}
'@ -TestScript ($helpers + @"
pm.test('B2-C1 409', () => assertStatus(409));
pm.test('B2-C1 detail', () => assertConflictDetail());
"@)),
    (Make-Request -Name 'D1-C1 add busy participant 409' -Method POST -Path '/Calendar/Event/Participant' -HeaderVars @('token_u4') -BodyMode raw -BodyRaw @'
{"eventId":{{d1HostEventId}},"userIds":[{{userId_u3}}]}
'@ -TestScript ($helpers + @"
pm.test('D1-C1 409', () => assertStatus(409));
pm.test('D1-C1 detail', () => assertConflictDetail());
"@)),
    (Make-Request -Name 'E1-C1 meeting request target busy 409' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"targetUserId":{{userId_u2}},"title":"P10 E1 conflict","description":"x","location":"","startAt":"{{slot5Start}}","endAt":"{{slot5End}}"}
'@ -TestScript ($helpers + @"
pm.test('E1-C1 409', () => assertStatus(409));
pm.test('E1-C1 detail', () => assertConflictDetail());
"@)),
    (Make-Request -Name 'E1-HP meeting request free slot' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"targetUserId":{{userId_u2}},"title":"P10 E1 happy","description":"x","location":"","startAt":"{{slotFree2Start}}","endAt":"{{slotFree2End}}"}
'@ -TestScript ($helpers + @"
pm.test('E1-HP 200', () => assertStatus(200));
pm.collectionVariables.set('meetingRequestId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'E2-setup conflict on pending slot' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarIdU2}},"title":"P10 race conflict","type":"Meeting","startAt":"{{slotFree2Start}}","endAt":"{{slotFree2End}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + "pm.test('E2 race event 200', () => assertStatus(200));")),
    (Make-Request -Name 'E2-C1 approve now conflicted 409' -Method POST -Path '/Calendar/MeetingRequest/Approve' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw @'
{"requestId":{{meetingRequestId}}}
'@ -TestScript ($helpers + @"
pm.test('E2-C1 409', () => assertStatus(409));
pm.test('E2-C1 detail', () => assertConflictDetail());
"@))
)

$collection = @{
    info = @{
        name = 'Calendar Phase 10 — Conflict Blocking 409'
        schema = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' }
        @{ key = 'slotStart'; value = $slotStart }
        @{ key = 'slotEnd'; value = $slotEnd }
        @{ key = 'slot2Start'; value = $slot2Start }
        @{ key = 'slot2End'; value = $slot2End }
        @{ key = 'slot3Start'; value = $slot3Start }
        @{ key = 'slot3End'; value = $slot3End }
        @{ key = 'slot4Start'; value = $slot4Start }
        @{ key = 'slot4End'; value = $slot4End }
        @{ key = 'slot5Start'; value = $slot5Start }
        @{ key = 'slot5End'; value = $slot5End }
        @{ key = 'slotFreeStart'; value = $slotFreeStart }
        @{ key = 'slotFreeEnd'; value = $slotFreeEnd }
        @{ key = 'slotFree2Start'; value = $slotFree2Start }
        @{ key = 'slotFree2End'; value = $slotFree2End }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth }
        @{ name = '1. Setup busy events'; item = $setup }
        @{ name = '2. Conflict scenarios'; item = $tests }
    )
}

$collection | ConvertTo-Json -Depth 40 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
