$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-phase6-collection.json'

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
function assertHasDetail() {
  const j = pm.response.json();
  const hay = (j.detail || j.title || '');
  pm.expect(hay).to.be.a('string').and.not.empty;
}
'@

$device = '{"deviceID":"BE2A.250530.026.F3","deviceName":"postman-test-device","deviceVersion":"16","appVersion":"2.113.0","platform":"android"}'
function Login-User($label,$username,$tokenVar,$userIdVar,$expectedId) {
    $loginBody = "{`"username`":`"$username`",`"password`":`"Test@12345`",`"deviceInfo`":$device}"
    @(
        (Make-Request -Name "Login $label" -Method POST -Path '/Auth/Login' -HeaderVars @('NONE') -BodyMode raw -BodyRaw $loginBody -TestScript ($helpers + "pm.test('Login $label',()=>assertStatus(200)); pm.collectionVariables.set('$tokenVar', pm.response.json().accessToken);")),
        (Make-Request -Name "Profile $label" -Method GET -Path '/chat/profile' -HeaderVars @($tokenVar) -TestScript ($helpers + "pm.test('Profile $label',()=>assertStatus(200)); pm.expect(pm.response.json().userId).to.eql($expectedId); pm.collectionVariables.set('$userIdVar', pm.response.json().userId.toString());"))
    )
}

$auth = @()
$auth += Login-User 'U1' 'chattest_sara' 'token_u1' 'userId_u1' '2746'
$auth += Login-User 'U2' 'chattest_reza' 'token_u2' 'userId_u2' '2747'
$auth += Login-User 'U3' 'chattest_nima' 'token_u3' 'userId_u3' '2748'
$auth += Login-User 'U4' 'chattest_kian' 'token_u4' 'userId_u4' '2749'

$folderE1 = @(
    (Make-Request -Name 'E1-1 Create happy' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"targetUserId":{{userId_u2}},"title":"Phase6 Budget Sync","description":"Q3","location":"Room A","startAt":"{{mrStart}}","endAt":"{{mrEnd}}"}
'@ -TestScript ($helpers + @"
pm.test('E1-1 200', () => assertStatus(200));
const id = pm.response.json();
pm.expect(id).to.be.a('number').above(0);
pm.collectionVariables.set('requestId', id.toString());
"@)),
    (Make-Request -Name 'E1-2 Invalid title' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"targetUserId":{{userId_u2}},"title":"A","startAt":"{{mrStart2}}","endAt":"{{mrEnd2}}"}' -TestScript ($helpers + "pm.test('E1-2 400',()=>assertStatus(400));")),
    (Make-Request -Name 'E1-3 Bad time' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"targetUserId":{{userId_u2}},"title":"Bad Time","startAt":"{{mrEnd}}","endAt":"{{mrStart}}"}' -TestScript ($helpers + "pm.test('E1-3 400',()=>assertStatus(400)); pm.test('detail',()=>assertHasDetail());")),
    (Make-Request -Name 'E1-4 Self target' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"targetUserId":{{userId_u1}},"title":"Self Meet","startAt":"{{mrStart2}}","endAt":"{{mrEnd2}}"}' -TestScript ($helpers + "pm.test('E1-4 400',()=>assertStatus(400));")),
    (Make-Request -Name 'E1-5 Target not found' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"targetUserId":999999,"title":"Missing User","startAt":"{{mrStart2}}","endAt":"{{mrEnd2}}"}' -TestScript ($helpers + "pm.test('E1-5 404',()=>assertStatus(404));"))
)

