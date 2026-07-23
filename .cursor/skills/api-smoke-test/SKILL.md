---
name: api-smoke-test
description: >-
  Smoke-test HTTP APIs with PowerShell or documented clients: login, call
  changed routes, assert status/body, read-back after writes. Use when testing
  endpoints, Postman alternatives, or verifying an API change locally.
---

# API Smoke Test (Global)

Prefer project docs (`api-testing-quickref`, Postman collections, `.http` files).

## Rules

- Never invent production passwords; use project-documented test users
- Never hard-code expired JWTs — login each session
- Prefer HTTPS local cert bypass only in documented local scripts
- Do not run destructive endpoints against shared prod

## Flow

1. Start or locate base URL (from launchSettings / README)
2. Login → store token in session variable
3. Call target routes with `Authorization: Bearer`
4. On failure: print status + response body
5. After POST/PUT/PATCH: GET to confirm
6. Report table: route, method, status, pass/fail, notes

## PowerShell skeleton

```powershell
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
try {
  $r = Invoke-RestMethod -Uri "$baseUrl/path" -Method GET -Headers $headers
  $r | ConvertTo-Json -Depth 5
} catch {
  Write-Host "Status:" $_.Exception.Response.StatusCode.value__
  Write-Host "Body:" $_.ErrorDetails.Message
}
```

Prefix shell with `rtk` when wrapping scripts; show `RTK ▸`.

## Postman / Newman

If the user wants collections: follow project Postman rules (fixed test users, Auth folder). Global default: do not invent multi-user credentials.
