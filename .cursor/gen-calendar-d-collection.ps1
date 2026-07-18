$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-d-participants-collection.json'

function Make-Request {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Path,
        [string[]]$HeaderVars = @('token_u1'),
        [string]$BodyMode = $null,
        [string]$BodyRaw = $null,
        [string]$TestScript = ''
    )
    $headers = @()
    if ($HeaderVars -and $HeaderVars.Count -gt 0 -and $HeaderVars[0] -ne 'NONE') {
        foreach ($hv in $HeaderVars) {
            $headers += @{ key = 'Authorization'; value = "Bearer {{$hv}}" }
        }
    }

    $pathParts = @($Path.TrimStart('/') -split '/' | Where-Object { $_ -ne '' })
    $query = @()
    $rawPath = $Path
    if ($Path -match '\?') {
        $rawPath = ($Path -split '\?')[0]
        $qs = ($Path -split '\?', 2)[1]
        foreach ($pair in ($qs -split '&')) {
            if ($pair -match '^([^=]+)=(.*)$') {
                $query += @{ key = $Matches[1]; value = $Matches[2] }
            }
        }
        $pathParts = @($rawPath.TrimStart('/') -split '/' | Where-Object { $_ -ne '' })
    }

    $url = @{
        raw  = "{{baseUrl}}$Path"
        host = @('{{baseUrl}}')
        path = $pathParts
    }
    if ($query.Count -gt 0) { $url.query = $query }

    $req = @{
        method = $Method
        header = $headers
        url    = $url
    }

    if ($BodyMode -eq 'raw') {
        $req.body = @{
            mode = 'raw'
            raw  = $BodyRaw
            options = @{ raw = @{ language = 'json' } }
        }
        $req.header += @{ key = 'Content-Type'; value = 'application/json' }
    }

    $events = @()
    if ($TestScript) {
        $events += @{
            listen = 'test'
            script = @{
                type = 'text/javascript'
                exec = ($TestScript -split "`n")
            }
        }
    }

    return @{
        name    = $Name
        request = $req
        event   = $events
    }
}

$helpers = @'
function assertStatus(code) { pm.response.to.have.status(code); }
function assertHasDetail() {
    const j = pm.response.json();
    const hay = (j.detail || j.title || '');
    pm.expect(hay).to.be.a('string').and.not.empty;
}
'@

$device = @'
{
  "deviceID": "BE2A.250530.026.F3",
  "deviceName": "postman-test-device",
  "deviceVersion": "16",
  "appVersion": "2.113.0",
  "platform": "android"
}
'@

function Login-User([string]$label, [string]$username, [string]$tokenVar, [string]$userIdVar, [string]$expectedId) {
    $loginBody = @"
{
  "username": "$username",
  "password": "Test@12345",
  "deviceInfo": $device
}
"@
    $loginTest = @"
$helpers
pm.test('Login $label 200', () => assertStatus(200));
const loginJson = pm.response.json();
pm.test('Login $label token', () => pm.expect(loginJson.accessToken).to.be.a('string').and.not.empty);
pm.collectionVariables.set('$tokenVar', loginJson.accessToken);
"@
    $profileTest = @"
$helpers
pm.test('Profile $label 200', () => assertStatus(200));
const profile = pm.response.json();
pm.test('Profile $label userId', () => {
  pm.expect(profile.userId).to.be.a('number').above(0);
  pm.expect(profile.userId).to.eql($expectedId);
});
pm.collectionVariables.set('$userIdVar', profile.userId.toString());
"@
    return @(
        (Make-Request -Name "Login $label ($username)" -Method 'POST' -Path '/Auth/Login' -HeaderVars @('NONE') -BodyMode 'raw' -BodyRaw $loginBody -TestScript $loginTest),
        (Make-Request -Name "Profile $label" -Method 'GET' -Path '/chat/profile' -HeaderVars @($tokenVar) -TestScript $profileTest)
    )
}