$folderE4E5E6 = @(
    (Make-Request -Name 'E4-1 Pending for U2' -Method GET -Path '/Calendar/MeetingRequest/Pending?page=0' -HeaderVars @('token_u2') -TestScript ($helpers + @"
pm.test('E4-1 200', () => assertStatus(200));
const p = pm.response.json();
pm.expect(p.data || p.Data).to.be.an('array');
pm.expect(p.totalCount ?? p.TotalCount).to.be.at.least(1);
"@)),
    (Make-Request -Name 'E5-1 Sent for U1' -Method GET -Path '/Calendar/MeetingRequest/Sent?page=0' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('E5-1 200', () => assertStatus(200));
const p = pm.response.json();
pm.expect(p.data || p.Data).to.be.an('array').that.is.not.empty;
"@)),
    (Make-Request -Name 'E6-1 Get by id' -Method GET -Path '/Calendar/MeetingRequest/{{requestId}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('E6-1 200', () => assertStatus(200));
const d = pm.response.json();
pm.expect(d.status).to.eql('Pending');
pm.expect(d.title).to.be.a('string').and.not.empty;
"@)),
    (Make-Request -Name 'E6-3 Outsider forbidden' -Method GET -Path '/Calendar/MeetingRequest/{{requestId}}' -HeaderVars @('token_u4') -TestScript ($helpers + "pm.test('E6-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'E6-2 Not found' -Method GET -Path '/Calendar/MeetingRequest/999999' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('E6-2 404',()=>assertStatus(404));"))
)

$folderE2 = @(
    (Make-Request -Name 'E2-3 U3 cannot approve' -Method POST -Path '/Calendar/MeetingRequest/Approve' -HeaderVars @('token_u3') -BodyMode raw -BodyRaw '{"requestId":{{requestId}}}' -TestScript ($helpers + "pm.test('E2-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'E2-1 U2 approve' -Method POST -Path '/Calendar/MeetingRequest/Approve' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw '{"requestId":{{requestId}}}' -TestScript ($helpers + @"
pm.test('E2-1 200', () => assertStatus(200));
const eventId = pm.response.json();
pm.expect(eventId).to.be.a('number').above(0);
pm.collectionVariables.set('approvedEventId', eventId.toString());
"@)),
    (Make-Request -Name 'E2-4 Already processed' -Method POST -Path '/Calendar/MeetingRequest/Approve' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw '{"requestId":{{requestId}}}' -TestScript ($helpers + "pm.test('E2-4 400',()=>assertStatus(400));")),
    (Make-Request -Name 'E2-2 Not found' -Method POST -Path '/Calendar/MeetingRequest/Approve' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw '{"requestId":999999}' -TestScript ($helpers + "pm.test('E2-2 404',()=>assertStatus(404));"))
)

$folderE3E7 = @(
    (Make-Request -Name 'Setup Create for reject' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"targetUserId":{{userId_u3}},"title":"Phase6 Reject Flow","startAt":"{{mrRejectStart}}","endAt":"{{mrRejectEnd}}"}' -TestScript ($helpers + @"
pm.test('setup reject 200', () => assertStatus(200));
pm.collectionVariables.set('rejectRequestId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'E3-3 U2 cannot reject' -Method POST -Path '/Calendar/MeetingRequest/Reject' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw '{"requestId":{{rejectRequestId}},"reason":"nope"}' -TestScript ($helpers + "pm.test('E3-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'E3-1 U3 reject' -Method POST -Path '/Calendar/MeetingRequest/Reject' -HeaderVars @('token_u3') -BodyMode raw -BodyRaw '{"requestId":{{rejectRequestId}},"reason":"busy week"}' -TestScript ($helpers + "pm.test('E3-1 200',()=>assertStatus(200)); pm.expect(pm.response.json()).to.eql(true);")),
    (Make-Request -Name 'E3-4 Already processed reject' -Method POST -Path '/Calendar/MeetingRequest/Reject' -HeaderVars @('token_u3') -BodyMode raw -BodyRaw '{"requestId":{{rejectRequestId}}}' -TestScript ($helpers + "pm.test('E3-4 400',()=>assertStatus(400));")),
    (Make-Request -Name 'Setup Create for cancel' -Method POST -Path '/Calendar/MeetingRequest' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"targetUserId":{{userId_u4}},"title":"Phase6 Cancel Flow","startAt":"{{mrCancelStart}}","endAt":"{{mrCancelEnd}}"}' -TestScript ($helpers + @"
pm.test('setup cancel 200', () => assertStatus(200));
pm.collectionVariables.set('cancelRequestId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'E7-3 U2 cannot cancel' -Method POST -Path '/Calendar/MeetingRequest/Cancel' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw '{"requestId":{{cancelRequestId}}}' -TestScript ($helpers + "pm.test('E7-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'E7-1 U1 cancel' -Method POST -Path '/Calendar/MeetingRequest/Cancel' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"requestId":{{cancelRequestId}}}' -TestScript ($helpers + "pm.test('E7-1 200',()=>assertStatus(200));")),
    (Make-Request -Name 'E7-4 Cancel not pending' -Method POST -Path '/Calendar/MeetingRequest/Cancel' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"requestId":{{cancelRequestId}}}' -TestScript ($helpers + "pm.test('E7-4 400',()=>assertStatus(400));"))
)

$collection = @{
    info = @{
        name = 'Calendar Phase 6 — MeetingRequest'
        description = 'E1-E7. Using test users from: references/postman-test-users.md. SMS priority for notifications.'
        schema = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    event = @(@{
        listen = 'prerequest'
        script = @{
            type = 'text/javascript'
            exec = @(
                "if (pm.collectionVariables.get('timesReady') === '1') { return; }",
                "const dayMs = 86400000;",
                "const slot = Math.floor(Date.now() / 60000);",
                "const base = Date.UTC(2034, 0, 10, 10, 0, 0);",
                "const start = new Date(base + (slot % 40000) * dayMs);",
                "function iso(d) { return d.toISOString().replace(/\\.\\d{3}Z$/, 'Z'); }",
                "function addHours(d,h){ return new Date(d.getTime()+h*3600000); }",
                "function addDays(d,n){ return new Date(d.getTime()+n*dayMs); }",
                "pm.collectionVariables.set('mrStart', iso(start));",
                "pm.collectionVariables.set('mrEnd', iso(addHours(start,1)));",
                "pm.collectionVariables.set('mrStart2', iso(addDays(start,2)));",
                "pm.collectionVariables.set('mrEnd2', iso(addHours(addDays(start,2),1)));",
                "pm.collectionVariables.set('mrRejectStart', iso(addDays(start,4)));",
                "pm.collectionVariables.set('mrRejectEnd', iso(addHours(addDays(start,4),1)));",
                "pm.collectionVariables.set('mrCancelStart', iso(addDays(start,6)));",
                "pm.collectionVariables.set('mrCancelEnd', iso(addHours(addDays(start,6),1)));",
                "pm.collectionVariables.set('timesReady','1');"
            )
        }
    })
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth },
        @{ name = '1. E1 Create'; item = $folderE1 },
        @{ name = '2. E4 E5 E6 Read'; item = $folderE4E5E6 },
        @{ name = '3. E2 Approve'; item = $folderE2 },
        @{ name = '4. E3 Reject + E7 Cancel'; item = $folderE3E7 }
    )
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' },
        @{ key = 'token_u1'; value = '' }, @{ key = 'token_u2'; value = '' },
        @{ key = 'token_u3'; value = '' }, @{ key = 'token_u4'; value = '' },
        @{ key = 'userId_u1'; value = '2746' }, @{ key = 'userId_u2'; value = '2747' },
        @{ key = 'userId_u3'; value = '2748' }, @{ key = 'userId_u4'; value = '2749' },
        @{ key = 'requestId'; value = '' }, @{ key = 'rejectRequestId'; value = '' },
        @{ key = 'cancelRequestId'; value = '' }, @{ key = 'approvedEventId'; value = '' },
        @{ key = 'mrStart'; value = '' }, @{ key = 'mrEnd'; value = '' },
        @{ key = 'mrStart2'; value = '' }, @{ key = 'mrEnd2'; value = '' },
        @{ key = 'mrRejectStart'; value = '' }, @{ key = 'mrRejectEnd'; value = '' },
        @{ key = 'mrCancelStart'; value = '' }, @{ key = 'mrCancelEnd'; value = '' },
        @{ key = 'timesReady'; value = '' }
    )
}

[System.IO.File]::WriteAllText($outPath, ($collection | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote $outPath"
