$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-phase5-collection.json'

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
    if ($HeaderVars -and $HeaderVars[0] -ne 'NONE') {
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

function Login-User([string]$label, [string]$username, [string]$tokenVar, [string]$userIdVar, [string]$expectedId) {
    $loginBody = "{`"username`":`"$username`",`"password`":`"Test@12345`",`"deviceInfo`":$device}"
    $loginTest = @"
$helpers
pm.test('Login $label 200', () => assertStatus(200));
pm.collectionVariables.set('$tokenVar', pm.response.json().accessToken);
"@
    $profileTest = @"
$helpers
pm.test('Profile $label 200', () => assertStatus(200));
const p = pm.response.json();
pm.expect(p.userId).to.eql($expectedId);
pm.collectionVariables.set('$userIdVar', p.userId.toString());
"@
    return @(
        (Make-Request -Name "Login $label" -Method 'POST' -Path '/Auth/Login' -HeaderVars @('NONE') -BodyMode 'raw' -BodyRaw $loginBody -TestScript $loginTest),
        (Make-Request -Name "Profile $label" -Method 'GET' -Path '/chat/profile' -HeaderVars @($tokenVar) -TestScript $profileTest)
    )
}

$auth = @()
$auth += Login-User 'U1' 'chattest_sara' 'token_u1' 'userId_u1' '2746'
$auth += Login-User 'U2' 'chattest_reza' 'token_u2' 'userId_u2' '2747'
$auth += Login-User 'U3' 'chattest_nima' 'token_u3' 'userId_u3' '2748'
$auth += Login-User 'U4' 'chattest_kian' 'token_u4' 'userId_u4' '2749'

