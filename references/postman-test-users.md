# Postman Integration Test Users (Customer API)

> **Canonical source of truth** for Customer API Postman / Newman integration tests.
> Cursor **MUST** read this file before writing or running any Postman integration collection for Customer features.
> Do **not** invent usernames, passwords, or user IDs. Do **not** use Admin credentials (`a.kashani`) for Customer multi-user flows.

---

## Environment

| Setting | Value |
|---------|-------|
| Bounded context | Customer |
| Base URL (HTTP) | `http://localhost:5144` |
| Login path | `POST {{baseUrl}}/Auth/Login` |
| Shared password | `Test@12345` |
| Seed script | `.cursor/CreateChatTestUsers/Program.cs` |

Start API if needed:

```powershell
rtk dotnet run --project Customer/Api
```

---

## The four ChatTest application users

| Alias | Username | Display name | Phone | UserId | Role in multi-user tests |
|-------|----------|--------------|-------|--------|--------------------------|
| **U1** | `chattest_sara` | Sara ChatTest | `09120000001` | `2746` | Primary actor / initiator |
| **U2** | `chattest_reza` | Reza ChatTest | `09120000002` | `2747` | Peer / acceptor |
| **U3** | `chattest_nima` | Nima ChatTest | `09120000003` | `2748` | Third party / group member |
| **U4** | `chattest_kian` | Kian ChatTest | `09120000004` | `2749` | Fourth party / observer |

> `UserId` values are from the local DB used by existing Chat collections. If login works but profile IDs differ after DB reset, refresh IDs from `GET /chat/profile` (or equivalent) and update this table.

---

## Collection variables (required naming)

Use these exact Postman collection variable keys:

| Variable | Source |
|----------|--------|
| `baseUrl` | `http://localhost:5144` |
| `token_u1` … `token_u4` | Set after each login from `accessToken` |
| `userId_u1` … `userId_u4` | Prefer known IDs above; confirm via Profile when needed |

---

## Login request body (template)

Reuse this body for each user (change only `username`):

```json
{
  "username": "chattest_sara",
  "password": "Test@12345",
  "deviceInfo": {
    "deviceID": "BE2A.250530.026.F3",
    "deviceName": "postman-test-device",
    "deviceVersion": "16",
    "appVersion": "2.113.0",
    "platform": "android"
  }
}
```

### Auth setup folder (mandatory first)

Every new Customer Postman integration collection **must** start with folder `0. Auth (Setup)` that:

1. Logs in U1 → saves `token_u1`
2. Logs in U2 → saves `token_u2`
3. Logs in U3 → saves `token_u3`
4. Logs in U4 → saves `token_u4`
5. Optionally calls Profile for each and asserts `userId` matches the table (or updates variables)

---

## PowerShell smoke login (one user)

```powershell
$baseUrl = 'http://localhost:5144'
$loginBody = @{
  username = 'chattest_sara'
  password = 'Test@12345'
  deviceInfo = @{
    deviceID = 'BE2A.250530.026.F3'
    deviceName = 'postman-test-device'
    deviceVersion = '16'
    appVersion = '2.113.0'
    platform = 'android'
  }
} | ConvertTo-Json -Depth 3

$login = Invoke-RestMethod -Uri "$baseUrl/Auth/Login" -Method POST -ContentType 'application/json' -Body $loginBody
$token = $login.accessToken
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
```

---

## Rules for agents

1. **Always** `Read` this file before creating/editing Postman collections or Newman scripts for Customer API.
2. **Always** authenticate with these four users for full multi-actor coverage when the feature involves more than one user.
3. For single-actor smoke tests, still use **U1** (`chattest_sara`) — never a random username.
4. Cite this path in the verification report: `references/postman-test-users.md`.
5. Admin API tests remain separate (`a.kashani` / see `references/api-testing-quickref.md`).

---

## Recreate users if missing

```powershell
rtk dotnet run --project .cursor/CreateChatTestUsers
```
```

