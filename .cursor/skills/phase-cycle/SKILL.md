---
name: phase-cycle
description: >-
  Run a two-stage phased delivery cycle on any backend or frontend: Stage 1
  implements and commits remaining phases continuously after one approval;
  Stage 2 waits for a separate approval then verifies each phase with real
  E2E (Postman/Newman, Playwright, Cypress, or project test suite) until all
  Must scenarios pass. Use for /phase-cycle, start/continue/finish phased delivery.
---

# Two-stage phase cycle (Global — Backend & Frontend)

Coordinate `scenario-contract`, project scaffold skills, and `verify-feature`
across an ordered phase list defined by the **project phase map**.

Prefer project `.cursor/skills/phase-cycle` if present. Otherwise use this skill
+ the project's `docs/phase-map.md` (or path recorded in state).

## Mental model — NON-NEGOTIABLE

```text
STAGE 1 — DEVELOPMENT (one approval)
  Owner: /phase-cycle  |  Start Stage 1  |  شروع پیاده‌سازی فازها
  Agent: implement Phase firstIncomplete → … → last
         per-phase commit, NO per-phase "تایید شد"
  Then: STOP + development-summary
  WAIT — do NOT start real E2E

STAGE 2 — VERIFICATION (second, separate approval)
  Owner: Start Stage 2 | Start Postman | Start E2E | شروع تست
  Agent: verify phase-by-phase with REAL runners until Must scenarios pass
```

**Never** mix stages.  
**Never** start Stage 2 because Stage 1 finished.  
**Never** ask “continue to Phase N?” during Stage 1 after cycle approval — continue.

## Stack modes

Detect from kickoff / repo markers; store in state as `stack`:

| Mode | Typical Stage 1 | Typical Stage 2 runner |
|------|-----------------|-------------------------|
| `backend` | API/handlers/services | Postman, Newman, `.http`, integration tests |
| `frontend` | UI/pages/components | Playwright, Cypress, Vitest+RTL (E2E preferred for Must) |
| `fullstack` | BE then FE slices per phase map | API suite + UI E2E as map requires |

Do not invent a runner. Prefer what the phase map / project docs name.

---

## Bootstrap (required once per feature)

Before Stage 1, these must exist (create them with owner if missing):

| Artifact | Default path | Purpose |
|----------|--------------|---------|
| Phase map | `docs/phase-map.md` | Ordered phases, scope, Must demos, deps |
| Scenario contracts | path in map | Must/Should rows per phase |
| Implementation guide | path in map | What each phase ships |
| State file | `.cursor/phase-cycle-state.json` | Machine state only |
| Reports dir | `docs/Phase-Reports/` | Per-phase + summaries |

Templates: see [BOOTSTRAP.md](BOOTSTRAP.md), [phase-map.template.md](phase-map.template.md),
[state.template.json](state.template.json), [report-templates.md](report-templates.md).

If artifacts are missing:

1. Draft phase map + empty state from templates.
2. Present draft to owner.
3. **STOP** until owner confirms map (or says Stage 1 with that draft accepted).

Never invent business rules to fill gaps — mark `Open product decision`.

---

## Invocation

### Stage 1

```text
/phase-cycle
Feature: [name]
Stack: [backend | frontend | fullstack]
Start: [phaseId | next]
Mode: all-remaining
PhaseMap: [path — optional if default]
Branch: [optional preferred branch name]
```

Persian OK: `شروع پیاده‌سازی فازها` / `مرحله ۱` / `Stage 1`.

That approval authorizes: **implement + build-verify + commit every remaining
phase in one continuous run**.

It does **not** authorize:

- real DB / production-like E2E as acceptance evidence;
- Stage 2 runners (Postman/Playwright/…) for pass/fail of the cycle;
- migrations / destructive cleanup;
- push / PR;
- inventing product rules beyond the guides.

### Stage 2

Only when state is `awaitingVerificationApproval` (or legacy `awaitingPostmanApproval`)
and owner says one of:

```text
Start Stage 2
Start Postman
Start E2E
شروع تست
شروع تست پست‌من
approved for verification
```

---

## State machine

File: `.cursor/phase-cycle-state.json` (never commit secrets/tokens/env values).

```text
development:
  contractChecked → implemented → businessVerified → committed → nextPhase
  → developmentComplete → awaitingVerificationApproval

verification:
  verificationApproved → phaseTesting → phasePassed → nextPhase
  → allPhasesPassed
```

Minimal fields: `feature`, `stack`, `stage`, `status`, `branch`, `currentPhase`,
`phaseOrder`, `authorization`, `phaseResults`, `verificationPhaseResults`,
`commits`, `reportsDir`, `phaseMapPath`, `updatedAt`.

Workflow artifacts (may stay unstaged during cycle; do not ignore unrelated dirty files):

- `.cursor/phase-cycle-state.json`
- `{reportsDir}/Phase-*-development.md`
- `{reportsDir}/Phase-*-verification.md` (alias `*-postman.md` for API-only projects)
- `{reportsDir}/development-summary.md`
- `{reportsDir}/verification-summary.md` (alias `postman-summary.md`)

---

## Stage 1 — Branch & pre-task

Before code:

```text
Phase I am on: [id]
Feature: [...]
Stack: [backend|frontend|fullstack]
Phase map: [path]
Sections/docs I will read: [...]
Files I will CREATE: [...]
Files I will MODIFY: [...]
Assumptions I am making: [...]
```

Git (always `rtk`; show `RTK ▸`):

