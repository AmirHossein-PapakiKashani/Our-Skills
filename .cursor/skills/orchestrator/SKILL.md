---
name: orchestrator
description: >-
  Route Elay Backend tasks through investigation, CQRS scaffold, and verification.
  Use at the start of any feature request, bug fix, or refactor in this repo.
  Invoke with /orchestrator or when the user asks to orchestrate a task.
---

# Elay Orchestrator

You coordinate work for the Elay Backend (.NET 9, CQRS, Admin + Customer contexts).
You do **not** replace project rules — `.cursor/rules/` and `AGENTS.md` always apply.

## Step 0 — Classify the task

| Signal | Route |
|--------|-------|
| Messaging, Secretariat, OrgChart, Permit, Notification | → **scenario-contract** (mandatory), then wait for approval |
| Brand-new Command or Query | → **scenario-contract** (mandatory), then wait for approval |
| Simple bug fix in one known handler | → fix directly (GEMINI.md Section 27), then **verify-feature** |
| New CRUD vertical slice | → **scenario-contract** if sensitive, else **cqrs-scaffold** after brief plan |
| Blazor UI only | → GEMINI.md Section 29, then **verify-feature** (build only unless API touched) |
| User says "تایید شد" or "approved" after investigation | → **cqrs-scaffold** (or continue approved fix) |

## Step 1 — Pre-task protocol (always)

Before any code, output exactly:

```
Sections I will read: [...]
Files I will CREATE: [...]
Files I will MODIFY: [...]
Assumptions I am making: [...]
```

Use `AGENTS.md` pre-task map (top of file) to pick sections.

## Step 2 — Discovery tools (mandatory for code exploration)

1. `codebase-memory-mcp`: `search_graph` / `search_code` / `get_code_snippet` / `trace_path`
2. Shell: prefix every command with `rtk` (show `RTK ▸ rtk <cmd>` in chat)
3. **FORBIDDEN** for `.cs`: Cursor Grep/Glob as first exploration step

For large blast-radius mapping, launch `explore` subagent with:

```
MANDATORY: Use codebase-memory MCP (search_graph, search_code, get_code_snippet).
FORBIDDEN: Grep, Glob, ripgrep for .cs files.
Shell: prefix with rtk.
```

## Step 3 — Investigation gate

If **scenario-contract** applies:

1. Read and follow `.cursor/skills/scenario-contract/SKILL.md`
2. Present Investigation Report + Scenario Contract table(s)
3. **STOP** — no file creation, no code edits
4. Wait for user: `approved` or `تایید شد`
5. If user says "ok continue" but open questions remain → ask to resolve them first

## Step 4 — Execute

After approval (or when investigation not required):

1. Read `.cursor/skills/cqrs-scaffold/SKILL.md` + `references/*` for new features
2. Or apply minimal fix per `AGENTS.md` Section 27 for bugs
3. Never touch: `Program.cs`, `Migrations/**`, `Share/SharedKernel.Domain/Abstractions/**`

## Step 5 — Verify

Always end with `.cursor/skills/verify-feature/SKILL.md`:

- Build must pass
- API smoke test if endpoint changed
- Scenario Coverage table if a contract was approved

## Step 6 — Optional subagents

| When | Subagent |
|------|----------|
| Large unknown blast radius | `explore` (readonly) |
| Before merge / after big change | `bugbot` |
| Auth, permit, secrets | `security-review` |
| CI failure | `ci-investigator` |

## Hard rules (never violate)

- No `IMapper` — Mapster `.Adapt<T>()` only
- HTTP 200 for success — never 201 Created
- Check `.IsSuccess` before `.Value`
- `CancellationToken` on every async I/O
- Soft delete only — never `Remove()`
- Namespaces without `Admin.` / `Customer.` prefix
- Preserve typos: `Commads`, `Extentions`, `EndPoint`
- Migrations: flag human — never generate migration files

## User kickoff template

When user starts a task, they may paste:

```
/orchestrator
Feature: [name]
Context: [Admin | Customer]
Task: [one paragraph]
```

You respond with classification, plan, and next skill to run.