$auth = @()
$auth += Login-User 'U1' 'chattest_sara' 'token_u1' 'userId_u1' '2746'
$auth += Login-User 'U2' 'chattest_reza' 'token_u2' 'userId_u2' '2747'
$auth += Login-User 'U3' 'chattest_nima' 'token_u3' 'userId_u3' '2748'
$auth += Login-User 'U4' 'chattest_kian' 'token_u4' 'userId_u4' '2749'

$setup = @(
    (Make-Request -Name 'Setup — U1 Calendar List' -Method 'GET' -Path '/Calendar/List' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('Setup list 200', () => assertStatus(200));
const list = pm.response.json();
const personal = list.find(c => c.type === 'Personal' && c.canWrite === true);
pm.expect(personal).to.exist;
pm.collectionVariables.set('calendarId', personal.id.toString());
"@)),
    (Make-Request -Name 'Setup — U1 Create main event' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{calendarId}},
  "title": "D Phase Main Meeting",
  "type": "Meeting",
  "startAt": "{{evtStart}}",
  "endAt": "{{evtEnd}}",
  "isAllDay": false,
  "isPersonal": false,
  "visibleOnlyToParticipants": false
}
'@ -TestScript ($helpers + @"
pm.test('Setup event 200', () => assertStatus(200));
const id = pm.response.json();
pm.expect(id).to.be.a('number').above(0);
pm.collectionVariables.set('eventId', id.toString());
"@)),
    (Make-Request -Name 'Setup — U1 Create private event' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{calendarId}},
  "title": "D Phase Private Meeting",
  "type": "Private",
  "startAt": "{{privateStart}}",
  "endAt": "{{privateEnd}}",
  "isAllDay": false,
  "isPersonal": true,
  "visibleOnlyToParticipants": true
}
'@ -TestScript ($helpers + @"
pm.test('Setup private event 200', () => assertStatus(200));
pm.collectionVariables.set('privateEventId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'Setup — U1 Create conflict slot event with U3' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{calendarId}},
  "title": "D Phase Busy Slot For U3",
  "type": "Meeting",
  "startAt": "{{conflictStart}}",
  "endAt": "{{conflictEnd}}",
  "isAllDay": false,
  "participantUserIds": [{{userId_u3}}]
}
'@ -TestScript ($helpers + @"
pm.test('Setup busy event 200', () => assertStatus(200));
pm.collectionVariables.set('busyEventId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'Setup — U1 Create overlap event (no U3)' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{calendarId}},
  "title": "D Phase Overlap Target",
  "type": "Meeting",
  "startAt": "{{overlapStart}}",
  "endAt": "{{overlapEnd}}",
  "isAllDay": false
}
'@ -TestScript ($helpers + @"
pm.test('Setup overlap event 200', () => assertStatus(200));
pm.collectionVariables.set('overlapEventId', pm.response.json().toString());
"@))
)

