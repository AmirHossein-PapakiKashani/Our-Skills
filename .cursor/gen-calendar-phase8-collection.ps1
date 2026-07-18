$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-phase8-collection.json'

function Make-Request {
    param(
        [string]$Name, [string]$Method, [string]$Path,
        [string[]]$HeaderVars = @('token_u1'),
        [string]$BodyMode = $null, [string]$BodyRaw = $null,
        [string]$FormMode = $null, [hashtable]$FormData = $null,
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
    if ($FormMode -eq 'formdata') {
        $items = @()
        foreach ($k in $FormData.Keys) {
            $v = $FormData[$k]
            if ($v -is [hashtable] -and $v.type -eq 'file') {
                $items += @{ key = $k; type = 'file'; src = $v.src }
            } else {
                $items += @{ key = $k; type = 'text'; value = "$v" }
            }
        }
        $req.body = @{ mode = 'formdata'; formdata = $items }
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

$samplePdf = 'd:\Elay_Backend-master\.cursor\phase8-sample.pdf'
$sampleTxt = 'd:\Elay_Backend-master\.cursor\phase8-bad.txt'
# Minimal PDF bytes
[IO.File]::WriteAllBytes($samplePdf, [byte[]](0x25,0x50,0x44,0x46,0x2D,0x31,0x2E,0x34,0x0A,0x25,0xE2,0xE3,0xCF,0xD3,0x0A,0x31,0x20,0x30,0x20,0x6F,0x62,0x6A,0x0A,0x3C,0x3C,0x2F,0x54,0x79,0x70,0x65,0x2F,0x43,0x61,0x74,0x61,0x6C,0x6F,0x67,0x2F,0x50,0x61,0x67,0x65,0x73,0x20,0x32,0x20,0x30,0x20,0x52,0x3E,0x3E,0x0A,0x65,0x6E,0x64,0x6F,0x62,0x6A,0x0A,0x32,0x20,0x30,0x20,0x6F,0x62,0x6A,0x0A,0x3C,0x3C,0x2F,0x54,0x79,0x70,0x65,0x2F,0x50,0x61,0x67,0x65,0x73,0x2F,0x43,0x6F,0x75,0x6E,0x74,0x20,0x30,0x3E,0x3E,0x0A,0x65,0x6E,0x64,0x6F,0x62,0x6A,0x0A,0x74,0x72,0x61,0x69,0x6C,0x65,0x72,0x0A,0x3C,0x3C,0x2F,0x53,0x69,0x7A,0x65,0x20,0x33,0x2F,0x52,0x6F,0x6F,0x74,0x20,0x31,0x20,0x30,0x20,0x52,0x3E,0x3E,0x0A,0x73,0x74,0x61,0x72,0x74,0x78,0x72,0x65,0x66,0x0A,0x30,0x0A,0x25,0x25,0x45,0x4F,0x46))
Set-Content -Path $sampleTxt -Value 'not-a-pdf' -Encoding ASCII

$auth = @()
$auth += Login-User 'U1' 'chattest_sara' 'token_u1' 'userId_u1' '2746'
$auth += Login-User 'U2' 'chattest_reza' 'token_u2' 'userId_u2' '2747'
$auth += Login-User 'U4' 'chattest_kian' 'token_u4' 'userId_u4' '2749'

$setup = @(
    (Make-Request -Name 'Setup List calendars' -Method GET -Path '/Calendar/List' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('Setup calendars 200', () => assertStatus(200));
const list = pm.response.json();
const personal = list.find(c => c.type === 'Personal' || c.Type === 'Personal') || list[0];
pm.collectionVariables.set('calendarId', (personal.id || personal.Id).toString());
"@)),
    (Make-Request -Name 'Setup Create event' -Method POST -Path '/Calendar/Event' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"calendarId":{{calendarId}},"title":"Phase8 Attachments Notes","type":"Meeting","startAt":"{{eventStart}}","endAt":"{{eventEnd}}","isAllDay":false,"isPersonal":false,"visibleOnlyToParticipants":true,"participantUserIds":[{{userId_u2}}]}
'@ -TestScript ($helpers + @"
pm.test('Setup event 200', () => assertStatus(200));
pm.collectionVariables.set('eventId', pm.response.json().toString());
"@))
)

$folderG1 = @(
    (Make-Request -Name 'G1-1 Upload PDF' -Method POST -Path '/Calendar/Event/Attachment' -HeaderVars @('token_u1') -FormMode formdata -FormData @{
        eventId = '{{eventId}}'
        file = @{ type = 'file'; src = $samplePdf }
    } -TestScript ($helpers + @"
pm.test('G1-1 200', () => assertStatus(200));
const d = pm.response.json();
pm.expect(d.id || d.Id).to.be.a('number').above(0);
pm.expect(d.fileName || d.FileName).to.be.a('string').and.not.empty;
pm.collectionVariables.set('attachmentId', (d.id || d.Id).toString());
"@)),
    (Make-Request -Name 'G1-2 Missing file' -Method POST -Path '/Calendar/Event/Attachment' -HeaderVars @('token_u1') -FormMode formdata -FormData @{
        eventId = '{{eventId}}'
    } -TestScript ($helpers + "pm.test('G1-2 400',()=>assertStatus(400));")),
    (Make-Request -Name 'G1-4 Bad type' -Method POST -Path '/Calendar/Event/Attachment' -HeaderVars @('token_u1') -FormMode formdata -FormData @{
        eventId = '{{eventId}}'
        file = @{ type = 'file'; src = $sampleTxt }
    } -TestScript ($helpers + "pm.test('G1-4 400',()=>assertStatus(400));")),
    (Make-Request -Name 'G1-5 Event not found' -Method POST -Path '/Calendar/Event/Attachment' -HeaderVars @('token_u1') -FormMode formdata -FormData @{
        eventId = '999999'
        file = @{ type = 'file'; src = $samplePdf }
    } -TestScript ($helpers + "pm.test('G1-5 404',()=>assertStatus(404));")),
    (Make-Request -Name 'G1-6 U4 forbidden' -Method POST -Path '/Calendar/Event/Attachment' -HeaderVars @('token_u4') -FormMode formdata -FormData @{
        eventId = '{{eventId}}'
        file = @{ type = 'file'; src = $samplePdf }
    } -TestScript ($helpers + "pm.test('G1-6 403',()=>assertStatus(403));"))
)

$folderG3 = @(
    (Make-Request -Name 'G3-1 List attachments' -Method GET -Path '/Calendar/Event/{{eventId}}/Attachments' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('G3-1 200', () => assertStatus(200));
pm.expect(pm.response.json()).to.be.an('array').with.lengthOf.at.least(1);
"@)),
    (Make-Request -Name 'G3-3 U4 forbidden' -Method GET -Path '/Calendar/Event/{{eventId}}/Attachments' -HeaderVars @('token_u4') -TestScript ($helpers + "pm.test('G3-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'G3-2 Not found' -Method GET -Path '/Calendar/Event/999999/Attachments' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('G3-2 404',()=>assertStatus(404));"))
)

$folderG4 = @(
    (Make-Request -Name 'G4-1 Create note' -Method POST -Path '/Calendar/Event/Note' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"text":"Phase8 note from U2"}' -TestScript ($helpers + @"
pm.test('G4-1 200', () => assertStatus(200));
const id = pm.response.json();
pm.expect(id).to.be.a('number').above(0);
pm.collectionVariables.set('noteId', id.toString());
"@)),
    (Make-Request -Name 'G4-2 Update note' -Method POST -Path '/Calendar/Event/Note' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"noteId":{{noteId}},"text":"Phase8 note updated"}' -TestScript ($helpers + "pm.test('G4-2 200',()=>assertStatus(200)); pm.expect(pm.response.json()).to.eql(parseInt(pm.collectionVariables.get('noteId'),10));")),
    (Make-Request -Name 'G4-3 Empty text' -Method POST -Path '/Calendar/Event/Note' -HeaderVars @('token_u2') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"text":""}' -TestScript ($helpers + "pm.test('G4-3 400',()=>assertStatus(400));")),
    (Make-Request -Name 'G4-6 U1 cannot edit U2 note' -Method POST -Path '/Calendar/Event/Note' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"eventId":{{eventId}},"noteId":{{noteId}},"text":"hack"}' -TestScript ($helpers + "pm.test('G4-6 403',()=>assertStatus(403));")),
    (Make-Request -Name 'G4-4 Event not found' -Method POST -Path '/Calendar/Event/Note' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw '{"eventId":999999,"text":"x"}' -TestScript ($helpers + "pm.test('G4-4 404',()=>assertStatus(404));"))
)

$folderG5 = @(
    (Make-Request -Name 'G5-1 List notes' -Method GET -Path '/Calendar/Event/{{eventId}}/Notes' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('G5-1 200', () => assertStatus(200));
pm.expect(pm.response.json()).to.be.an('array').with.lengthOf.at.least(1);
"@)),
    (Make-Request -Name 'G5-3 U4 forbidden' -Method GET -Path '/Calendar/Event/{{eventId}}/Notes' -HeaderVars @('token_u4') -TestScript ($helpers + "pm.test('G5-3 403',()=>assertStatus(403));"))
)

$folderG2G6 = @(
    (Make-Request -Name 'G2-3 U4 cannot delete attachment' -Method DELETE -Path '/Calendar/Event/Attachment/{{attachmentId}}' -HeaderVars @('token_u4') -TestScript ($helpers + "pm.test('G2-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'G2-1 Delete attachment' -Method DELETE -Path '/Calendar/Event/Attachment/{{attachmentId}}' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('G2-1 200',()=>assertStatus(200));")),
    (Make-Request -Name 'G2-2 Not found' -Method DELETE -Path '/Calendar/Event/Attachment/999999' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('G2-2 404',()=>assertStatus(404));")),
    (Make-Request -Name 'G6-3 U4 cannot delete note' -Method DELETE -Path '/Calendar/Event/Note/{{noteId}}' -HeaderVars @('token_u4') -TestScript ($helpers + "pm.test('G6-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'G6-1 Creator deletes note' -Method DELETE -Path '/Calendar/Event/Note/{{noteId}}' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('G6-1 200',()=>assertStatus(200));")),
    (Make-Request -Name 'G6-2 Not found' -Method DELETE -Path '/Calendar/Event/Note/999999' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('G6-2 404',()=>assertStatus(404));")),
    (Make-Request -Name 'B4 Detail has arrays' -Method GET -Path '/Calendar/Event/{{eventId}}' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('B4 detail 200', () => assertStatus(200));
const d = pm.response.json();
pm.expect(d.attachments || d.Attachments).to.be.an('array');
pm.expect(d.notes || d.Notes).to.be.an('array');
"@))
)

$now = [DateTime]::UtcNow
$eventStart = $now.AddDays(4).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$eventEnd = $now.AddDays(4).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

$collection = @{
    info = @{
        name = 'Calendar Phase 8 — Attachments & Notes G1-G6'
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
        @{ name = '2. G1 Attachments Add'; item = $folderG1 }
        @{ name = '3. G3 Attachments List'; item = $folderG3 }
        @{ name = '4. G4 Notes Upsert'; item = $folderG4 }
        @{ name = '5. G5 Notes List'; item = $folderG5 }
        @{ name = '6. G2 G6 Delete + Detail'; item = $folderG2G6 }
    )
}

$collection | ConvertTo-Json -Depth 40 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
