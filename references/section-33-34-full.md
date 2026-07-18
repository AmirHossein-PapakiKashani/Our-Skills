# Section 33 & 34 — Scenario Contract + Investigation Protocol

> Source of truth extracted from `GEMINI.md` / `CLAUDE.md` / `AGENTS.md`.
> Used by the `scenario-contract` skill. Do not edit casually — sync with master file if protocol changes.

---

## Section 33 — Scenario Contract Template

> Purpose: close the gap between "what should be covered" and "what was actually
> covered." A Scenario Contract is a filled table that exists **before** any
> agent execution prompt is written. No prompt is generated from memory of
> what scenarios "probably" matter — it is generated from this table.

> Granularity rule: build one Scenario Contract **per Command or Query**, not
> one per whole feature. A feature with Create + Update + Delete + GetAll gets
> four separate contracts. Granular contracts make missing coverage visible;
> a single contract for an entire feature hides gaps inside vague rows.

---

### 33.1 — Header (fill before the table)

```
Feature:            [e.g. ExternalRecipient]
Bounded Context:    [Admin | Customer]
Slice type:         [Command | Query]
Action:             [Create | Update | Delete | GetById | GetAll | Custom]
Planned files:      [list exact paths from Section 25.2 / Phase 2 plan]
Sensitive domain?:  [Yes — Messaging/OrgChart/Permit/Notification | No]
Drafted by:         Agent
Approved by:        [ ] Pending — Pazhvak must type "approved" / "تایید شد"
```

> ⚠️ HARD RULE: Agent must NOT generate executable code (Section 25 Phase 3)
> until this contract is reviewed and explicitly approved. A contract with
> unchecked categories is not approved, even if Pazhvak says "looks fine" —
> explicit approval text is required.

---

### 33.2 — Mandatory Scenario Categories

Every category below must have **at least one row** in the table, or a row
explicitly marked `N/A — [reason]`. Silent omission of a category is not
allowed.

| # | Category | Applies to |
|---|---|---|
| 1 | Happy path — success | All |
| 2 | Validation failure (one row **per FluentValidation rule**, not lumped) | All |
| 3 | Not found (missing entity; soft-deleted entity must behave as not found) | Update/Delete/GetById |
| 4 | Duplicate / Conflict (uniqueness constraints) | Create/Update |
| 5 | Unauthorized / Forbidden (role-based access, if applicable) | All |
| 6 | Pagination boundary (PageIndex=0, PageIndex past last page, PageSize edge values) | Queries (paginated) |
| 7 | Search/filter edge cases (empty key, special chars, case-insensitivity) | Queries (search) |
| 8 | Soft-delete interaction (query excludes deleted; delete sets IsDeleted, never hard-deletes) | All touching deletable entities |
| 9 | Domain-specific side effects (e.g. notification trigger, external flag bypass) | Sensitive domains — mandatory |
| 10 | Cross-entity ripple effects (other features reading same DbSet) | Sensitive domains — mandatory |
| 11 | Concurrency / idempotency (double-submit, race conditions) | Where relevant |
| 12 | CancellationToken / long-running behavior | Only if handler has loops or external calls |

---

### 33.3 — Scenario Table (copy and fill)

| ID | Category | Description | Precondition / Setup | Input | Expected Result | Priority | Status |
|---|---|---|---|---|---|---|---|
| S01 | Happy path | | | | `Result.Success()` with ... | Must | Pending |
| S02 | Validation | Rule: `Name` empty | | | `AccessUnAuthorized` w/ message containing "نام الزامی است" | Must | Pending |
| S03 | Not found | | | | `[Feature]Errors.NotFound` | Must | Pending |
| S04 | Conflict | | | | `[Feature]Errors.DuplicateName` | Must | Pending |
| S05 | Unauthorized | | | | 401/Forbidden per role policy | Should | Pending |
| S06 | Pagination | PageIndex beyond last page | | | Empty `Data`, correct `TotalCount` | Should | Pending |
| S07 | Search | Empty search key returns unfiltered list | | | Full list, paginated | Should | Pending |
| S08 | Soft delete | Soft-deleted row excluded from GetAll | | | Excluded from result set | Must | Pending |
| S09 | Domain side effect | [actual side effect name] | | | | Must | Pending |
| S10 | Ripple effect | [other feature/handler affected] | | | No regression in [other feature] | Must | Pending |
| S11 | Concurrency | | | | | Could | Pending |
| S12 | Cancellation | N/A — handler has no loop | — | — | — | N/A | N/A |

