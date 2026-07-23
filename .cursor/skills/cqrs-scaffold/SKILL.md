---
name: cqrs-scaffold
description: >-
  Scaffold or extend CQRS vertical slices for .NET Clean Architecture backends
  (Command/Query/Handler/Endpoint/DTO). Use after orchestrator routing and after
  scenario-contract approval when required. Defers to project AGENTS.md when present.
---

# CQRS Scaffold — .NET (Global)

If `.cursor/skills/cqrs-scaffold` or `AGENTS.md` Section 25 exists → **follow the project**.

## Prerequisites

- [ ] Orchestrator classified the task
- [ ] Approval received if scenario-contract was required
- [ ] Pre-task protocol stated

## Phase 1 — Pre-flight

1. MCP search — no duplicate feature/DTO/endpoint
2. Confirm DbSet / repository / ID type from existing code
3. Mirror the **nearest existing** feature’s folder + namespace style (including intentional typos if the project has them)

## Phase 2 — Plan (before code)

```
Files I will CREATE:
- Domain entity (if new)
- DTO / input model
- Errors
- Command+Validator and/or Query
- Handler(s)
- API endpoint module

Files I will MODIFY:
- DbContext / interface (if new entity)
- DI / mapper registration (if required)
```

## Phase 3 — Generate (defaults; project overrides win)

| Topic | Default |
|-------|---------|
| Mapping | Use project mapper only (e.g. Mapster `.Adapt<T>()`) — do not add AutoMapper if unused |
| Result | Never read `.Value` without success check |
| Async | Forward `CancellationToken` |
| Handlers | try/catch → log → server error Result |
| Delete | Soft delete if project uses it |
| Audit | Do not set audit fields if an interceptor does |
| Migrations | Flag EF command for human — do not generate migration files |
| HTTP | Match project (many Elay-like APIs use 200 for create; do not invent 201 if project forbids it) |

Queries: `.AsNoTracking()`, sort before paginate, project’s pagination helper if any.

## Phase 4 — Checklist

- Namespaces match project
- No duplicate endpoints
- Auth/rate-limit metadata if siblings have them
- XML docs if project documents public APIs

## Phase 5 — Hand off

Run **verify-feature**.
