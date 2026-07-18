$ErrorActionPreference = 'Stop'
$baseUrl = 'http://localhost:5144'
$password = 'Test@12345'

function Login([string]$username) {
  $deviceJson = '{"deviceID":"BE2A.250530.026.F3","deviceName":"postman-test-device","deviceVersion":"16","appVersion":"2.113.0","platform":"android"}'
  $body = "{`"username`":`"$username`",`"password`":`"$password`",`"deviceInfo`":$deviceJson}"
  $r = Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json; charset=utf-8' -Body $body
  if (-not $r.accessToken) { throw "Login failed for $username" }
  return $r.accessToken
}

function AuthHeaders([string]$token) {
  @{ Authorization = "Bearer $token" }
}

function PostMultipart([string]$url, [string]$token, [hashtable]$fields) {
  Add-Type -AssemblyName System.Net.Http
  $client = [System.Net.Http.HttpClient]::new()
  try {
    $client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $token)
    $content = [System.Net.Http.MultipartFormDataContent]::new()
    foreach ($key in $fields.Keys) {
      $val = [string]$fields[$key]
      $content.Add([System.Net.Http.StringContent]::new($val), $key)
    }
    $resp = $client.PostAsync($url, $content).GetAwaiter().GetResult()
    $text = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $resp.IsSuccessStatusCode) {
      throw "POST $url failed $($resp.StatusCode): $text"
    }
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return ($text | ConvertFrom-Json)
  }
  finally {
    $client.Dispose()
  }
}

Write-Host '=== AUTH ==='
$t1 = Login 'chattest_sara'
$t2 = Login 'chattest_reza'
$null = Login 'chattest_nima'
$null = Login 'chattest_kian'
Write-Host 'AUTH OK (U1-U4)'

Write-Host '=== CREATE GROUP ==='
$group = PostMultipart "$baseUrl/chat/groups" $t1 @{
  name = "PersistInt-$(Get-Date -Format yyyyMMddHHmmss)"
  memberUserIds = '2747'
}
$conversationId = $group.id
if (-not $conversationId) { $conversationId = $group.conversationId }
if (-not $conversationId) { throw "No conversation id: $($group | ConvertTo-Json -Depth 6)" }
Write-Host "conversationId=$conversationId"

Write-Host '=== TOMBSTONE ==='
$msg = PostMultipart "$baseUrl/chat/conversations/$conversationId/messages" $t1 @{ text = "tombstone-$(Get-Date -Format HHmmss)" }
$messageId = $msg.id
if (-not $messageId) { throw "No message id: $($msg | ConvertTo-Json -Depth 5)" }
Invoke-RestMethod -Uri "$baseUrl/chat/messages/$messageId" -Method DELETE -Headers (AuthHeaders $t1) | Out-Null
$page = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$conversationId/messages?pageSize=50" -Method GET -Headers (AuthHeaders $t2)
$found = @($page.messages) | Where-Object { $_.id -eq $messageId } | Select-Object -First 1
if (-not $found) { throw 'TOMBSTONE FAIL: deleted message missing' }
if ($found.isDeleted -ne $true) { throw 'TOMBSTONE FAIL: isDeleted != true' }
if ($null -ne $found.text) { throw 'TOMBSTONE FAIL: text should be null' }
Write-Host "TOMBSTONE=True messageId=$messageId"

Write-Host '=== SYSTEM LOG ==='
$addBody = '{"userIds":[2748]}'
Invoke-RestMethod -Uri "$baseUrl/chat/groups/$conversationId/members" -Method POST -Headers (AuthHeaders $t1) -ContentType 'application/json' -Body $addBody | Out-Null
$page2 = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$conversationId/messages?pageSize=50" -Method GET -Headers (AuthHeaders $t1)
$sys = @($page2.messages) | Where-Object {
  $_.text -and (
    ([string]$_.text).Contains('Nima') -or
    ([string]$_.text).Contains([char]0x0627) # Arabic/Persian alef heuristic fallback
  )
} | Select-Object -First 1
if (-not $sys) {
  $sys = @($page2.messages) | Where-Object { $_.text -and $_.id -gt $messageId -and -not $_.isDeleted } | Select-Object -Last 1
}
if (-not $sys) {
  $sample = (@($page2.messages) | ForEach-Object { $_.text } | Where-Object { $_ }) -join ' | '
  throw "SYSTEM_LOG FAIL. Sample: $sample"
}
Write-Host "SYSTEM_LOG=True text=$($sys.text)"

Write-Host '=== PIN RELOAD ==='
$pinMsg = PostMultipart "$baseUrl/chat/conversations/$conversationId/messages" $t1 @{ text = "pin-$(Get-Date -Format HHmmss)" }
$pinnedMessageId = $pinMsg.id
Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$conversationId/messages/$pinnedMessageId/pin" -Method POST -Headers (AuthHeaders $t1) | Out-Null
$pins = Invoke-RestMethod -Uri "$baseUrl/chat/conversations/$conversationId/pinned-messages" -Method GET -Headers (AuthHeaders $t2)
$pinList = @($pins)
$hit = $pinList | Where-Object { $_.id -eq $pinnedMessageId } | Select-Object -First 1
if (-not $hit) { throw "PIN_RELOAD FAIL count=$($pinList.Count)" }
Write-Host "PIN_RELOAD=True pinnedMessageId=$pinnedMessageId isPinned=$($hit.isPinned)"

Write-Host 'ALL_INTEGRATION_OK'
