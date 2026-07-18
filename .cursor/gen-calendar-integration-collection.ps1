$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-integration-collection.json'

function New-Uuid { return [guid]::NewGuid().ToString() }

function Make-Request {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Path,
        [string[]]$HeaderVars = @('token_admin'),
        [hashtable]$ExtraHeaders = @{},
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
    foreach ($k in $ExtraHeaders.Keys) {
        $headers += @{ key = $k; value = $ExtraHeaders[$k] }
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
        $hasContentType = $headers | Where-Object { $_.key -eq 'Content-Type' }
        if (-not $hasContentType) {
            $req.header += @{ key = 'Content-Type'; value = 'application/json' }
        }
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

# ASCII-only helpers — avoid Persian literals (PowerShell ConvertTo-Json mangles UTF-8)
$helpers = @'
function responseText() {
    try { return JSON.stringify(pm.response.json()); }
    catch (e) { return pm.response.text(); }
}
function assertStatus(code) {
    pm.response.to.have.status(code);
}
function assertHasDetail() {
    const j = pm.response.json();
    const hay = (j.detail || j.title || '');
    pm.expect(hay).to.be.a('string').and.not.empty;
}
'@

$device = @'
{
  "deviceID": "BE2A.250530.026.F3",
  "deviceName": "postman-calendar-it",
  "deviceVersion": "16",
  "appVersion": "2.113.0",
  "platform": "android"
}
'@

function Login-User([string]$label, [string]$username, [string]$password, [string]$tokenVar, [string]$userIdVar) {
    $loginBody = @"
{
  "username": "$username",
  "password": "$password",
  "deviceInfo": $device
}
"@
    $loginTest = @"
$helpers
pm.test('Login $label returns 200', function () { assertStatus(200); });
const loginJson = pm.response.json();
pm.test('Login $label has accessToken', function () {
    pm.expect(loginJson.accessToken).to.be.a('string').and.not.empty;
});
pm.collectionVariables.set('$tokenVar', loginJson.accessToken);
"@
    $profileTest = @"
$helpers
pm.test('Profile $label returns 200', function () { assertStatus(200); });
const profile = pm.response.json();
pm.test('Profile $label has userId', function () {
    pm.expect(profile.userId).to.be.a('number').above(0);
});
pm.collectionVariables.set('$userIdVar', profile.userId.toString());
"@
    return @(
        (Make-Request -Name "Login $label ($username)" -Method 'POST' -Path '/Auth/Login' -HeaderVars @('NONE') -BodyMode 'raw' -BodyRaw $loginBody -TestScript $loginTest),
        (Make-Request -Name "Profile $label" -Method 'GET' -Path '/chat/profile' -HeaderVars @($tokenVar) -TestScript $profileTest)
    )
}

# ========== 0. Auth ==========
$auth = @()
$auth += Login-User 'Admin' 'a.kashani' '123456' 'token_admin' 'userId_admin'
$auth += Login-User 'Sara' 'chattest_sara' 'Test@12345' 'token_sara' 'userId_sara'
$auth += Login-User 'Reza' 'chattest_reza' 'Test@12345' 'token_reza' 'userId_reza'

# ========== A1 List ==========
$folderA1 = @(
    (Make-Request -Name 'A1-1 — List auto-create personal' -Method 'GET' -Path '/Calendar/List' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('A1-1 status 200', () => assertStatus(200));
const list = pm.response.json();
pm.test('A1-1 returns array', () => pm.expect(list).to.be.an('array').that.is.not.empty);
const personal = list.find(c => c.type === 'Personal' && c.canWrite === true);
pm.test('A1-1 has personal writable calendar', () => pm.expect(personal).to.exist);
pm.collectionVariables.set('personalCalendarId', personal.id.toString());
pm.collectionVariables.set('defaultPersonalCalendarId', personal.id.toString());
"@)),
    (Make-Request -Name 'A1-2 — List multiple calendars' -Method 'GET' -Path '/Calendar/List' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('A1-2 status 200', () => assertStatus(200));
pm.test('A1-2 array', () => pm.expect(pm.response.json()).to.be.an('array'));
"@)),
    (Make-Request -Name 'A1-3 — No token 401' -Method 'GET' -Path '/Calendar/List' -HeaderVars @('NONE') -TestScript @"
pm.test('A1-3 status 401', () => pm.response.to.have.status(401));
"@)
)

# ========== A2 Create ==========
$folderA2 = @(
    (Make-Request -Name 'A2-1 — Create Personal happy' -Method 'POST' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"title":"IT Extra Personal Cal","type":"Personal","color":"#00BCD4"}' -TestScript ($helpers + @"
pm.test('A2-1 status 200', () => assertStatus(200));
const id = pm.response.json();
pm.test('A2-1 returns int id', () => pm.expect(id).to.be.a('number').above(0));
pm.collectionVariables.set('extraCalendarId', id.toString());
"@)),
    (Make-Request -Name 'A2-2 — Empty title 400' -Method 'POST' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"title":"","type":"Personal"}' -TestScript ($helpers + @"
pm.test('A2-2 status 400', () => assertStatus(400));
pm.test('A2-2 title required', () => assertHasDetail());
"@)),
    (Make-Request -Name 'A2-3 — Title too short 400' -Method 'POST' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"title":"A","type":"Personal"}' -TestScript ($helpers + @"
pm.test('A2-3 status 400', () => assertStatus(400));
pm.test('A2-3 min length', () => assertHasDetail());
"@)),
    (Make-Request -Name 'A2-4 — Unit without orgPositionId 400' -Method 'POST' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"title":"Unit No Pos","type":"Unit"}' -TestScript ($helpers + @"
pm.test('A2-4 status 400', () => assertStatus(400));
pm.test('A2-4 org required', () => assertHasDetail());
"@)),
    (Make-Request -Name 'A2-5 — Unit missing position 404' -Method 'POST' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"title":"Unit Bad Pos","type":"Unit","orgPositionId":999999}' -TestScript ($helpers + @"
pm.test('A2-5 status 404', () => assertStatus(404));
pm.test('A2-5 not found', () => assertHasDetail());
"@)),
    (Make-Request -Name 'A2-6 — Organization forbidden 403' -Method 'POST' -Path '/Calendar' -HeaderVars @('token_sara') -BodyMode 'raw' -BodyRaw '{"title":"Org Forbidden","type":"Organization"}' -TestScript ($helpers + @"
pm.test('A2-6 status 403', () => assertStatus(403));
pm.test('A2-6 forbidden', () => assertHasDetail());
"@))
)

# ========== A3 Update ==========
$folderA3 = @(
    (Make-Request -Name 'A3-1 — Update calendar happy' -Method 'PUT' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"id":{{extraCalendarId}},"title":"IT Extra Personal Updated","color":"#009688"}' -TestScript ($helpers + @"
pm.test('A3-1 status 200', () => assertStatus(200));
pm.test('A3-1 body true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'A3-2 — Invalid title 400' -Method 'PUT' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"id":{{extraCalendarId}},"title":"X"}' -TestScript ($helpers + @"
pm.test('A3-2 status 400', () => assertStatus(400));
"@)),
    (Make-Request -Name 'A3-3 — Calendar not found 404' -Method 'PUT' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"id":999999,"title":"Missing Cal"}' -TestScript ($helpers + @"
pm.test('A3-3 status 404', () => assertStatus(404));
pm.test('A3-3 not found', () => assertHasDetail());
"@)),
    (Make-Request -Name 'A3-4 — Edit forbidden 403' -Method 'PUT' -Path '/Calendar' -HeaderVars @('token_sara') -BodyMode 'raw' -BodyRaw '{"id":{{extraCalendarId}},"title":"Hack Edit"}' -TestScript ($helpers + @"
pm.test('A3-4 status 403', () => assertStatus(403));
pm.test('A3-4 forbidden', () => assertHasDetail());
"@))
)

# ========== A4 Delete (keep default personal; delete only extras later after events) ==========
$folderA4Setup = @(
    (Make-Request -Name 'A4-Setup — Create disposable calendar' -Method 'POST' -Path '/Calendar' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"title":"Disposable Cal For Delete","type":"Personal"}' -TestScript ($helpers + @"
pm.test('A4-Setup status 200', () => assertStatus(200));
pm.collectionVariables.set('disposableCalendarId', pm.response.json().toString());
"@))
)

$folderA4 = @(
    (Make-Request -Name 'A4-1 — Delete authorized calendar 200' -Method 'DELETE' -Path '/Calendar/{{disposableCalendarId}}' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('A4-1 status 200', () => assertStatus(200));
pm.test('A4-1 true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'A4-2 — Delete missing 404' -Method 'DELETE' -Path '/Calendar/999999' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('A4-2 status 404', () => assertStatus(404));
pm.test('A4-2 not found', () => assertHasDetail());
"@)),
    (Make-Request -Name 'A4-3 — Delete forbidden 403' -Method 'DELETE' -Path '/Calendar/{{extraCalendarId}}' -HeaderVars @('token_sara') -TestScript ($helpers + @"
pm.test('A4-3 status 403', () => assertStatus(403));
pm.test('A4-3 forbidden', () => assertHasDetail());
"@)),
    (Make-Request -Name 'A4-4 — Default personal cannot delete 400' -Method 'DELETE' -Path '/Calendar/{{defaultPersonalCalendarId}}' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('A4-4 status 400', () => assertStatus(400));
pm.test('A4-4 cannot delete default', () => assertHasDetail());
"@))
)

# ========== B1 Create Event ==========
$folderB1 = @(
    (Make-Request -Name 'B1-1 — Create event happy' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{personalCalendarId}},
  "title": "IT Project Review",
  "description": "Sprint review",
  "type": "Meeting",
  "location": "Room 2",
  "startAt": "2027-03-15T09:00:00Z",
  "endAt": "2027-03-15T10:00:00Z",
  "isAllDay": false,
  "isPersonal": false,
  "visibleOnlyToParticipants": false,
  "participantUserIds": [{{userId_sara}}],
  "reminders": [{ "offsetMinutes": 15, "channel": "Sms" }]
}
'@ -TestScript ($helpers + @"
pm.test('B1-1 status 200', () => assertStatus(200));
const id = pm.response.json();
pm.test('B1-1 event id', () => pm.expect(id).to.be.a('number').above(0));
pm.collectionVariables.set('eventId', id.toString());
"@)),
    (Make-Request -Name 'B1-2 — Empty title 400' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"","type":"Meeting","startAt":"2026-08-11T09:00:00Z","endAt":"2026-08-11T10:00:00Z"}' -TestScript ($helpers + @"
pm.test('B1-2 status 400', () => assertStatus(400));
pm.test('B1-2 title required', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-3 — endAt <= startAt 400' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Bad Range","type":"Meeting","startAt":"2026-08-11T10:00:00Z","endAt":"2026-08-11T09:00:00Z"}' -TestScript ($helpers + @"
pm.test('B1-3 status 400', () => assertStatus(400));
pm.test('B1-3 invalid range', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-4 — Description too long 400' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{personalCalendarId}},
  "title": "Long Desc",
  "description": "{{longDesc}}",
  "type": "Meeting",
  "startAt": "2026-08-12T09:00:00Z",
  "endAt": "2026-08-12T10:00:00Z"
}
'@ -TestScript ($helpers + @"
// longDesc injected via prerequest replacement — build in test if needed
pm.test('B1-4 status 400', () => assertStatus(400));
pm.test('B1-4 max 2048', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-6 — Calendar not found 404' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":999999,"title":"No Cal","type":"Meeting","startAt":"2026-08-13T09:00:00Z","endAt":"2026-08-13T10:00:00Z"}' -TestScript ($helpers + @"
pm.test('B1-6 status 404', () => assertStatus(404));
pm.test('B1-6 not found', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-7 — Write forbidden 403' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_sara') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Sara Insert","type":"Meeting","startAt":"2026-08-14T09:00:00Z","endAt":"2026-08-14T10:00:00Z"}' -TestScript ($helpers + @"
pm.test('B1-7 status 403', () => assertStatus(403));
pm.test('B1-7 forbidden', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-8 — Invitee not found 404' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Bad Invitee","type":"Meeting","startAt":"2026-08-15T09:00:00Z","endAt":"2026-08-15T10:00:00Z","participantUserIds":[999999]}' -TestScript ($helpers + @"
pm.test('B1-8 status 404', () => assertStatus(404));
pm.test('B1-8 invitee', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-9 — Conflict 409' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Conflict Event","type":"Meeting","startAt":"2027-03-15T09:30:00Z","endAt":"2027-03-15T10:30:00Z","participantUserIds":[{{userId_sara}}]}' -TestScript ($helpers + @"
pm.test('B1-9 status 409', () => assertStatus(409));
pm.test('B1-9 conflict msg', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-10 — Negative reminder 400' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Bad Reminder","type":"Meeting","startAt":"2026-08-16T09:00:00Z","endAt":"2026-08-16T10:00:00Z","reminders":[{"offsetMinutes":-5,"channel":"Sms"}]}' -TestScript ($helpers + @"
pm.test('B1-10 status 400', () => assertStatus(400));
pm.test('B1-10 reminder', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-Recur — Invalid recurrence (both ends) 400' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Bad Recur","type":"Meeting","startAt":"2026-08-17T09:00:00Z","endAt":"2026-08-17T10:00:00Z","recurrence":{"type":"Daily","interval":1,"endDate":"2026-09-01T00:00:00Z","occurrenceCount":5}}' -TestScript ($helpers + @"
pm.test('B1-Recur status 400', () => assertStatus(400));
pm.test('B1-Recur invalid', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B1-RecurOK — Weekly recurring event' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{personalCalendarId}},
  "title": "Weekly Standup",
  "type": "Meeting",
  "startAt": "2027-03-01T08:00:00Z",
  "endAt": "2027-03-01T09:00:00Z",
  "recurrence": { "type": "Weekly", "interval": 1, "weekDays": [1], "occurrenceCount": 4 }
}
'@ -TestScript ($helpers + @"
pm.test('B1-RecurOK status 200', () => assertStatus(200));
pm.collectionVariables.set('recurringEventId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'B1-Private — VisibleOnly event' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Private Visible Only","type":"Private","startAt":"2027-03-22T09:00:00Z","endAt":"2027-03-22T10:00:00Z","visibleOnlyToParticipants":true,"participantUserIds":[{{userId_reza}}]}' -TestScript ($helpers + @"
pm.test('B1-Private status 200', () => assertStatus(200));
pm.collectionVariables.set('privateEventId', pm.response.json().toString());
"@))
)

# Fix B1-4: use prerequest to set long description — rewrite as separate request with event
$b14Prerequest = @'
const long = 'X'.repeat(2049);
const body = {
  calendarId: parseInt(pm.collectionVariables.get('personalCalendarId'), 10),
  title: 'Long Desc',
  description: long,
  type: 'Meeting',
  startAt: '2026-08-12T09:00:00Z',
  endAt: '2026-08-12T10:00:00Z'
};
pm.request.body.update(JSON.stringify(body));
'@

$folderB1[3] = @{
    name = 'B1-4 — Description too long 400'
    request = @{
        method = 'POST'
        header = @(
            @{ key = 'Authorization'; value = 'Bearer {{token_admin}}' },
            @{ key = 'Content-Type'; value = 'application/json' }
        )
        body = @{ mode = 'raw'; raw = '{}'; options = @{ raw = @{ language = 'json' } } }
        url = @{
            raw  = '{{baseUrl}}/Calendar/Event'
            host = @('{{baseUrl}}')
            path = @('Calendar', 'Event')
        }
    }
    event = @(
        @{
            listen = 'prerequest'
            script = @{ type = 'text/javascript'; exec = ($b14Prerequest -split "`n") }
        },
        @{
            listen = 'test'
            script = @{
                type = 'text/javascript'
                exec = (($helpers + @"
pm.test('B1-4 status 400', () => assertStatus(400));
pm.test('B1-4 max 2048', () => assertHasDetail());
"@) -split "`n")
            }
        }
    )
}

# ========== B2 Update ==========
$folderB2 = @(
    (Make-Request -Name 'B2-1 — Non-recurring edit 200' -Method 'PUT' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw @'
{
  "id": {{eventId}},
  "calendarId": {{personalCalendarId}},
  "title": "IT Project Review Edited",
  "description": "Updated",
  "type": "Meeting",
  "startAt": "2027-03-15T09:00:00Z",
  "endAt": "2027-03-15T10:30:00Z",
  "editScope": "All"
}
'@ -TestScript ($helpers + @"
pm.test('B2-1 status 200', () => assertStatus(200));
pm.test('B2-1 true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'B2-2 — Recurring ThisOnly 200' -Method 'PUT' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw @'
{
  "id": {{recurringEventId}},
  "calendarId": {{personalCalendarId}},
  "title": "Weekly Standup",
  "type": "Meeting",
  "startAt": "2027-03-08T08:00:00Z",
  "endAt": "2027-03-15T09:00:00Z",
  "editScope": "ThisOnly",
  "occurrenceDate": "2027-03-08T00:00:00Z"
}
'@ -TestScript ($helpers + @"
pm.test('B2-2 status 200', () => assertStatus(200));
pm.test('B2-2 true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'B2-4 — Recurring All 200' -Method 'PUT' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw @'
{
  "id": {{recurringEventId}},
  "calendarId": {{personalCalendarId}},
  "title": "Weekly Standup All",
  "type": "Meeting",
  "startAt": "2027-03-01T08:00:00Z",
  "endAt": "2027-03-01T09:00:00Z",
  "editScope": "All",
  "recurrence": { "type": "Weekly", "interval": 1, "weekDays": [1], "occurrenceCount": 4 }
}
'@ -TestScript ($helpers + @"
pm.test('B2-4 status 200', () => assertStatus(200));
"@)),
    (Make-Request -Name 'B2-6 — Missing occurrenceDate 400' -Method 'PUT' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw @'
{
  "id": {{recurringEventId}},
  "calendarId": {{personalCalendarId}},
  "title": "Weekly Standup",
  "type": "Meeting",
  "startAt": "2027-03-01T08:00:00Z",
  "endAt": "2027-03-01T09:00:00Z",
  "editScope": "ThisOnly"
}
'@ -TestScript ($helpers + @"
pm.test('B2-6 status 400', () => assertStatus(400));
pm.test('B2-6 occurrence required', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B2-7 — Event not found 404' -Method 'PUT' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"id":999999,"calendarId":{{personalCalendarId}},"title":"Missing","type":"Meeting","startAt":"2026-08-21T09:00:00Z","endAt":"2026-08-21T10:00:00Z"}' -TestScript ($helpers + @"
pm.test('B2-7 status 404', () => assertStatus(404));
pm.test('B2-7 not found', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B2-8 — Edit forbidden 403' -Method 'PUT' -Path '/Calendar/Event' -HeaderVars @('token_sara') -BodyMode 'raw' -BodyRaw '{"id":{{eventId}},"calendarId":{{personalCalendarId}},"title":"Hack","type":"Meeting","startAt":"2027-03-15T09:00:00Z","endAt":"2027-03-15T10:00:00Z"}' -TestScript ($helpers + @"
pm.test('B2-8 status 403', () => assertStatus(403));
pm.test('B2-8 forbidden', () => assertHasDetail());
"@))
)

# ========== B4 Get ==========
$folderB4 = @(
    (Make-Request -Name 'B4-1 — Get event detail 200' -Method 'GET' -Path '/Calendar/Event/{{eventId}}' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B4-1 status 200', () => assertStatus(200));
const e = pm.response.json();
pm.test('B4-1 has title', () => pm.expect(e.title).to.be.a('string').and.not.empty);
pm.test('B4-1 participants', () => pm.expect(e.participants).to.be.an('array'));
"@)),
    (Make-Request -Name 'B4-2 — Event not found 404' -Method 'GET' -Path '/Calendar/Event/999999' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B4-2 status 404', () => assertStatus(404));
pm.test('B4-2 not found', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B4-3 — Visible only forbidden 403' -Method 'GET' -Path '/Calendar/Event/{{privateEventId}}' -HeaderVars @('token_sara') -TestScript ($helpers + @"
pm.test('B4-3 status 403', () => assertStatus(403));
pm.test('B4-3 view forbidden', () => assertHasDetail());
"@))
)

# ========== B5 Range ==========
$folderB5 = @(
    (Make-Request -Name 'B5-1 — Empty far future range 200' -Method 'GET' -Path '/Calendar/Range?from=2028-01-01T00:00:00Z&to=2028-01-07T00:00:00Z&includeTaskDeadlines=false' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B5-1 status 200', () => assertStatus(200));
pm.test('B5-1 array', () => pm.expect(pm.response.json()).to.be.an('array'));
"@)),
    (Make-Request -Name 'B5-2 — Range with events 200' -Method 'GET' -Path '/Calendar/Range?from=2027-03-01T00:00:00Z&to=2027-03-31T00:00:00Z&includeTaskDeadlines=true' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B5-2 status 200', () => assertStatus(200));
const items = pm.response.json();
pm.test('B5-2 has items', () => pm.expect(items).to.be.an('array').that.is.not.empty);
pm.test('B5-2 has Event kind', () => pm.expect(items.some(i => i.kind === 'Event')).to.be.true);
"@)),
    (Make-Request -Name 'B5-3 — includeTaskDeadlines=false' -Method 'GET' -Path '/Calendar/Range?from=2027-03-01T00:00:00Z&to=2027-03-31T00:00:00Z&includeTaskDeadlines=false' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B5-3 status 200', () => assertStatus(200));
const items = pm.response.json();
pm.test('B5-3 no TaskDeadline', () => pm.expect(items.every(i => i.kind !== 'TaskDeadline')).to.be.true);
"@)),
    (Make-Request -Name 'B5-4 — Recurring expansion' -Method 'GET' -Path '/Calendar/Range?from=2027-03-01T00:00:00Z&to=2027-03-31T00:00:00Z&includeTaskDeadlines=false' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B5-4 status 200', () => assertStatus(200));
const items = pm.response.json();
const rid = parseInt(pm.collectionVariables.get('recurringEventId'), 10);
const occ = items.filter(i => i.eventId === rid);
pm.test('B5-4 multiple occurrences', () => pm.expect(occ.length).to.be.above(1));
pm.test('B5-4 has occurrenceDate', () => pm.expect(occ.some(i => i.occurrenceDate)).to.be.true);
"@)),
    (Make-Request -Name 'B5-5 — to <= from 400' -Method 'GET' -Path '/Calendar/Range?from=2027-03-08T00:00:00Z&to=2026-08-01T00:00:00Z' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B5-5 status 400', () => assertStatus(400));
pm.test('B5-5 invalid range', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B5-6 — Range > 92 days 400' -Method 'GET' -Path '/Calendar/Range?from=2026-01-01T00:00:00Z&to=2026-05-01T00:00:00Z' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B5-6 status 400', () => assertStatus(400));
pm.test('B5-6 too large', () => assertHasDetail());
"@))
)

# ========== B3 Delete (after B4/B5 so get/range still work) ==========
$folderB3Setup = @(
    (Make-Request -Name 'B3-Setup — Disposable non-recurring event' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Delete Me Soon","type":"Info","startAt":"2026-09-01T09:00:00Z","endAt":"2026-09-01T10:00:00Z"}' -TestScript ($helpers + @"
pm.test('B3-Setup status 200', () => assertStatus(200));
pm.collectionVariables.set('deleteEventId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'B3-Setup — Disposable recurring for ThisOnly' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_admin') -BodyMode 'raw' -BodyRaw '{"calendarId":{{personalCalendarId}},"title":"Delete Occ","type":"Meeting","startAt":"2026-09-07T08:00:00Z","endAt":"2026-09-07T09:00:00Z","recurrence":{"type":"Weekly","interval":1,"weekDays":[1],"occurrenceCount":3}}' -TestScript ($helpers + @"
pm.test('B3-Setup recur status 200', () => assertStatus(200));
pm.collectionVariables.set('deleteRecurEventId', pm.response.json().toString());
"@))
)

$folderB3 = @(
    (Make-Request -Name 'B3-1 — Delete non-recurring 200' -Method 'DELETE' -Path '/Calendar/Event?id={{deleteEventId}}&editScope=All' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B3-1 status 200', () => assertStatus(200));
pm.test('B3-1 true', () => pm.expect(pm.response.json()).to.eql(true));
"@)),
    (Make-Request -Name 'B3-2 — Recurring ThisOnly cancel 200' -Method 'DELETE' -Path '/Calendar/Event?id={{deleteRecurEventId}}&editScope=ThisOnly&occurrenceDate=2026-09-14T00:00:00Z' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B3-2 status 200', () => assertStatus(200));
"@)),
    (Make-Request -Name 'B3-4 — Recurring All delete 200' -Method 'DELETE' -Path '/Calendar/Event?id={{deleteRecurEventId}}&editScope=All' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B3-4 status 200', () => assertStatus(200));
"@)),
    (Make-Request -Name 'B3-5 — Missing occurrenceDate 400' -Method 'DELETE' -Path '/Calendar/Event?id={{recurringEventId}}&editScope=ThisOnly' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B3-5 status 400', () => assertStatus(400));
pm.test('B3-5 occurrence', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B3-6 — Event not found 404' -Method 'DELETE' -Path '/Calendar/Event?id=999999&editScope=All' -HeaderVars @('token_admin') -TestScript ($helpers + @"
pm.test('B3-6 status 404', () => assertStatus(404));
pm.test('B3-6 not found', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B3-7 — Delete forbidden 403' -Method 'DELETE' -Path '/Calendar/Event?id={{eventId}}&editScope=All' -HeaderVars @('token_sara') -TestScript ($helpers + @"
pm.test('B3-7 status 403', () => assertStatus(403));
pm.test('B3-7 forbidden', () => assertHasDetail());
"@))
)

$collection = @{
    info = @{
        _postman_id = (New-Uuid)
        name        = 'Elay Customer — Calendar Integration (Groups A+B)'
        description = 'Integration scenarios A1-B5 from 02-Calendar-Scenarios.md for implemented Calendar APIs. Run Auth first. baseUrl=http://localhost:5144'
        schema      = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' },
        @{ key = 'token_admin'; value = '' },
        @{ key = 'token_sara'; value = '' },
        @{ key = 'token_reza'; value = '' },
        @{ key = 'userId_admin'; value = '' },
        @{ key = 'userId_sara'; value = '' },
        @{ key = 'userId_reza'; value = '' },
        @{ key = 'personalCalendarId'; value = '' },
        @{ key = 'defaultPersonalCalendarId'; value = '' },
        @{ key = 'extraCalendarId'; value = '' },
        @{ key = 'disposableCalendarId'; value = '' },
        @{ key = 'eventId'; value = '' },
        @{ key = 'recurringEventId'; value = '' },
        @{ key = 'privateEventId'; value = '' },
        @{ key = 'deleteEventId'; value = '' },
        @{ key = 'deleteRecurEventId'; value = '' }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth }
        @{ name = 'A1. Calendar List'; item = $folderA1 }
        @{ name = 'A2. Calendar Create'; item = $folderA2 }
        @{ name = 'A3. Calendar Update'; item = $folderA3 }
        @{ name = 'A4. Calendar Delete Setup'; item = $folderA4Setup }
        @{ name = 'A4. Calendar Delete'; item = $folderA4 }
        @{ name = 'B1. Event Create'; item = $folderB1 }
        @{ name = 'B2. Event Update'; item = $folderB2 }
        @{ name = 'B4. Event Get'; item = $folderB4 }
        @{ name = 'B5. Calendar Range'; item = $folderB5 }
        @{ name = 'B3. Event Delete Setup'; item = $folderB3Setup }
        @{ name = 'B3. Event Delete'; item = $folderB3 }
    )
}

$json = $collection | ConvertTo-Json -Depth 100 -Compress:$false
[System.IO.File]::WriteAllText($outPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output "Written: $outPath ($((Get-Item $outPath).Length) bytes)"
