$ErrorActionPreference = 'Stop'
$outPath = 'd:\Elay_Backend-master\.cursor\calendar-phase11-collection.json'

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
$base = $now.AddDays(50).AddMinutes(([DateTime]::UtcNow.Ticks % 5000))
$hFrom = $base.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$hTo = $base.AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$hStart = $base.AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$hEnd = $base.AddDays(1).AddHours(23).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

$auth = @()
$auth += Login-User 'U1' 'chattest_sara' 'token_u1' 'userId_u1'
$auth += Login-User 'U2' 'chattest_reza' 'token_u2' 'userId_u2'
$auth += Login-User 'U3' 'chattest_nima' 'token_u3' 'userId_u3'
$auth += Login-User 'U4' 'chattest_kian' 'token_u4' 'userId_u4'

$tests = @(
    (Make-Request -Name 'H1-1 Favorites empty or list' -Method GET -Path '/Calendar/Favorites' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('H1-1 200', () => assertStatus(200));
pm.expect(pm.response.json()).to.be.an('array');
"@)),
    (Make-Request -Name 'H2-3 Cannot favorite self 400' -Method POST -Path '/Calendar/Favorites' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"targetUserId":{{userId_u1}}}
'@ -TestScript ($helpers + "pm.test('H2-3 400',()=>assertStatus(400));")),
    (Make-Request -Name 'H2-2 Target not found 404' -Method POST -Path '/Calendar/Favorites' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"targetUserId":999999001}
'@ -TestScript ($helpers + "pm.test('H2-2 404',()=>assertStatus(404));")),
    (Make-Request -Name 'H2-1 Add favorite U2' -Method POST -Path '/Calendar/Favorites' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"targetUserId":{{userId_u2}}}
'@ -TestScript ($helpers + @"
pm.test('H2-1 200', () => assertStatus(200));
const id = pm.response.json();
pm.expect(id).to.be.a('number').above(0);
pm.collectionVariables.set('favoriteId', id.toString());
"@)),
    (Make-Request -Name 'H2-4 Add favorite duplicate idempotent' -Method POST -Path '/Calendar/Favorites' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"targetUserId":{{userId_u2}}}
'@ -TestScript ($helpers + @"
pm.test('H2-4 200', () => assertStatus(200));
pm.expect(pm.response.json().toString()).to.eql(pm.collectionVariables.get('favoriteId'));
"@)),
    (Make-Request -Name 'H1-1b Favorites contains U2' -Method GET -Path '/Calendar/Favorites' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('H1-1b 200', () => assertStatus(200));
const list = pm.response.json();
const tid = parseInt(pm.collectionVariables.get('userId_u2'), 10);
pm.test('contains U2', () => pm.expect(list.some(x => x.targetUserId === tid)).to.be.true);
"@)),
    (Make-Request -Name 'H3-3 Other user cannot delete 403' -Method DELETE -Path '/Calendar/Favorites/{{favoriteId}}' -HeaderVars @('token_u2') -TestScript ($helpers + "pm.test('H3-3 403',()=>assertStatus(403));")),
    (Make-Request -Name 'H3-2 Favorite not found 404' -Method DELETE -Path '/Calendar/Favorites/999999001' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('H3-2 404',()=>assertStatus(404));")),
    (Make-Request -Name 'H3-1 Delete favorite' -Method DELETE -Path '/Calendar/Favorites/{{favoriteId}}' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('H3-1 200',()=>assertStatus(200));")),
    (Make-Request -Name 'H3 soft-delete excluded from list' -Method GET -Path '/Calendar/Favorites' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('list 200', () => assertStatus(200));
const list = pm.response.json();
const fid = parseInt(pm.collectionVariables.get('favoriteId'), 10);
pm.test('deleted gone', () => pm.expect(list.every(x => x.id !== fid)).to.be.true);
"@)),
    (Make-Request -Name 'H2 restore after soft-delete' -Method POST -Path '/Calendar/Favorites' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"targetUserId":{{userId_u2}}}
'@ -TestScript ($helpers + @"
pm.test('restore 200', () => assertStatus(200));
pm.collectionVariables.set('favoriteId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'HC-1 Create org holiday' -Method POST -Path '/Calendar/Holidays' -HeaderVars @('token_u1') -BodyMode raw -BodyRaw @'
{"title":"P11 Org Holiday","startAt":"{{hStart}}","endAt":"{{hEnd}}","isAllDay":true,"scope":"Organization","scopeId":null}
'@ -TestScript ($helpers + @"
pm.test('HC-1 200', () => assertStatus(200));
pm.collectionVariables.set('holidayId', pm.response.json().toString());
"@)),
    (Make-Request -Name 'H4-1 Holidays range org' -Method GET -Path '/Calendar/Holidays/Range?from={{hFrom}}&to={{hTo}}&scope=Organization' -HeaderVars @('token_u1') -TestScript ($helpers + @"
pm.test('H4-1 200', () => assertStatus(200));
const list = pm.response.json();
const hid = parseInt(pm.collectionVariables.get('holidayId'), 10);
pm.test('seeded holiday present', () => pm.expect(list.some(x => x.id === hid)).to.be.true);
"@)),
    (Make-Request -Name 'H4-2 Range too large 400' -Method GET -Path '/Calendar/Holidays/Range?from=2026-01-01T00:00:00Z&to=2026-05-01T00:00:00Z&scope=Organization' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('H4-2 400',()=>assertStatus(400));")),
    (Make-Request -Name 'H4-4 Unit missing scopeId 400' -Method GET -Path '/Calendar/Holidays/Range?from={{hFrom}}&to={{hTo}}&scope=Unit' -HeaderVars @('token_u1') -TestScript ($helpers + "pm.test('H4-4 400',()=>assertStatus(400));"))
)

$collection = @{
    info = @{
        name = 'Calendar Phase 11 — Favorites and Holidays'
        schema = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'
    }
    variable = @(
        @{ key = 'baseUrl'; value = 'http://localhost:5144' }
        @{ key = 'hFrom'; value = $hFrom }
        @{ key = 'hTo'; value = $hTo }
        @{ key = 'hStart'; value = $hStart }
        @{ key = 'hEnd'; value = $hEnd }
    )
    item = @(
        @{ name = '0. Auth (Setup)'; item = $auth }
        @{ name = '1. Favorites and Holidays'; item = $tests }
    )
}

$collection | ConvertTo-Json -Depth 40 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