$folderD1 = @(
    (Make-Request -Name 'D1-1 — Valid add U2' -Method 'POST' -Path '/Calendar/Event/Participant' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"userIds":[{{userId_u2}}]}' -TestScript ($helpers + @"
pm.test('D1-1 status 200', () => assertStatus(200));
pm.test('D1-1 true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'D1-2 — Empty userIds 400' -Method 'POST' -Path '/Calendar/Event/Participant' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"userIds":[]}' -TestScript ($helpers + @"
pm.test('D1-2 status 400', () => assertStatus(400));
pm.test('D1-2 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D1-3 — Event not found 404' -Method 'POST' -Path '/Calendar/Event/Participant' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"eventId":999999,"userIds":[{{userId_u2}}]}' -TestScript ($helpers + @"
pm.test('D1-3 status 404', () => assertStatus(404));
pm.test('D1-3 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D1-4 — Invalid user 404' -Method 'POST' -Path '/Calendar/Event/Participant' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"userIds":[999999]}' -TestScript ($helpers + @"
pm.test('D1-4 status 404', () => assertStatus(404));
pm.test('D1-4 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D1-5 — U2 cannot add 403' -Method 'POST' -Path '/Calendar/Event/Participant' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"userIds":[{{userId_u4}}]}' -TestScript ($helpers + @"
pm.test('D1-5 status 403', () => assertStatus(403));
pm.test('D1-5 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D1-6 — Duplicate invite ignored 200' -Method 'POST' -Path '/Calendar/Event/Participant' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"userIds":[{{userId_u2}}]}' -TestScript ($helpers + @"
pm.test('D1-6 status 200', () => assertStatus(200));
pm.test('D1-6 true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'D1-7 — Invitee busy 409' -Method 'POST' -Path '/Calendar/Event/Participant' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"eventId":{{overlapEventId}},"userIds":[{{userId_u3}}]}' -TestScript ($helpers + @"
pm.test('D1-7 status 409', () => assertStatus(409));
pm.test('D1-7 detail', () => assertHasDetail());
"@))
)

$folderD2 = @(
    (Make-Request -Name 'D2-3 — U3 cannot remove 403' -Method 'DELETE' -Path '/Calendar/Event/Participant?eventId={{eventId}}&userId={{userId_u2}}' -HeaderVars @('token_u3') -TestScript ($helpers + @"
pm.test('D2-3 status 403', () => assertStatus(403));
pm.test('D2-3 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D2-1 — Valid remove U2' -Method 'DELETE' -Path '/Calendar/Event/Participant?eventId={{eventId}}&userId={{userId_u2}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('D2-1 status 200', () => assertStatus(200));
pm.test('D2-1 true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'D2-2 — Participant not found 404' -Method 'DELETE' -Path '/Calendar/Event/Participant?eventId={{eventId}}&userId={{userId_u2}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('D2-2 status 404', () => assertStatus(404));
pm.test('D2-2 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D2-ReAdd — Restore U2 for RSVP' -Method 'POST' -Path '/Calendar/Event/Participant' -HeaderVars @('token_u1') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"userIds":[{{userId_u2}}]}' -TestScript ($helpers + @"
pm.test('D2-ReAdd status 200', () => assertStatus(200));
pm.test('D2-ReAdd true', () => pm.expect(pm.response.json()).to.eql(true));
"@))
)

$folderD3 = @(
    (Make-Request -Name 'D3-1 — U2 Accepted 200' -Method 'POST' -Path '/Calendar/Event/Respond' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"response":"Accepted"}' -TestScript ($helpers + @"
pm.test('D3-1 status 200', () => assertStatus(200));
pm.test('D3-1 true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'D3-2 — Invalid response 400' -Method 'POST' -Path '/Calendar/Event/Respond' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"response":"Nope"}' -TestScript ($helpers + @"
pm.test('D3-2 status 400', () => assertStatus(400));
pm.test('D3-2 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D3-3 — Event not found 404' -Method 'POST' -Path '/Calendar/Event/Respond' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw '{"eventId":999999,"response":"Maybe"}' -TestScript ($helpers + @"
pm.test('D3-3 status 404', () => assertStatus(404));
pm.test('D3-3 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D3-4 — U3 not invited 403' -Method 'POST' -Path '/Calendar/Event/Respond' -HeaderVars @('token_u3') -BodyMode 'raw' -BodyRaw '{"eventId":{{eventId}},"response":"Declined"}' -TestScript ($helpers + @"
pm.test('D3-4 status 403', () => assertStatus(403));
pm.test('D3-4 detail', () => assertHasDetail());
"@))
)

$folderD4 = @(
    (Make-Request -Name 'D4-1 — List participants 200' -Method 'GET' -Path '/Calendar/Event/{{eventId}}/Participants' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('D4-1 status 200', () => assertStatus(200));
const list = pm.response.json();
pm.test('D4-1 array', () => pm.expect(list).to.be.an('array').that.is.not.empty);
const u2 = list.find(p => p.userId === Number(pm.collectionVariables.get('userId_u2')));
pm.test('D4-1 U2 Accepted', () => {
  pm.expect(u2).to.exist;
  pm.expect(u2.response).to.eql('Accepted');
  pm.expect(u2.fullName).to.be.a('string').and.not.empty;
});
"@)),
    (Make-Request -Name 'D4-2 — Event not found 404' -Method 'GET' -Path '/Calendar/Event/999999/Participants' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('D4-2 status 404', () => assertStatus(404));
pm.test('D4-2 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'D4-3 — U4 cannot view private 403' -Method 'GET' -Path '/Calendar/Event/{{privateEventId}}/Participants' -HeaderVars @('token_u4') -TestScript ($helpers + @"
pm.test('D4-3 status 403', () => assertStatus(403));
pm.test('D4-3 detail', () => assertHasDetail());
"@))
)

$collection = @{
    info = @{
        name        = 'Calendar Group D — Participants Integration'
        description = 'D1-D4 participants/RSVP. Using test users from: references/postman-test-users.md'
        schema      = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    event = @(
        @{
            listen = 'prerequest'
            script = @{
                type = 'text/javascript'
                exec = @(
                    "if (pm.collectionVariables.get('timesReady') === '1') { return; }",
                    "const dayMs = 86400000;",
                    "const slot = Math.floor(Date.now() / 60000);",
                    "const base = Date.UTC(2032, 5, 1, 9, 0, 0);",
                    "const start = new Date(base + (slot % 50000) * dayMs);",
                    "function iso(d) { return d.toISOString().replace(/\\.\\d{3}Z$/, 'Z'); }",
                    "function addHours(d, h) { return new Date(d.getTime() + h * 3600000); }",
                    "function addDays(d, n) { return new Date(d.getTime() + n * dayMs); }",
                    "pm.collectionVariables.set('evtStart', iso(start));",
                    "pm.collectionVariables.set('evtEnd', iso(addHours(start, 1)));",
                    "// Busy U3 window completely covers overlap window",
                    "pm.collectionVariables.set('conflictStart', iso(addHours(start, 2)));",
                    "pm.collectionVariables.set('conflictEnd', iso(addHours(start, 4)));",
                    "pm.collectionVariables.set('overlapStart', iso(addHours(start, 2.5)));",
                    "pm.collectionVariables.set('overlapEnd', iso(addHours(start, 3.5)));",
                    "pm.collectionVariables.set('privateStart', iso(addDays(start, 3)));",
                    "pm.collectionVariables.set('privateEnd', iso(addHours(addDays(start, 3), 1)));",
                    "pm.collectionVariables.set('timesReady', '1');"
                )
            }
        }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth },
        @{ name = '1. Setup Events'; item = $setup },
        @{ name = '2. D1 Add Participants'; item = $folderD1 },
        @{ name = '3. D2 Remove Participant'; item = $folderD2 },
        @{ name = '4. D3 Respond'; item = $folderD3 },
        @{ name = '5. D4 List Participants'; item = $folderD4 }
    )
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' },
        @{ key = 'token_u1'; value = '' },
        @{ key = 'token_u2'; value = '' },
        @{ key = 'token_u3'; value = '' },
        @{ key = 'token_u4'; value = '' },
        @{ key = 'userId_u1'; value = '2746' },
        @{ key = 'userId_u2'; value = '2747' },
        @{ key = 'userId_u3'; value = '2748' },
        @{ key = 'userId_u4'; value = '2749' },
        @{ key = 'calendarId'; value = '' },
        @{ key = 'eventId'; value = '' },
        @{ key = 'privateEventId'; value = '' },
        @{ key = 'busyEventId'; value = '' },
        @{ key = 'overlapEventId'; value = '' },
        @{ key = 'evtStart'; value = '' },
        @{ key = 'evtEnd'; value = '' },
        @{ key = 'conflictStart'; value = '' },
        @{ key = 'conflictEnd'; value = '' },
        @{ key = 'overlapStart'; value = '' },
        @{ key = 'overlapEnd'; value = '' },
        @{ key = 'privateStart'; value = '' },
        @{ key = 'privateEnd'; value = '' },
        @{ key = 'timesReady'; value = '' }
    )
}

$json = $collection | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($outPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote $outPath"
