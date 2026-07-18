$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-phase7-collection.json'

function Make-Request {
    param(
        [string]$Name, [string]$Method, [string]$Path,
        [string[]]$HeaderVars = @('token_u1'),
        [string]$BodyMode = $null, [string]$BodyRaw = $null, [string]$TestScript = ''
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
'@

$device = '{"deviceID":"BE2A.250530.026.F3","deviceName":"postman-test-device","deviceVersion":"16","appVersion":"2.113.0","platform":"android"}'
function Login-User($label,$username,$tokenVar,$userIdVar,$expectedId) {
    $loginBody = "{`"username`":`"$username`",`"password`":`"Test@12345`",`"deviceInfo`":$device}"
    @(
        (Make-Request -Name "Login $label" -Method POST -Path '/Auth/Login' -HeaderVars @('NONE') -BodyMode raw -BodyRaw $loginBody -TestScript ($helpers + "pm.test('Login $label',()=>assertStatus(200)); pm.collectionVariables.set('$tokenVar', pm.response.json().accessToken);")),
        (Make-Request -Name "Profile $label" -Method GET -Path '/chat/profile' -HeaderVars @($tokenVar) -TestScript ($helpers + "pm.test('Profile $label',()=>assertStatus(200)); pm.collectionVariables.set('$userIdVar', pm.response.json().userId.toString());"))
    )
}

$auth = @()
$auth += Login-User 'U1' 'chattest_sara' 'token_u1' 'userId_u1' '2746'
$auth += Login-User 'U2' 'chattest_reza' 'token_u2' 'userId_u2' '2747'
$auth += Login-User 'U4' 'chattest_kian' 'token_u4' 'userId_u4' '2749'

$setup = @(
    (Make-Request -Name 'Setup List calendars' -Method GET -Path '/Calendar/List' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('Setup calendars 200', () => assertStatus(200));
const list = pm.response.json();
pm.expect(list).to.be.an('array').that.is.not.empty;
const personal = list.find(c => c.type === 'Personal' || c.Type === 'Personal') || list[0];
pm.collectionVariables.set('calendarId', (personal.id || personal.Id).toString());
"@)),
    (Make-Request -Name 'Setup Create event' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"Phase7 Reminder Event","type":"Meeting","startAt":"{{eventStart}}","endAt":"{{eventEnd}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":true,"participantUserIds":[{{userId_u2}}]}
'@ -TestScript ($helpers + @"
pm.test('Setup event 200', () => assertStatus(200));
const id = pm.response.json();
pm.expect(id).to.be.a('number').above(0);
pm.collectionVariables.set('eventId', id.toString());
"@))
)

$folderF1 = @(
    (Make-Request -Name 'F1-1 Valid InApp add' -Method POST -Path '/Calendar/Event/Reminder' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"offsetMinutes":15,"channel":"InApp"}' -TestScript ($helpers + @"
pm.test('F1-1 200', () => assertStatus(200));
const rid = pm.response.json();
pm.expect(rid).to.be.a('number').above(0);
pm.collectionVariables.set('reminderInAppId', rid.toString());
"@)),
    (Make-Request -Name 'F1-1b Valid Sms add' -Method POST -Path '/Calendar/Event/Reminder' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"offsetMinutes":30,"channel":"Sms"}' -TestScript ($helpers + @"
pm.test('F1-1b 200', () => assertStatus(200));
pm.collectionVariables.set('reminderSmsId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'F1-2 Negative offset' -Method POST -Path '/Calendar/Event/Reminder' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"offsetMinutes":-5,"channel":"InApp"}' -TestScript ($helpers + "pm.test('F1-2 400',()=>assertStatus(400));")),
    (Make-Request -Name 'F1-3 Invalid channel' -Method POST -Path '/Calendar/Event/Reminder' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"offsetMinutes":10,"channel":"Push"}' -TestScript ($helpers + "pm.test('F1-3 400',()=>assertStatus(400));")),
    (Make-Request -Name 'F1-5 Event not found' -Method POST -Path '/Calendar/Event/Reminder' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"eventId":999999,"offsetMinutes":10,"channel":"InApp"}' -TestScript ($helpers + "pm.test('F1-5 404',()=>assertStatus(404));")),
    (Make-Request -Name 'F1-6 U4 forbidden add' -Method POST -Path '/Calendar/Event/Reminder' -HeaderVars @('token_u4') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"offsetMinutes":10,"channel":"InApp"}' -TestScript ($helpers + "pm.test('F1-6 403',()=>assertStatus(403));")),
    (Make-Request -Name 'F1-7 Duplicate' -Method POST -Path '/Calendar/Event/Reminder' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"offsetMinutes":15,"channel":"InApp"}' -TestScript ($helpers + "pm.test('F1-7 400',()=>assertStatus(400));"))
)

$folderF3 = @(
    (Make-Request -Name 'F3-1 List reminders' -Method GET -Path '/Calendar/Event/{{eventId}}/Reminders' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('F3-1 200', () => assertStatus(200));
const arr = pm.response.json();
pm.expect(arr).to.be.an('array').with.lengthOf.at.least(2);
"@)),
    (Make-Request -Name 'F3-3 U4 forbidden view' -Method GET -Path '/Calendar/Event/{{eventId}}/Reminders' -HeaderVars @('token_u4') -TestScript ($helpers + "pm.test('F3-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'F3-2 Event not found' -Method GET -Path '/Calendar/Event/999999/Reminders' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('F3-2 404',()=>assertStatus(404));"))
)

$folderF2 = @(
    (Make-Request -Name 'F2-1 Delete InApp' -Method DELETE -Path '/Calendar/Event/Reminder/{{reminderInAppId}}' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('F2-1 200',()=>assertStatus(200)); pm.expect(pm.response.json()).to.eql(true);")),
    (Make-Request -Name 'F2-3 U4 forbidden delete' -Method DELETE -Path '/Calendar/Event/Reminder/{{reminderSmsId}}' -HeaderVars @('token_u4') -TestScript ($helpers + "pm.test('F2-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'F2-2 Not found' -Method DELETE -Path '/Calendar/Event/Reminder/999999' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('F2-2 404',()=>assertStatus(404));"))
)

$now = [DateTime]::UtcNow
$eventStart = $now.AddDays(3).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$eventEnd = $now.AddDays(3).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

$collection = @{
    info = @{
        name = 'Calendar Phase 7 — Reminders F1-F3'
        schema = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' }
        @{ key = 'eventStart'; value = $eventStart }
        @{ key = 'eventEnd'; value = $eventEnd }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth }
        @{ name = '1. Setup'; item = $setup }
        @{ name = '2. F1 Add Reminder'; item = $folderF1 }
        @{ name = '3. F3 List Reminders'; item = $folderF3 }
        @{ name = '4. F2 Delete Reminder'; item = $folderF2 }
    )
}

$collection | ConvertTo-Json -Depth 30 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
