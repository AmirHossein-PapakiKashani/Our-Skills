---
name: verify-feature
description: >-
  Post-implementation verification for Elay Backend. Mandatory build check,
  optional API smoke test, and Scenario Coverage table. Use after cqrs-scaffold
  or any code change before reporting task complete.
---

# Verify Feature — Elay Backend

Run this **before** declaring any task complete or committing.

## 1. Build check (mandatory)

```powershell
rtk dotnet build Elay.sln
```

- Any error → fix before reporting done
- Show `RTK ▸ rtk dotnet build Elay.sln` in chat before running

For scoped check:

```powershell
rtk dotnet build Admin/Core/Application/Application.csproj
rtk dotnet build Customer/Api/Api.csproj
```

## 2. Linter / diagnostics

If files were edited, check IDE diagnostics on changed files only.

## 3. API smoke test (when API touched)

Follow `references/api-testing-quickref.md` and `AGENTS.md` Section 32. Summary:

### Customer API — Postman / integration (mandatory credentials)

When the user asks for Postman integration tests, **or** you build/run a Customer collection:

1. **Read first:** `references/postman-test-users.md`
2. Authenticate with the four ChatTest users only (`chattest_sara` … `chattest_kian`)
3. State in the report: `Using test users from: references/postman-test-users.md`
4. Enforced by rule: `.cursor/rules/postman-integration-tests.mdc`

### Admin API (HTTP)

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

### Customer API (HTTPS)

Use Section 32.1 SSL bypass + `https://localhost:8181/auth/login`.

### Test the endpoint

Always wrap in try/catch to see error body (Section 32.3).

After POST/PUT, GET list to confirm persistence (Section 32.6).

**Do not** run raw SQL — verify through API only.

If API is not running, state `Blocked` for API scenarios and tell user to start:

```powershell
rtk dotnet run --project Customer/Api
# or Admin/Api
```

## 4. Scenario Coverage table (if contract was approved)

If `scenario-contract` produced an approved table, update every row:

| ID | Status | Evidence |
|----|--------|----------|
| S01 | Covered / Blocked / N/A | Actual response excerpt or reason |

Rules:

- `Covered` only with real request/response evidence
- `Blocked` with explicit blocker (e.g. migration pending)
- Never report **finished** with unexplained `Pending` rows

## 5. Migration reminder

If entity/DbSet was added, repeat migration command for human (Section 26) — do not run EF yourself.

## 6. Final report format

```
## Verification Report

- Build: PASS / FAIL
- API tests: [endpoints tested or N/A]
- Migration: [command or N/A]

### Scenario Coverage (if applicable)
| ID | Status | Evidence |
|----|--------|----------|
| ... | ... | ... |

### Remaining blockers
- [none or list]
```

## Optional — deeper review

Before merge on sensitive changes:

- `bugbot` subagent on branch changes
- `security-review` for auth/permit/secrets