1. `rtk git status --short --branch`
2. Stop if pre-existing user changes overlap — never stash/reset/discard for them
3. Do not implement on `main`/`master` unless owner said so
4. Create/resume one cumulative branch (from state or `codex/<feature-slug>-phases`)
5. Working tree must be clean before creating the branch (unless resuming)
6. `rtk git log -10 --pretty=format:%s` — match commit style
7. Never push automatically

---

## Stage 1 — Continuous implementation

Process phases in **phase map order**, from first incomplete.

### Continuous-run rule

While `Mode: all-remaining` / Stage 1 active:

- Run scenario-contract **internally** (blast radius + Must checklist).
- **Do NOT** stop for per-phase `approved` / `تایید شد`.
- Stage 1 approval already covers documented contracts for this feature.
- Stop mid-Stage-1 **only** for Hard blockers.

### Per phase

1. Internal contract check vs scenario doc for that phase.
2. Re-read implementation guide for that phase (+ security/domain docs if sensitive).
3. Discover code via **codebase-memory MCP** first (`search_graph`, `get_code_snippet`, `trace_path`).
4. Write endpoint/UI/rule checklist into development report — **no invented business rules**.
5. Implement **only** this phase (scaffold skill / targeted edit / FE components).
6. Respect project DO-NOT-TOUCH lists (e.g. migrations, composition roots).
7. Keep compatibility guarantees from the map (legacy routes, flags, old screens).
8. Build/typecheck (`rtk` + project command) until green or hard blocker.
9. Commit when allowed; write `Phase-<id>-development.md`; update state; **start next phase without asking**.

Stage 1 acceptance = contracts + build/typecheck (+ unit tests if map requires).  
Stage 1 does **not** claim real E2E / API Verified.

---

## Stage 1 — Commit gate

Commit only when:

- phase scope from map is implemented;
- build/typecheck green;
- docs updated if public contracts/routes/UI copy changed;
- no secrets staged;
- staged diff is only this phase (+ intentional shared prerequisites);
- no accidental product-rule rewrite outside guides.

Procedure:

1. `rtk git status --short`
2. Stage **explicit paths** — no blind `git add .`
3. `rtk git diff --cached`
4. Unstage secrets/unrelated without discarding working tree
5. Commit (Conventional Commits if project uses them)

Record hash in state + development report → next phase.

---

## End of Stage 1 — HARD STOP

After all remaining phases are business-verified and committed:

1. Write `development-summary.md`
2. State: `developmentComplete` → `awaitingVerificationApproval`
3. Prepare Stage 2 **plan only** (base URL, users, collection/spec path, markers, cleanup) — do not execute
4. Show: commits, build status, open decisions, exact Stage 2 phrase
5. **STOP**

```text
Stage 1 (development) complete. Awaiting Stage 2.
Say: Start Stage 2 / Start E2E / Start Postman / شروع تست
```

---

## Stage 2 — Prepare real verification

Only after Stage 2 phrase:

1. Resolve env/config without printing secrets
2. Prove target is local/staging — not production
3. Confirm app under test points at that target
4. Use **only** documented test users/accounts
5. Prefer official seed/API paths over raw DB writes
6. Unique run markers + scoped cleanup; honor soft-delete / data rules

Never migrate / hard-delete / broad update without separate approval.

---

## Stage 2 — Per-phase verification

Map Must scenarios from the scenario contract doc.

Runner must hit the **real** running system. Mocks do not count as Passed.

For each phase in order:

1. Execute every **Must** scenario for that phase
2. Assert status/shape/UI outcomes and critical values
3. Re-read persisted state / UI when side effects expected
4. Write sanitized evidence to `Phase-<id>-verification.md`
5. Stay on phase until all Must rows pass

Fix loop:

```text
fail → diagnose → fix → build → restart if needed
    → rerun failed → rerun related regressions → repeat
```

MCP first for diagnosis. If a later fix can break an earlier phase, re-run
affected earlier groups before advancing.

### Commit after phase passes

- code fixes: `fix(...): …`
- durable sanitized suites/reports: `test(...): …`
- never commit tokens/passwords/connection strings/populated envs
- no empty commit if nothing changed

Then next phase. When all pass: `verification-summary.md`, state `allPhasesPassed`,
list commits. Do not push without approval.

---

## Completion meanings

| Label | Meaning |
|-------|---------|
| Development Complete | Implemented + build verified + phase committed |
| Verified (API/UI) | Every real Must scenario for the phase passed |
| Project Complete | All phases are Development Complete **and** Verified |

Never call Verified / Project Complete during Stage 1.

---

## Hard blockers (only legal mid-cycle stops)

- Overlapping dirty user changes
- Material conflict in source contracts
- Credentials/DB/app target missing or looks like production
- Migration / destructive action needs new approval
- Safe scoped commit impossible
- Product decision required but owner forbade inventing rules

Report: blocker, completed work, current phase, last green commit, smallest resume action.

---

## Related skills

| Skill | Role |
|-------|------|
| `orchestrator` | Routes “run all phases” here |
| `scenario-contract` | Internal per-phase investigation |
| `cqrs-scaffold` | .NET BE slices |
| `verify-feature` | Build + coverage after changes |
| `api-smoke-test` | HTTP smoke helpers in Stage 2 |
| Project FE skills | UI implementation / Playwright |

---

## Quick owner phrases

| Intent | Say |
|--------|-----|
| Start continuous build+commit | `/phase-cycle` … `Mode: all-remaining` |
| Allow real E2E | `Start Stage 2` / `شروع تست` |
| Resume after blocker | `Resume phase-cycle` + resolve blocker |
| Stop everything | `Abort phase-cycle` (persist state; do not discard user work) |
