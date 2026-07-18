# Elay Backend — Cursor Agent Skills

Orchestration layer for AI agents working on this repo. Complements `AGENTS.md` (master manual), `references/`, and `.cursor/rules/`.

## Skills

| Skill | When to use |
|-------|-------------|
| **orchestrator** | Start of every task — routes to other skills |
| **scenario-contract** | Sensitive domains or new Command/Query — investigation before code |
| **cqrs-scaffold** | After approval — create/fix CQRS vertical slices |
| **verify-feature** | After any code change — build, API test, coverage table |

## Quick start

In Cursor Agent chat:

```
/orchestrator
Feature: Category
Context: Admin
Task: add paginated list query with search by name
```

For sensitive work, after investigation report:

```
تایید شد
```

## Flow

```
User request
    → orchestrator (classify + plan)
    → scenario-contract? (if required) → WAIT for تایید شد
    → cqrs-scaffold (code)
    → verify-feature (build + tests + coverage)
    → done
```

## References

See `references/README.md` for full index.

## Doc stack (what to read when)

| Need | Read |
|------|------|
| Start any task | `orchestrator` skill |
| Architecture, patterns | `AGENTS.md` Sections 1–32 |
| CQRS paths/templates | `references/file-locations.md`, `templates.md`, `namespaces.md` |
| Investigation / scenarios | `references/section-33-34-full.md` |
| RTK + MCP enforcement | `.cursor/rules/*.mdc` |
