---
name: orchestrator
description: >-
  Route backend tasks through investigation, scaffold, fix, or verification.
  Use at the start of any feature, bug fix, refactor, or new endpoint.
  Invoke with /orchestrator. Prefers project .cursor/skills when present.
---

# Backend Orchestrator (Global)

Coordinate work for **any** backend repo. Project-local skills/rules override this skill when they exist under `.cursor/skills/`.

## Step 0 — Detect project context

1. If `.cursor/skills/orchestrator/SKILL.md` exists → **follow that instead**
2. Else if `AGENTS.md` / `GEMINI.md` / `.cursorrules` exists → treat as project law
3. Else use this global flow + `~/.cursor/rules/`

## Step 1 — Classify

| Signal | Route |
|--------|-------|
| `/phase-orchestrator`, investigate→plan→implement, research before each phase | → **phase-orchestrator** |
| `/phase-cycle`, multi-phase epic without per-phase plan gate | → **phase-cycle** |
| Sensitive domain (auth, payments, messaging, permissions, org, notifications) | → **scenario-contract**, wait for approval |
| Brand-new Command / Query / endpoint / mutation | → **scenario-contract**, then scaffold |
| Simple bug in one known handler | → minimal fix, then **verify-feature** |
| New CRUD / CQRS vertical slice (.NET) | → **cqrs-scaffold** after plan (or after approval if sensitive) |
| UI-only | → project UI docs; **verify-feature** (build) |
| User says `approved` / `تایید شد` | → continue plan/implement or approved fix (check phase-orchestrator state first) |
| `Start Stage 2` / `Start Postman` / `Start E2E` / `شروع تست` | → **phase-orchestrator** or **phase-cycle** Stage 2 if state awaits verification |

## Step 2 — Pre-task protocol (always)

Before code, state:

```
Sections/docs I will read: [...]
Files I will CREATE: [...]
Files I will MODIFY: [...]
Assumptions I am making: [...]
```

## Step 3 — Discovery (mandatory)

1. codebase-memory MCP: `search_graph` / `search_code` / `get_code_snippet` / `trace_path`
2. Shell: every command with `rtk` + show `RTK ▸ rtk <cmd>`
3. No Grep/Glob for source as first step

Subagent prompt must include RTK + MCP mandatory lines.

## Step 4 — Investigation gate

If scenario-contract applies: read that skill, present report + tables, **STOP** until `approved` / `تایید شد`.

## Step 5 — Execute → Verify

Implement per project conventions (or global `cqrs-scaffold`), then always run **verify-feature**.

## Kickoff template

```
/orchestrator
Feature: [name]
Context: [bounded context or service]
Task: [one paragraph]
Stack: [.NET | Node | other — optional]
```

Phased epic — investigate → plan → implement (preferred when research comes first):

```
/phase-orchestrator
Feature: [name]
Stack: [backend | frontend | fullstack]
Start: next
Mode: single-phase
Gate: approve-plan
PhaseMap: docs/phase-map.md
```

Phased epic — continuous code-first Stage 1 (legacy phase-cycle):

```
/phase-cycle
Feature: [name]
Stack: [backend | frontend | fullstack]
Start: next
Mode: all-remaining
PhaseMap: docs/phase-map.md
```
