---
name: verify-feature
description: >-
  Post-implementation verification for any backend: build/typecheck, optional
  API smoke test, and scenario coverage table. Use after scaffold or any code
  change before reporting task complete.
---

# Verify Feature (Global)

Prefer project `verify-feature` if present. Run **before** claiming done or committing.

## 1. Build (mandatory)

Detect and run:

```powershell
# .NET
rtk dotnet build <solution-or-csproj>

# Node
rtk npm test   # or project script: rtk npm run build
```

Show `RTK ▸` first. Any error → fix before “done”.

## 2. Diagnostics

Check IDE lints on **edited files only**.

## 3. API smoke (when API touched)

1. Confirm API is running (or state Blocked)
2. Obtain auth the way the project documents (never invent production credentials)
3. Call changed endpoints; wrap HTTP errors to show body
4. After write: read-back via GET to confirm persistence
5. Prefer API over raw SQL

If project has `references/api-testing-quickref.md` or Postman rules — follow those.

## 4. Scenario Coverage (if contract existed)

| ID | Status | Evidence |
|----|--------|----------|
| S01 | Covered / Blocked / N/A | response excerpt or reason |

No unexplained `Pending` when reporting finished.

## 5. Migration reminder

If schema changed: print exact EF/Alembic/Prisma command for the human — do not apply unless asked.

## 6. Report

```
## Verification Report
- Build: PASS / FAIL
- API tests: [list or N/A]
- Migration: [command or N/A]
### Scenario Coverage
...
### Remaining blockers
...
```

Optional: `bugbot` / `security-review` before merge on sensitive changes.