---

### 33.4 — Status Field Rules

`Status` only moves from `Pending` to `Covered` when there is **evidence** —
an actual executed request (per GEMINI.md Section 32) with real response output.

| Status | Meaning |
|---|---|
| `Pending` | Scenario identified, not yet tested |
| `Covered` | Tested with real request/response evidence attached |
| `N/A` | Explicitly does not apply, with stated reason |
| `Blocked` | Cannot be tested yet (e.g. depends on a migration not yet applied) |

A task is **not complete** while any row is `Pending`.

---

## Section 34 — Investigation Phase Protocol (Sensitive Features)

> Sensitive system areas always get an investigation phase before implementation.
> Mandatory output: Section 33 Scenario Contract (not free-form analysis).

---

### 34.1 — When This Section Is Mandatory

Trigger whenever the task touches any of:

- Messaging (نامه/پیام) — Secretariat (دبیرخانه), signed messages, external recipients
- Organizational chart (OrgPositions / JobTitle tree)
- Permit / form workflows
- Notification system
- Any feature Pazhvak explicitly flags as sensitive

For simple CRUD / reference data / UI-only: Section 33 is **recommended** but full
blast-radius mapping (34.2) is optional unless touching shared concerns
(audit interceptor, soft-delete filter, `IApplicationDbContext`).

---

### 34.2 — Step 1: Map the Blast Radius

List **every file** that touches the entity/data:

- Entity + EF configuration
- Every handler reading/writing the same DbSet
- Handlers in **other** features using the same DbSet
- Carter endpoints
- Blazor ViewModels/pages (if UI in scope)
- PDF/Word templates referencing this data

State the list explicitly. If a file cannot be found with confidence, say so.

**Use codebase-memory MCP:** `search_graph`, `trace_path`, `get_code_snippet` —
not Grep for `.cs` files.

---

### 34.3 — Step 2: Read, Don't Skim

Read each file from 34.2 in full. Do not infer from file names or similar features.
Do not assume `.Include()` chains exist without verifying.

---

### 34.4 — Step 3: Build the Scenario Contract

One contract per Command/Query. For sensitive domains, categories 9 and 10 are
**never** `N/A` — if they seem not to apply, re-check blast radius from 34.2.

---

### 34.5 — Step 4: Answer the Blast Radius Question

```
What existing behavior could this change break?
- [Feature/handler 1]: [why affected, or "not affected because ..."]
- [Feature/handler 2]: ...
```

If uncertain, say so — never write reassuring but unverified claims.

---

### 34.6 — Step 5: Present the Investigation Report

Before any code:

1. Files read (34.2 + 34.3)
2. Blast radius answer (34.5)
3. Draft Scenario Contract(s) (34.4 / Section 33)
4. Open questions needing Pazhvak's confirmation

---

### 34.7 — Step 6: Stop and Wait

Do NOT proceed to scaffold/code until Pazhvak replies with **"approved"** or **"تایید شد"**.
"ok continue" without resolving open questions is NOT sufficient.

---

### 34.8 — Closing the Loop: Implementation → Evidence

Task is done when every approved contract row is `Covered` with real evidence
(GEMINI.md Section 32 API testing).

Final message must include:

```
Scenario Coverage:
| ID  | Status   | Evidence |
|-----|----------|----------|
| S01 | Covered  | [response excerpt] |
| S02 | Covered  | ... |
```

Never report finished with unexplained `Pending` rows.

> Do NOT run raw SQL against the database. Verify through API endpoints.