$setup = @(
    (Make-Request -Name 'Setup — U2 Calendar List' -Method 'GET' -Path '/Calendar/List' -HeaderVars @('token_u2') -TestScript ($helpers + @"
pm.test('setup list', () => assertStatus(200));
const personal = pm.response.json().find(c => c.type === 'Personal' && c.canWrite);
pm.collectionVariables.set('calendarIdU2', personal.id.toString());
"@)),
    (Make-Request -Name 'Setup — U2 Create busy event' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{calendarIdU2}},
  "title": "Phase5 Busy Block",
  "type": "Meeting",
  "startAt": "{{busyStart}}",
  "endAt": "{{busyEnd}}",
  "isAllDay": false,
  "isPersonal": false
}
'@ -TestScript ($helpers + @"
pm.test('setup busy 200', () => assertStatus(200));
"@)),
    (Make-Request -Name 'Setup — U2 Create personal event' -Method 'POST' -Path '/Calendar/Event' -HeaderVars @('token_u2') -BodyMode 'raw' -BodyRaw @'
{
  "calendarId": {{calendarIdU2}},
  "title": "Phase5 Secret Personal",
  "type": "Private",
  "startAt": "{{personalStart}}",
  "endAt": "{{personalEnd}}",
  "isAllDay": false,
  "isPersonal": true
}
'@ -TestScript ($helpers + @"
pm.test('setup personal 200', () => assertStatus(200));
"@))
)

$folderC1 = @(
    (Make-Request -Name 'C1-1 — Multiple users FreeBusy' -Method 'GET' -Path '/Calendar/FreeBusy?userIds={{userId_u2}},{{userId_u3}}&from={{rangeFrom}}&to={{rangeTo}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('C1-1 status 200', () => assertStatus(200));
const list = pm.response.json();
pm.test('C1-1 array', () => pm.expect(list).to.be.an('array').with.length(2));
const u2 = list.find(x => x.userId === Number(pm.collectionVariables.get('userId_u2')));
pm.test('C1-1 U2 has slots', () => {
  pm.expect(u2).to.exist;
  pm.expect(u2.busySlots).to.be.an('array').that.is.not.empty;
  pm.expect(u2.busySlots[0]).to.have.keys('startAt', 'endAt');
  pm.expect(u2.busySlots[0]).to.not.have.property('title');
});
"@)),
    (Make-Request -Name 'C1-2 — User fully free' -Method 'GET' -Path '/Calendar/FreeBusy?userIds={{userId_u4}}&from={{rangeFrom}}&to={{rangeTo}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('C1-2 status 200', () => assertStatus(200));
const list = pm.response.json();
pm.test('C1-2 empty slots', () => {
  pm.expect(list).to.have.length(1);
  pm.expect(list[0].busySlots).to.eql([]);
});
"@)),
    (Make-Request -Name 'C1-3 — Empty userIds 400' -Method 'GET' -Path '/Calendar/FreeBusy?userIds=&from={{rangeFrom}}&to={{rangeTo}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('C1-3 status 400', () => assertStatus(400));
pm.test('C1-3 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'C1-4 — Invalid user 400' -Method 'GET' -Path '/Calendar/FreeBusy?userIds=999999&from={{rangeFrom}}&to={{rangeTo}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('C1-4 status 400', () => assertStatus(400));
pm.test('C1-4 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'C1-5 — Range too large 400' -Method 'GET' -Path '/Calendar/FreeBusy?userIds={{userId_u2}}&from={{rangeFrom}}&to={{rangeHugeTo}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('C1-5 status 400', () => assertStatus(400));
pm.test('C1-5 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'C1-8 — No token 401' -Method 'GET' -Path '/Calendar/FreeBusy?userIds={{userId_u2}}&from={{rangeFrom}}&to={{rangeTo}}' -HeaderVars @('NONE') -TestScript @"
pm.test('C1-8 status 401', () => pm.response.to.have.status(401));
"@)
)

$folderB6 = @(
    (Make-Request -Name 'B6-2 — No subordinates returns empty' -Method 'GET' -Path '/Calendar/Subordinates/Range?from={{rangeFrom}}&to={{rangeTo}}' -HeaderVars @('token_u4') -TestScript ($helpers + @"
pm.test('B6-2 status 200', () => assertStatus(200));
pm.test('B6-2 empty array', () => pm.expect(pm.response.json()).to.eql([]));
"@)),
    (Make-Request -Name 'B6-1 — Manager view (best effort)' -Method 'GET' -Path '/Calendar/Subordinates/Range?from={{rangeFrom}}&to={{rangeTo}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('B6-1 status 200', () => assertStatus(200));
const list = pm.response.json();
pm.test('B6-1 array', () => pm.expect(list).to.be.an('array'));
// If org tree has no subordinates for U1 in this DB, empty is valid (B6-2 covered by U4).
if (list.length > 0) {
  const personal = list.find(x => x.isBusyOnly === true);
  if (personal) {
    pm.expect(personal.title).to.eql(null);
  }
}
"@)),
    (Make-Request -Name 'B6-3 — Invalid range 400' -Method 'GET' -Path '/Calendar/Subordinates/Range?from={{rangeTo}}&to={{rangeFrom}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('B6-3 status 400', () => assertStatus(400));
pm.test('B6-3 detail', () => assertHasDetail());
"@)),
    (Make-Request -Name 'B6-6 — No token 401' -Method 'GET' -Path '/Calendar/Subordinates/Range?from={{rangeFrom}}&to={{rangeTo}}' -HeaderVars @('NONE') -TestScript @"
pm.test('B6-6 status 401', () => pm.response.to.have.status(401));
"@)
)

$collection = @{
    info = @{
        name = 'Calendar Phase 5 — FreeBusy + Subordinates'
        description = 'C1 + B6. Using test users from: references/postman-test-users.md'
        schema = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
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
                    "const base = Date.UTC(2033, 2, 1, 9, 0, 0);",
                    "const start = new Date(base + (slot % 40000) * dayMs);",
                    "function iso(d) { return d.toISOString().replace(/\\.\\d{3}Z$/, 'Z'); }",
                    "function addHours(d, h) { return new Date(d.getTime() + h * 3600000); }",
                    "function addDays(d, n) { return new Date(d.getTime() + n * dayMs); }",
                    "pm.collectionVariables.set('busyStart', iso(start));",
                    "pm.collectionVariables.set('busyEnd', iso(addHours(start, 1)));",
                    "pm.collectionVariables.set('personalStart', iso(addHours(start, 2)));",
                    "pm.collectionVariables.set('personalEnd', iso(addHours(start, 3)));",
                    "pm.collectionVariables.set('rangeFrom', iso(addDays(start, -1)));",
                    "pm.collectionVariables.set('rangeTo', iso(addDays(start, 5)));",
                    "pm.collectionVariables.set('rangeHugeTo', iso(addDays(start, 100)));",
                    "pm.collectionVariables.set('timesReady', '1');"
                )
            }
        }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth },
        @{ name = '1. Setup Events'; item = $setup },
        @{ name = '2. C1 FreeBusy'; item = $folderC1 },
        @{ name = '3. B6 Subordinates'; item = $folderB6 }
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
        @{ key = 'calendarIdU2'; value = '' },
        @{ key = 'busyStart'; value = '' },
        @{ key = 'busyEnd'; value = '' },
        @{ key = 'personalStart'; value = '' },
        @{ key = 'personalEnd'; value = '' },
        @{ key = 'rangeFrom'; value = '' },
        @{ key = 'rangeTo'; value = '' },
        @{ key = 'rangeHugeTo'; value = '' },
        @{ key = 'timesReady'; value = '' }
    )
}

[System.IO.File]::WriteAllText($outPath, ($collection | ConvertTo-Json -Depth 30), [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote $outPath"
