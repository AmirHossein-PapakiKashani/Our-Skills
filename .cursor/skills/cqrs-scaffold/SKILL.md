---
name: cqrs-scaffold
description: >-
  Scaffold or extend CQRS features in Elay Backend (Command/Query/Handler/Endpoint/DTO).
  Use after orchestrator routing and after scenario-contract approval when required.
  Follows AGENTS.md Section 25.
---

# CQRS Scaffold — Elay Backend

## Prerequisites

- [ ] `orchestrator` classified the task
- [ ] If sensitive or new Command/Query: user replied `approved` / `تایید شد`
- [ ] Pre-task protocol stated (sections, files CREATE/MODIFY, assumptions)

## Phase 1 — Pre-flight (mandatory)

Before writing files:

1. `search_graph` / `search_code` — feature folder, DTO, endpoint must not duplicate existing work
2. Confirm `DbSet` name from `IApplicationDbContext` if entity exists
3. Confirm entity ID type (`int` vs `Guid`)

State findings explicitly.

## Phase 2 — File generation plan

Output plan before any code (`AGENTS.md` Section 25 Phase 2):

```
Files I will CREATE:
1. [Context]/Core/Domain/Models/[Feature]/[Feature].cs     ← if new entity
2. [Context]/Core/Application/DTOs/[Feature]Dto.cs
3. [Context]/Core/Application/Errors/[Feature]Errors.cs
4. [Context]/Core/Application/Features/[Feature]/Commads/[Action][Feature]Command.cs
5. [Context]/Core/Application/Features/[Feature]/Commads/[Action][Feature]CommandHandler.cs
6. [Context]/Api/EndPoint/[Feature]/[Feature][Method]EndPoint.cs
(+ Queries if read slice)

Files I will MODIFY:
- [Context]/Core/Application/Data/IApplicationContext.cs    ← DbSet if new entity
- [Context]/Infrastructure/Data/ApplicationDbContext.cs       ← DbSet if new entity
- [Context]/Core/Application/Extentions/MapsterConfig.cs
```

Paths: `references/file-locations.md`. Templates: `references/templates.md`. Namespaces: `references/namespaces.md`.  
Architecture depth: `AGENTS.md` Sections 1–24, 25 Phase 0–1, 27–28.

## Phase 3 — Code generation

Critical rules (override everything):

| Rule | Detail |
|------|--------|
| Namespace | No `Admin.` / `Customer.` — see Section 25.1 |
| Typos | `Commads`, `Extentions`, `EndPoint` — preserve |
| Mapping | Mapster `.Adapt<T>()` — no `IMapper` |
| HTTP | Always 200 OK — never 201 |
| Async | `CancellationToken` forwarded to all I/O |
| Handlers | try/catch → `Log.Error` → `Error.ServerError` |
| DI | Primary constructors: `Handler(IDep dep)` |
| Audit | Never set CreateBy/CreateDate manually |
| Delete | Soft delete: `IsDeleted = true` — never `Remove()` |
| Endpoints | `.RequireRateLimiting(RateLimitConst.RateFix)` + `.RequireAuthorization()` |
| Result | Check `res.IsSuccess` before `res.Value` |

### Queries with pagination/search

Follow `AGENTS.md` Section 28:

- `.AsNoTracking()` on reads
- `Pagination(request.Request)` — PageIndex is **zero-based**
- Search: `EF.Functions.Like` — not `.Contains()` for free text

## Phase 4 — Post-generation checklist

Verify every item in `AGENTS.md` Section 25 Phase 4.

If new entity or DbSet added, output migration command from `references/migrations-quickref.md`.

Do **not** run `dotnet ef migrations add` yourself.

## Phase 5 — Hand off

Invoke `verify-feature` skill:

- `rtk dotnet build Elay.sln`
- API test if endpoint added/changed
- Scenario Coverage table if contract exists

## Bug fix shortcut

If task is fix-only (not scaffold):

1. `search_code` for error/symbol
2. `trace_path` for callers
3. Minimal edit per Section 27
4. `verify-feature`
