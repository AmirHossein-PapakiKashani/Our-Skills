# API Testing Quick Reference

> Verify through API endpoints only — never raw SQL.

## Customer Postman integration (mandatory)

For **Customer** Postman / Newman integration collections and multi-user flows, use the canonical credentials file only:

**`references/postman-test-users.md`**

- Four users: `chattest_sara`, `chattest_reza`, `chattest_nima`, `chattest_kian`
- Password: `Test@12345`
- Base URL: `http://localhost:5144`
- Cursor rule: `.cursor/rules/postman-integration-tests.mdc` (always on)

Do **not** invent users. Do **not** use Admin credentials for Customer integration suites.

## Admin login (HTTP :6144)

```powershell
$loginBody = @{
  username = "a.kashani"
  password = "123456"
  deviceInfo = @{
    deviceID = "BE2A.250530.026.F3"
    deviceName = "sdk_gphone64_x86_64"
    deviceVersion = "16"
    appVersion = "2.113.0"
    platform = "android"
  }
} | ConvertTo-Json -Depth 3

$loginResponse = Invoke-RestMethod -Uri "http://localhost:6144/auth/login" -Method POST -ContentType "application/json" -Body $loginBody
$token = $loginResponse.accessToken
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
```

## Customer login (HTTPS :8181)

Use SSL bypass + `https://localhost:8181/auth/login` — full script in `GEMINI.md` Section 32.1.

## Test endpoint (always try/catch)

```powershell
try {
  $response = Invoke-RestMethod -Uri "http://localhost:6144/[endpoint]" -Method POST -Headers $headers -Body $body
  $response | ConvertTo-Json -Depth 5
} catch {
  Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
  Write-Host "Error: $($_.ErrorDetails.Message)"
}
```

## Interpret results

| Response | Meaning |
|----------|---------|
| `isSuccess: true` | OK |
| `AccessUnAuthorized` + empty code | Validation error (not auth) |
| HTTP 401 | Re-login |
| HTTP 400 Problem | Business logic error |
| Connection refused | Start API: `rtk dotnet run --project Admin/Api` |

## After POST

GET list with `PageIndex=0&PageSize=10` to confirm persistence.
