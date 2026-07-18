$ErrorActionPreference = 'Stop'
$jsonPath = 'd:\Elay_Backend-master\.cursor\calendar-integration-collection.json'
$genPath = 'd:\Elay_Backend-master\.cursor\gen-calendar-integration-collection.ps1'

# 1) Regenerate base collection from generator
powershell -NoProfile -ExecutionPolicy Bypass -File $genPath | Out-Host

$j = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

# 2) Collection-level prerequest: unique time slots once per run
$bootstrap = @(
    "if (pm.collectionVariables.get('timesReady') === '1') { return; }",
    "const dayMs = 86400000;",
    "const slot = Math.floor(Date.now() / 60000);",
    "const base = Date.UTC(2031, 0, 5, 9, 0, 0);",
    "const start = new Date(base + (slot % 40000) * dayMs);",
    "function iso(d) { return d.toISOString().replace(/\.\d{3}Z$/, 'Z'); }",
    "function addHours(d, h) { return new Date(d.getTime() + h * 3600000); }",
    "function addDays(d, n) { return new Date(d.getTime() + n * dayMs); }",
    "const evtStart = start;",
    "const evtEnd = addHours(evtStart, 1);",
    "pm.collectionVariables.set('evtStart', iso(evtStart));",
    "pm.collectionVariables.set('evtEnd', iso(evtEnd));",
    "pm.collectionVariables.set('evtEndPlus', iso(addHours(evtStart, 1.5)));",
    "pm.collectionVariables.set('conflictStart', iso(addHours(evtStart, 0.5)));",
    "pm.collectionVariables.set('conflictEnd', iso(addHours(evtStart, 1.5)));",
    "pm.collectionVariables.set('privateStart', iso(addDays(evtStart, 10)));",
    "pm.collectionVariables.set('privateEnd', iso(addHours(addDays(evtStart, 10), 1)));",
    "const recurStart = addDays(evtStart, -7);",
    "pm.collectionVariables.set('recurStart', iso(recurStart));",
    "pm.collectionVariables.set('recurEnd', iso(addHours(recurStart, 1)));",
    "const recurOcc = addDays(recurStart, 7);",
    "pm.collectionVariables.set('recurOccStart', iso(recurOcc));",
    "pm.collectionVariables.set('recurOccEnd', iso(addHours(recurOcc, 1)));",
    "pm.collectionVariables.set('recurOccDate', iso(new Date(Date.UTC(recurOcc.getUTCFullYear(), recurOcc.getUTCMonth(), recurOcc.getUTCDate()))));",
    "pm.collectionVariables.set('rangeFrom', iso(addDays(recurStart, -1)));",
    "pm.collectionVariables.set('rangeTo', iso(addDays(evtStart, 20)));",
    "pm.collectionVariables.set('timesReady', '1');"
)

$eventObj = [pscustomobject]@{
    listen = 'prerequest'
    script = [pscustomobject]@{
        type = 'text/javascript'
        exec = $bootstrap
    }
}
$j | Add-Member -MemberType NoteProperty -Name event -Value @($eventObj) -Force

# 3) Time variable defaults
$extraVars = @(
    'evtStart','evtEnd','evtEndPlus','conflictStart','conflictEnd',
    'privateStart','privateEnd','recurStart','recurEnd','recurOccStart',
    'recurOccEnd','recurOccDate','rangeFrom','rangeTo','timesReady'
)
$varList = @($j.variable)
$existing = @{}
foreach ($v in $varList) { $existing[$v.key] = $true }
foreach ($k in $extraVars) {
    if (-not $existing.ContainsKey($k)) {
        $varList += [pscustomobject]@{ key = $k; value = '' }
    }
}
$j | Add-Member -MemberType NoteProperty -Name variable -Value $varList -Force

# 4) Rewrite bodies / URLs that contain fixed dates
function Replace-InRaw([string]$raw) {
    if ([string]::IsNullOrEmpty($raw)) { return $raw }
    $raw = $raw.Replace('2027-03-15T09:00:00Z', '{{evtStart}}')
    $raw = $raw.Replace('2027-03-15T10:00:00Z', '{{evtEnd}}')
    $raw = $raw.Replace('2027-03-15T09:30:00Z', '{{conflictStart}}')
    $raw = $raw.Replace('2027-03-15T10:30:00Z', '{{conflictEnd}}')
    $raw = $raw.Replace('2027-03-22T09:00:00Z', '{{privateStart}}')
    $raw = $raw.Replace('2027-03-22T10:00:00Z', '{{privateEnd}}')
    $raw = $raw.Replace('2027-03-01T08:00:00Z', '{{recurStart}}')
    $raw = $raw.Replace('2027-03-01T09:00:00Z', '{{recurEnd}}')
    $raw = $raw.Replace('2027-03-08T08:00:00Z', '{{recurOccStart}}')
    $raw = $raw.Replace('2027-03-08T09:00:00Z', '{{recurOccEnd}}')
    $raw = $raw.Replace('2027-03-08T00:00:00Z', '{{recurOccDate}}')
    # Also older Aug 2026 leftovers if any
    $raw = $raw.Replace('2026-08-10T09:00:00Z', '{{evtStart}}')
    $raw = $raw.Replace('2026-08-10T10:00:00Z', '{{evtEnd}}')
    $raw = $raw.Replace('2026-08-10T09:30:00Z', '{{conflictStart}}')
    $raw = $raw.Replace('2026-08-10T10:30:00Z', '{{conflictEnd}}')
    return $raw
}

function Walk-Items($items) {
    foreach ($it in $items) {
        if ($it.request -and $it.request.body -and $it.request.body.raw) {
            $it.request.body.raw = Replace-InRaw $it.request.body.raw
        }
        if ($it.request -and $it.request.url -and $it.request.url.raw) {
            $u = $it.request.url.raw
            $u = $u.Replace('from=2027-03-01T00:00:00Z&to=2027-03-31T00:00:00Z', 'from={{rangeFrom}}&to={{rangeTo}}')
            $u = $u.Replace('from=2026-08-01T00:00:00Z&to=2026-08-31T00:00:00Z', 'from={{rangeFrom}}&to={{rangeTo}}')
            $it.request.url.raw = $u
            if ($it.request.url.query) {
                foreach ($q in $it.request.url.query) {
                    if ($q.key -eq 'from' -and ($q.value -match '2027-03-01|2026-08-01')) { $q.value = '{{rangeFrom}}' }
                    if ($q.key -eq 'to' -and ($q.value -match '2027-03-31|2026-08-31')) { $q.value = '{{rangeTo}}' }
                }
            }
        }
        if ($it.item) { Walk-Items $it.item }
    }
}

Walk-Items $j.item

$out = $j | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($jsonPath, $out, [System.Text.UTF8Encoding]::new($false))
Write-Output "Patched: $jsonPath size=$((Get-Item $jsonPath).Length)"
