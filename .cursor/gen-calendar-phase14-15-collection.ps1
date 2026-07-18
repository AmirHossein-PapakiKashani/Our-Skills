$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-phase14-15-collection.json'

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
$base = $now.AddDays(60).Date.AddHours(10)
$kFrom = $base.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$kTo = $base.AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$validFrom = $base.AddDays(-1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$validTo = $base.AddDays(30).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$meetingStart = $base.AddDays(2).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$meetingEnd = $base.AddDays(2).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

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
    (Make-Request -Name 'Setup Create meeting event for L-phase' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"P14-15 Minutes Host","type":"Meeting","startAt":"{{meetingStart}}","endAt":"{{meetingEnd}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + @"
pm.test('event 200', () => assertStatus(200));
pm.collectionVariables.set('minutesEventId', pm.response.json().toString());
"@))
)

$phase14 = @(
    (Make-Request -Name 'K1-2 Invalid duration 400' -Method POST -Path '/Calendar/SchedulingLinks' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"title":"Bad Duration","durationMinutes":3}
'@ -TestScript ($helpers + "pm.test('K1-2 400',()=>assertStatus(400));")),
    (Make-Request -Name 'K1-1 Create scheduling link' -Method POST -Path '/Calendar/SchedulingLinks' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"title":"P14 Public Link","durationMinutes":30,"validFrom":"{{validFrom}}","validTo":"{{validTo}}","allowedWeekDays":[1,2,3,4,5],"dailyTimeWindow":{"start":"09:00","end":"17:00"}}
'@ -TestScript ($helpers + @"
pm.test('K1-1 200', () => assertStatus(200));
const id = pm.response.json();
pm.expect(id).to.be.a('number').above(0);
pm.collectionVariables.set('linkId', id.toString());
"@)),
    (Make-Request -Name 'K2 List links and capture token' -Method GET -Path '/Calendar/SchedulingLinks' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('K2 200', () => assertStatus(200));
const list = pm.response.json();
pm.expect(list).to.be.an('array');
const lid = parseInt(pm.collectionVariables.get('linkId'), 10);
const row = list.find(x => x.id === lid);
pm.test('link present', () => pm.expect(row).to.be.an('object'));
pm.collectionVariables.set('schedToken', row.token);
"@)),
    (Make-Request -Name 'K4-2 Invalid token 404' -Method GET -Path '/Calendar/SchedulingLinks/not-a-real-token/Availability?from={{kFrom}}&to={{kTo}}' -HeaderVars @('NONE') -TestScript ($helpers + "pm.test('K4-2 404',()=>assertStatus(404));")),
    (Make-Request -Name 'K4-1 Availability slots' -Method GET -Path '/Calendar/SchedulingLinks/{{schedToken}}/Availability?from={{kFrom}}&to={{kTo}}' -HeaderVars @('NONE') -TestScript ($helpers + @"
pm.test('K4-1 200', () => assertStatus(200));
const slots = pm.response.json();
pm.expect(slots).to.be.an('array');
pm.test('has slot', () => pm.expect(slots.length).to.be.above(0));
pm.collectionVariables.set('bookStart', slots[0].startAt);
"@)),
    (Make-Request -Name 'K5-1 Book free slot' -Method POST -Path '/Calendar/SchedulingLinks/{{schedToken}}/Book' -HeaderVars @('NONE') -BodyMode raw -BodyRaw @'
{"guestFullName":"Guest Tester","guestPhoneNumber":"09121234567","startAt":"{{bookStart}}"}
'@ -TestScript ($helpers + @"
pm.test('K5-1 200', () => assertStatus(200));
const eid = pm.response.json();
pm.expect(eid).to.be.a('number').above(0);
pm.collectionVariables.set('bookedEventId', eid.toString());
"@)),
    (Make-Request -Name 'K5-2 Book same slot 409' -Method POST -Path '/Calendar/SchedulingLinks/{{schedToken}}/Book' -HeaderVars @('NONE') -BodyMode raw -BodyRaw @'
{"guestFullName":"Guest Two","guestPhoneNumber":"09129876543","startAt":"{{bookStart}}"}
'@ -TestScript ($helpers + "pm.test('K5-2 409',()=>assertStatus(409));")),
    (Make-Request -Name 'K6-3 Invalid phone 400' -Method POST -Path '/Calendar/Event/GuestInvite' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"eventId":{{bookedEventId}},"guestFullName":"Bad Phone","guestPhoneNumber":"abc"}
'@ -TestScript ($helpers + "pm.test('K6-3 400',()=>assertStatus(400));")),
    (Make-Request -Name 'K6-1 Guest invite ok' -Method POST -Path '/Calendar/Event/GuestInvite' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"eventId":{{bookedEventId}},"guestFullName":"Invited Guest","guestPhoneNumber":"09121112233"}
'@ -TestScript ($helpers + "pm.test('K6-1 200',()=>assertStatus(200));")),
    (Make-Request -Name 'K3-3 Other user delete 403' -Method DELETE -Path '/Calendar/SchedulingLinks/{{linkId}}' -HeaderVars @('token_u2') -TestScript ($helpers + "pm.test('K3-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'K3-2 Link not found 404' -Method DELETE -Path '/Calendar/SchedulingLinks/999999001' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('K3-2 404',()=>assertStatus(404));")),
    (Make-Request -Name 'K3-1 Owner soft-delete link' -Method DELETE -Path '/Calendar/SchedulingLinks/{{linkId}}' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('K3-1 200',()=>assertStatus(200));"))
)

$phase15 = @(
    (Make-Request -Name 'L1-1 Create minutes' -Method POST -Path '/Calendar/Event/Minutes' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"eventId":{{minutesEventId}},"overallOutcome":"Initial outcome"}
'@ -TestScript ($helpers + @"
pm.test('L1-1 200', () => assertStatus(200));
const id = pm.response.json();
pm.expect(id).to.be.a('number').above(0);
pm.collectionVariables.set('minutesId', id.toString());
"@)),
    (Make-Request -Name 'L1-2 Duplicate minutes 409' -Method POST -Path '/Calendar/Event/Minutes' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"eventId":{{minutesEventId}},"overallOutcome":"dup"}
'@ -TestScript ($helpers + "pm.test('L1-2 409',()=>assertStatus(409));")),
    (Make-Request -Name 'L2-1 Get minutes' -Method GET -Path '/Calendar/Event/{{minutesEventId}}/Minutes' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('L2-1 200', () => assertStatus(200));
const m = pm.response.json();
pm.expect(m.id.toString()).to.eql(pm.collectionVariables.get('minutesId'));
pm.expect(m.overallOutcome).to.eql('Initial outcome');
"@)),
    (Make-Request -Name 'L3-1 Update agenda and decisions' -Method PUT -Path '/Calendar/Minutes' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"id":{{minutesId}},"overallOutcome":"Updated outcome","agendaItems":["Topic A","Topic B"],"decisions":["Decision 1"]}
'@ -TestScript ($helpers + "pm.test('L3-1 200',()=>assertStatus(200));")),
    (Make-Request -Name 'L2-1b Verify updated content' -Method GET -Path '/Calendar/Event/{{minutesEventId}}/Minutes' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('L2-1b 200', () => assertStatus(200));
const m = pm.response.json();
pm.test('outcome', () => pm.expect(m.overallOutcome).to.eql('Updated outcome'));
pm.test('agenda count', () => pm.expect(m.agendaItems.length).to.eql(2));
pm.test('decisions count', () => pm.expect(m.decisions.length).to.eql(1));
"@)),
    (Make-Request -Name 'L4-1 Add action with assignee U2' -Method POST -Path '/Calendar/Minutes/Actions' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"minutesId":{{minutesId}},"title":"Follow up item","assigneeUserId":{{userId_u2}},"dueDate":"{{meetingEnd}}"}
'@ -TestScript ($helpers + @"
pm.test('L4-1 200', () => assertStatus(200));
pm.collectionVariables.set('actionId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'L4 bad assignee 404' -Method POST -Path '/Calendar/Minutes/Actions' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"minutesId":{{minutesId}},"title":"Bad assignee","assigneeUserId":999999001}
'@ -TestScript ($helpers + "pm.test('L4 404',()=>assertStatus(404));")),
    (Make-Request -Name 'L5-2 Not completed without reason 400' -Method PUT -Path '/Calendar/Minutes/Actions/Status' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"id":{{actionId}},"isCompleted":false}
'@ -TestScript ($helpers + "pm.test('L5-2 400',()=>assertStatus(400));")),
    (Make-Request -Name 'L5-1 Mark action completed' -Method PUT -Path '/Calendar/Minutes/Actions/Status' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"id":{{actionId}},"isCompleted":true}
'@ -TestScript ($helpers + "pm.test('L5-1 200',()=>assertStatus(200));")),
    (Make-Request -Name 'L6-1 Soft-delete action' -Method DELETE -Path '/Calendar/Minutes/Actions/{{actionId}}' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('L6-1 200',()=>assertStatus(200));")),
    (Make-Request -Name 'L2-1c Actions excluded after delete' -Method GET -Path '/Calendar/Event/{{minutesEventId}}/Minutes' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('L2-1c 200', () => assertStatus(200));
const aid = parseInt(pm.collectionVariables.get('actionId'), 10);
pm.test('action gone', () => pm.expect(pm.response.json().actions.every(a => a.id !== aid)).to.be.true);
"@))
)

$collection = @{
    info = @{
        name = 'Calendar Phase 14-15 — Scheduling Links + Minutes'
        schema = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' }
        @{ key = 'kFrom'; value = $kFrom }
        @{ key = 'kTo'; value = $kTo }
        @{ key = 'validFrom'; value = $validFrom }
        @{ key = 'validTo'; value = $validTo }
        @{ key = 'meetingStart'; value = $meetingStart }
        @{ key = 'meetingEnd'; value = $meetingEnd }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth }
        @{ name = '1. Setup'; item = $setup }
        @{ name = '2. Phase 14 Scheduling Links'; item = $phase14 }
        @{ name = '3. Phase 15 Meeting Minutes'; item = $phase15 }
    )
}

$collection | ConvertTo-Json -Depth 40 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
