---
name: scenario-contract
description: >-
  Investigation and scenario-coverage gate before coding sensitive domains or
  any new Command/Query/endpoint. Must complete and be approved before writes.
  Use for auth, payments, messaging, permissions, org, notifications, or new mutations.
---

# Scenario Contract & Investigation (Global)

Prefer project `scenario-contract` / Section 33–34 docs if present.

## When to trigger

- Auth, payments, messaging, secretariat/workflow, org chart, permits, notifications
- Brand-new Command, Query, endpoint, or schema-affecting change
- User marks the feature as sensitive

Otherwise skip → go to scaffold/fix via orchestrator.

## Steps

### 1. Map blast radius (MCP)

List every related file: entity, configs, handlers, endpoints, UI, jobs, templates.
Use `search_graph` + `trace_path`. Never guess paths.

### 2. Read the files

`get_code_snippet` / targeted `Read`. Do not infer from names alone.

### 3. Scenario Contract table (one per Command/Query)

Minimum rows (or `N/A — reason`):

| Category | Example |
|----------|---------|
| Happy path | Valid create/update/read |
| Validation | Empty/invalid fields |
| AuthZ | Unauthorized / forbidden |
| Not found | Missing ids |
| Conflict / duplicate | Unique constraints |
| Side effects | Notifications, outbox, files |
| Ripple | Other handlers sharing DbSet/table |

Sensitive domains: side effects + ripple are **never** N/A without justification.

### 4. Blast radius answer

```
What existing behavior could this change break?
- [handler/feature]: [why, or "not affected because ..."]
```

### 5. Investigation Report

1. Files read  
2. Blast radius  
3. Draft contracts (Status = Pending)  
4. Open questions for the user  

### 6. HARD STOP

No code, no scaffold, no “final prompt” for another agent until:

**`approved`** or **`تایید شد`**

Ambiguous “ok continue” with open questions → resolve questions first.

## After implementation

Hand off to **verify-feature**; every contract row → Covered with evidence or Blocked with reason.
