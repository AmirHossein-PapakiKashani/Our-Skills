---
name: scenario-contract
description: >-
  Use before generating any agent execution prompt for sensitive domains
  (Messaging/Secretariat/OrgChart/Permit/Notification) or any new Command/Query
  in the Elay Backend project. Mandatory investigation + scenario coverage step
  that must complete and be explicitly approved before any code is written.
---

# Scenario Contract & Investigation Phase

## When to trigger

- Messaging (نامه/پیام), Secretariat (دبیرخانه), OrgChart, Permit, Notification
- Brand-new Command or Query (any domain)
- User flags feature as sensitive

If none apply, skip this skill — go to `cqrs-scaffold` via `orchestrator`.

## What to do (in order)

### 1. Map blast radius

List every file touching the entity/data — not just the obvious handler:

- Entity + EF configuration
- All handlers on same DbSet (including other features)
- Carter endpoints
- Blazor ViewModels/pages (if UI in scope)
- PDF/Word templates

Use `codebase-memory-mcp` (`search_graph`, `trace_path`). State list explicitly.
If you cannot find a file with confidence, say so — never guess.

### 2. Read every file from step 1

Full read via `get_code_snippet` / `Read`. Do not infer from names.
Do not assume `.Include()` without verifying.

### 3. Build Scenario Contract(s)

**One table per Command or Query** — not one per whole feature.

Full template and categories: `references/section-33-34-full.md`

Every mandatory category (33.2) needs a row or explicit `N/A — [reason]`.
For sensitive domains, categories 9 (side effects) and 10 (ripple effects) are **never** N/A.

### 4. Answer blast radius question

```
What existing behavior could this change break?
- [handler/feature]: [why, or "not affected because ..."]
```

### 5. Present Investigation Report

Output all of:

1. **Files read** (paths)
2. **Blast radius answer**
3. **Draft Scenario Contract(s)** (filled tables, Status = Pending)
4. **Open questions** for Pazhvak

### 6. STOP — hard gate

- Do NOT write code
- Do NOT invoke `cqrs-scaffold`
- Do NOT generate "final execution prompt" for another agent

Wait for: **`approved`** or **`تایید شد`**

"ok continue" without resolving open questions → ask for explicit resolution first.

## After implementation (handoff to verify-feature)

When code is done, every contract row must move to `Covered` with API evidence
(`references/api-testing-quickref.md`). Report coverage table — see 34.8 in `references/section-33-34-full.md`.

## Parallel discovery

For wide blast radius, launch `explore` subagent (readonly) with codebase-memory MCP mandatory.
