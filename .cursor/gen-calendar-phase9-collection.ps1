$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-phase9-collection.json'

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
$rangeFrom = $now.AddDays(10).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$rangeTo = $now.AddDays(17).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
# Task create uses SolarDateTime.Parse — must send Persian solar (yyyy/MM/dd), not ISO Gregorian
$solarCal = [Globalization.CultureInfo]::GetCultureInfo('fa-IR').DateTimeFormat.Calendar
$dueDate = $now.AddDays(12).Date
$taskDue = '{0:0000}/{1:00}/{2:00}' -f $solarCal.GetYear($dueDate), $solarCal.GetMonth($dueDate), $solarCal.GetDayOfMonth($dueDate)
$eventStart = $now.AddDays(11).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$eventEnd = $now.AddDays(11).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

$auth = @()
$auth += Login-User 'U1' 'chattest_sara' 'token_u1' 'userId_u1'
$auth += Login-User 'U2' 'chattest_reza' 'token_u2' 'userId_u2'
$auth += Login-User 'U4' 'chattest_kian' 'token_u4' 'userId_u4'

$setup = @(
    (Make-Request -Name 'Setup Create task deadline' -Method POST -Path '/Task' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"title":"Phase9 calendar deadline","description":"Newman seed","assignedToUserId":{{userId_u1}},"formId":null,"formDataId":null,"dueDate":"{{taskDue}}","priority":1}
'@ -TestScript ($helpers + @"
pm.test('Setup task 200', () => assertStatus(200));
const id = pm.response.json();
pm.expect(id).to.be.a('number').above(0);
pm.collectionVariables.set('taskId', id.toString());
"@)),
    (Make-Request -Name 'Setup List calendars' -Method GET -Path '/Calendar/List' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('Setup calendars 200', () => assertStatus(200));
const list = pm.response.json();
const personal = list.find(c => c.type === 'Personal' || c.Type === 'Personal') || list[0];
pm.collectionVariables.set('calendarId', (personal.id || personal.Id).toString());
"@)),
    (Make-Request -Name 'Setup Create event' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"Phase9 range event","type":"Meeting","startAt":"{{eventStart}}","endAt":"{{eventEnd}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":false,"participantUserIds":[]}
'@ -TestScript ($helpers + @"
pm.test('Setup event 200', () => assertStatus(200));
pm.collectionVariables.set('eventId', pm.response.json().toString());
"@))
)

$folderB5 = @(
    (Make-Request -Name 'B5-1 Empty range' -Method GET -Path '/Calendar/Range?from=2028-01-01T00:00:00Z&to=2028-01-07T00:00:00Z&includeTaskDeadlines=true' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('B5-1 200', () => assertStatus(200));
pm.expect(pm.response.json()).to.be.an('array');
"@)),
    (Make-Request -Name 'B5-2 Events and task deadlines' -Method GET -Path '/Calendar/Range?from={{rangeFrom}}&to={{rangeTo}}&includeTaskDeadlines=true' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('B5-2 200', () => assertStatus(200));
const items = pm.response.json();
pm.test('B5-2 has Event', () => pm.expect(items.some(i => i.kind === 'Event')).to.be.true);
pm.test('B5-2 has TaskDeadline', () => pm.expect(items.some(i => i.kind === 'TaskDeadline')).to.be.true);
const tid = parseInt(pm.collectionVariables.get('taskId'), 10);
const td = items.find(i => i.kind === 'TaskDeadline' && i.taskId === tid);
pm.test('B5-2 seeded task present', () => pm.expect(!!td).to.be.true);
pm.test('B5-2 title prefix Due:', () => pm.expect(td.title).to.match(/^Due: /));
pm.test('B5-2 type Deadline', () => pm.expect(td.type).to.eql('Deadline'));
pm.test('B5-2 color black', () => pm.expect(td.color).to.eql('#000000'));
pm.test('B5-2 eventId null on task', () => pm.expect(td.eventId).to.be.null);
"@)),
    (Make-Request -Name 'B5-3 includeTaskDeadlines=false' -Method GET -Path '/Calendar/Range?from={{rangeFrom}}&to={{rangeTo}}&includeTaskDeadlines=false' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('B5-3 200', () => assertStatus(200));
const items = pm.response.json();
pm.test('B5-3 no TaskDeadline', () => pm.expect(items.every(i => i.kind !== 'TaskDeadline')).to.be.true);
pm.test('B5-3 still has Event', () => pm.expect(items.some(i => i.kind === 'Event')).to.be.true);
"@)),
    (Make-Request -Name 'B5-5 to <= from 400' -Method GET -Path '/Calendar/Range?from=2027-03-08T00:00:00Z&to=2026-08-01T00:00:00Z' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('B5-5 400',()=>assertStatus(400));")),
    (Make-Request -Name 'B5-6 range > 92 days 400' -Method GET -Path '/Calendar/Range?from=2026-01-01T00:00:00Z&to=2026-05-01T00:00:00Z' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('B5-6 400',()=>assertStatus(400));")),
    (Make-Request -Name 'P9-1 U4 cannot see U1 task' -Method GET -Path '/Calendar/Range?from={{rangeFrom}}&to={{rangeTo}}&includeTaskDeadlines=true' -HeaderVars @('token_u4') -TestScript ($helpers + @"
pm.test('P9-1 200', () => assertStatus(200));
const items = pm.response.json();
const tid = parseInt(pm.collectionVariables.get('taskId'), 10);
pm.test('P9-1 other user task hidden', () => pm.expect(items.every(i => i.taskId !== tid)).to.be.true);
"@)),
    (Make-Request -Name 'P9-2 U2 sees assigned task' -Method POST -Path '/Task' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"title":"Phase9 assigned to U2","description":"assigned seed","assignedToUserId":{{userId_u2}},"formId":null,"formDataId":null,"dueDate":"{{taskDue}}","priority":1}
'@ -TestScript ($helpers + @"
pm.test('P9-2 create assigned 200', () => assertStatus(200));
pm.collectionVariables.set('taskIdU2', pm.response.json().toString());
"@)),
    (Make-Request -Name 'P9-2b U2 range has assigned task' -Method GET -Path '/Calendar/Range?from={{rangeFrom}}&to={{rangeTo}}&includeTaskDeadlines=true' -HeaderVars @('token_u2') -TestScript ($helpers + @"
pm.test('P9-2b 200', () => assertStatus(200));
const items = pm.response.json();
const tid = parseInt(pm.collectionVariables.get('taskIdU2'), 10);
pm.test('P9-2b assigned task visible', () => pm.expect(items.some(i => i.kind === 'TaskDeadline' && i.taskId === tid)).to.be.true);
"@))
)

$collection = @{
    info = @{
        name = 'Calendar Phase 9 — Task Deadlines on Range B5'
        schema = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' }
        @{ key = 'rangeFrom'; value = $rangeFrom }
        @{ key = 'rangeTo'; value = $rangeTo }
        @{ key = 'taskDue'; value = $taskDue }
        @{ key = 'eventStart'; value = $eventStart }
        @{ key = 'eventEnd'; value = $eventEnd }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth }
        @{ name = '1. Setup'; item = $setup }
        @{ name = '2. B5 Task Deadlines'; item = $folderB5 }
    )
}

$collection | ConvertTo-Json -Depth 40 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
