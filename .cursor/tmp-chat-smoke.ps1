$ErrorActionPreference = 'Stop'
$baseUrl = 'http://localhost:5144'
$deviceJson = '{"deviceID":"BE2A.250530.026.F3","deviceName":"postman-test-device","deviceVersion":"16","appVersion":"2.113.0","platform":"android"}'

function Login-ChatUser([string]$username) {
  $body = "{`"username`":`"$username`",`"password`":`"Test@12345`",`"deviceInfo`":$deviceJson}"
  $login = Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json' -Body $body
  if (-not $login.accessToken) { throw "Login failed for $username" }
  return [string]$login.accessToken
}

function Invoke-Multipart([string]$uri, [string]$token, [hashtable]$fields) {
  $boundary = [guid]::NewGuid().ToString()
  $LF = "`r`n"
  $bodyLines = @()
  foreach ($key in $fields.Keys) {
    $bodyLines += "--$boundary"
    $bodyLines += "Content-Disposition: form-data; name=`"$key`""
    $bodyLines += ""
    $bodyLines += [string]$fields[$key]
  }
  $bodyLines += "--$boundary--"
  $bodyLines += ""
  $body = $bodyLines -join $LF
  $headers = @{ Authorization = "Bearer $token" }
  return Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "multipart/form-data; boundary=$boundary" -Body $body
}

function Invoke-Auth([string]$method, [string]$uri, [string]$token, [string]$jsonBody = $null) {
  $headers = @{ Authorization = "Bearer $token" }
  if ($jsonBody) {
    $headers['Content-Type'] = 'application/json'
    return Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -Body $jsonBody
  }
  return Invoke-RestMethod -Uri $uri -Method $method -Headers $headers
}

Write-Output '=== LOGIN U1/U2/U3 ==='
$token1 = Login-ChatUser 'chattest_sara'
$token2 = Login-ChatUser 'chattest_reza'
$token3 = Login-ChatUser 'chattest_nima'
Write-Output 'LOGIN_OK'

Write-Output '=== CREATE GROUP (U1 + U2) ==='
$stamp = Get-Date -Format 'HHmmss'
$group = Invoke-Multipart "$baseUrl/chat/groups" $token1 @{ name = "ChatPersistTest-$stamp"; memberUserIds = '2747' }
$conversationId = $group.id
if (-not $conversationId) { $conversationId = $group.Id }
Write-Output "GROUP_ID=$conversationId"

Write-Output '=== SEND MESSAGE ==='
$msg = Invoke-Multipart "$baseUrl/chat/conversations/$conversationId/messages" $token1 @{ text = 'message-before-delete' }
$messageId = $msg.id
if (-not $messageId) { $messageId = $msg.Id }
Write-Output "MESSAGE_ID=$messageId"

Write-Output '=== PIN MESSAGE ==='
Invoke-Auth 'POST' "$baseUrl/chat/conversations/$conversationId/messages/$messageId/pin" $token1 | Out-Null
Write-Output 'PIN_OK'

Write-Output '=== GET PINNED ==='
$pinned1 = Invoke-Auth 'GET' "$baseUrl/chat/conversations/$conversationId/pinned-messages" $token1
$pinIds = @($pinned1 | ForEach-Object { if ($_.id) { $_.id } else { $_.Id } })
Write-Output ("PINNED_COUNT=" + $pinIds.Count)
Write-Output ("PIN_CONTAINS_MSG=" + ($pinIds -contains $messageId))

Write-Output '=== ADD MEMBER U3 (system log) ==='
Invoke-Auth 'POST' "$baseUrl/chat/groups/$conversationId/members" $token1 '{"userIds":[2748]}' | Out-Null
Write-Output 'ADD_MEMBER_OK'

Write-Output '=== DELETE MESSAGE ==='
Invoke-Auth 'DELETE' "$baseUrl/chat/messages/$messageId" $token1 | Out-Null
Write-Output 'DELETE_OK'

Write-Output '=== RELOAD MESSAGES (tombstone + system) ==='
$page = Invoke-Auth 'GET' "$baseUrl/chat/conversations/$conversationId/messages?pageSize=50" $token1
$messages = $page.messages
if (-not $messages) { $messages = $page.Messages }
$tombstone = $false
$systemLog = $false
foreach ($m in @($messages)) {
  $mid = $m.id; if (-not $mid) { $mid = $m.Id }
  $isDel = $m.isDeleted; if ($null -eq $isDel) { $isDel = $m.IsDeleted }
  $text = $m.text; if ($null -eq $text) { $text = $m.Text }
  if (($mid -eq $messageId) -and ($isDel -eq $true)) { $tombstone = $true }
  if ($text -and ($text -like '*اضافه*')) { $systemLog = $true }
}
Write-Output "TOMBSTONE=$tombstone"
Write-Output "SYSTEM_LOG=$systemLog"

Write-Output '=== RELOAD PINNED AFTER DELETE ==='
$pinned2 = Invoke-Auth 'GET' "$baseUrl/chat/conversations/$conversationId/pinned-messages" $token1
$pinAfterIds = @($pinned2 | ForEach-Object { if ($_.id) { $_.id } else { $_.Id } })
$pinAfterDelete = $pinAfterIds -contains $messageId
Write-Output "PIN_AFTER_DELETE=$pinAfterDelete"

Write-Output '=== SEND+PIN AGAIN FOR RELOAD PIN TEST ==='
$msg2 = Invoke-Multipart "$baseUrl/chat/conversations/$conversationId/messages" $token1 @{ text = 'pin-reload-test' }
$mid2 = $msg2.id; if (-not $mid2) { $mid2 = $msg2.Id }
Invoke-Auth 'POST' "$baseUrl/chat/conversations/$conversationId/messages/$mid2/pin" $token1 | Out-Null
$pinned3 = Invoke-Auth 'GET' "$baseUrl/chat/conversations/$conversationId/pinned-messages" $token2
$pinReloadIds = @($pinned3 | ForEach-Object { if ($_.id) { $_.id } else { $_.Id } })
$pinReload = $pinReloadIds -contains $mid2
Write-Output "PIN_RELOAD_U2=$pinReload"

Write-Output '=== SUMMARY ==='
$pass = ($tombstone -eq $true) -and ($systemLog -eq $true) -and ($pinReload -eq $true) -and ($pinAfterDelete -eq $false)
Write-Output "OVERALL_PASS=$pass"
Write-Output "CONVERSATION_ID=$conversationId"
Write-Output "DELETED_MESSAGE_ID=$messageId"
Write-Output "PINNED_MESSAGE_ID=$mid2"
