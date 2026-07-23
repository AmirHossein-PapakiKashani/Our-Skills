---
name: phase-orchestrator
description: >-
  Accuracy-first phased delivery with explicit stack profiles (Side/Language/Framework
  e.g. Python FastAPI, .NET, Flutter): Investigation → Plan → Quality gate →
  Implement → Verify per phase; optional safe automation; Stage 2 E2E separate.
  Use for /phase-orchestrator or investigate-then-implement on any stack.
---

# Phase Orchestrator (Accuracy-first → then automate)

**Priority order:** (1) implementation accuracy (2) safe automation.  
Do **not** invent product/sales ideas here.

Prefer project `.cursor/skills/phase-orchestrator` if present.

## Mental model — NON-NEGOTIABLE

```text
OUTER
  STAGE 1 — DEVELOPMENT
    For each map phase:
      I  INVESTIGATION   (no code)
      P  PLAN            (binding; no code)
      Q  QUALITY GATE    (plan + stack completeness)
      X  IMPLEMENTATION  (only planned files; match stack)
      V  VERIFY GATE     (stack build/test + diff budget)
      commit + report → next phase if Mode allows
    → development-summary → HARD STOP

  STAGE 2 — VERIFICATION (separate owner phrase only)
    Real E2E until Must scenarios pass

INNER (never skip)
  I → P → Q → X → V
```

**Never** start X before I + P + Q pass.  
**Never** commit before V passes (unless Hard blocker documented).  
**Never** edit files outside the plan allow-list without a dated Plan amendment.  
**Never** start Stage 2 because Stage 1 finished.  
**Never** assume .NET/Python/Node — resolve **Stack Profile** first.

Details: [accuracy-gates.md](accuracy-gates.md) · [plan-template.md](plan-template.md) · [investigation-template.md](investigation-template.md) · [stack-profile.md](stack-profile.md)

---

## Stack profile (backend / frontend / any language)

Declare **Side + Language + Framework** so each phase can be Python, C#, TS, Flutter, etc.

Full spec: [stack-profile.md](stack-profile.md).

### Kickoff

```text
/phase-orchestrator
Feature: [name]
Side: [backend | frontend | fullstack | shared]
Language: [python | csharp | typescript | javascript | dart | go | java | other]
Framework: [fastapi | django | flask | aspnet | nest | express | next | react | vue | flutter | other]
Build: [optional — e.g. uv run pytest | dotnet build X.sln | pnpm test]
Root: [optional — e.g. apps/api | Customer/Api | mobile]
Start: [phaseId | next]
Mode: [single-phase | all-remaining]
Gate: [approve-plan | auto]
Strict: [on | off]
MaxFiles: [number]
```

| Field | Meaning |
|-------|---------|
| `Side` | Layer this run implements |
| `Language` | Implementation language |
| `Framework` | Framework / platform |
| `Build` | Default verify command for V (always run via `rtk`) |
| `Root` | Package/subfolder for allow-list |

Legacy `Stack: backend` = `Side` only → then Language/Framework from phase-map or repo detection.  
Ambiguous after resolution order → **HARD STOP** (ask owner).

### Resolution order

```text
1) Kickoff Side/Language/Framework/Build/Root
2) Phase row in phase-map
3) phase-map "Stack defaults"
4) Repo markers (pyproject, *.sln, package.json, pubspec.yaml, go.mod, …)
5) STOP if still unclear
```

Prefer **one language per phase**. For BE+FE: two phases or explicit fullstack split in plan.

---

## Mode / Gate defaults

| Field | Default | Meaning |
|-------|---------|---------|
| `Mode: single-phase` | **default** | One map phase then stop |
| `Mode: all-remaining` | | After V+commit, next phase I automatically |
| `Gate: approve-plan` | **default** | Stop after Plan until `approved` / `تایید شد` |
| `Gate: auto` | | After Q, implement without wait |
| `Strict: on` | **default** | Golden examples, diff budget, allow-list, **stack recorded** |

Persian OK: `شروع phase-orchestrator`

Stage 2: `Start Stage 2` / `Start E2E` / `Start Postman` / `شروع تست`

---

## Artifacts

| Artifact | Path | When |
|----------|------|------|
| Phase map | `docs/phase-map.md` | Feature (+ stack defaults / per-phase stack) |
| State | `.cursor/phase-orchestrator-state.json` | Always (includes stackProfile) |
| Investigation | `{reportsDir}/Phase-<id>-investigation.md` | End I |
| Plan | `{reportsDir}/Phase-<id>-plan.md` | End P |
| Development | `{reportsDir}/Phase-<id>-development.md` | End V |
| Summaries | `development-summary.md` / `verification-summary.md` | Outer gates |

Missing map → bootstrap via `phase-cycle` templates; stop until map confirmed.  
Never store secrets in state/reports.

---

## State machine

```text
idle → investigating → planning → qualityGate
  → [awaitingPlanApproval?] → implementing → verifyGate
  → committed → nextPhase | developmentComplete → awaitingVerificationApproval
```

`microStep`: `investigating|planning|qualityGate|awaitingPlanApproval|implementing|verifyGate|committed`

Store also: `stackProfile` `{side,language,framework,build,root}`, `strict`, `maxFiles`, plans, commits.

---

## Pre-task block (every micro-step)

```text
Map phase: [id]
Micro-step: I|P|Q|X|V
Side / Language / Framework / Root:
Strict / Gate / Mode:
Docs: [...]
Allow-list (from plan; empty until P): [...]
Assumptions: [...]
```

Shell: `rtk` + `RTK ▸`. Discovery: codebase-memory MCP first (patterns for **this** stack).

---

## I — INVESTIGATION (no code)

1. Resolve stack profile for this phase ([stack-profile.md](stack-profile.md)).  
2. Read phase-map row + linked docs.  
3. MCP blast radius under `Root` / that ecosystem.  
4. Fill [investigation-template.md](investigation-template.md) including **Stack profile** section.  
5. Must/Should + golden example (Strict) + compatibility + open questions.

No code → P.

---

## P — BINDING PLAN (no code)

Fill [plan-template.md](plan-template.md). Header **must** repeat Side/Language/Framework/Root/Build.

Also: DoD, anti-goals, tasks (path + Done when + Verify), allow-list under Root, diff budget, contract freeze, Must↔tasks, golden ref.

Do not plan `cqrs-scaffold` unless Language is csharp / Framework aspnet (or project skill matches).  
Python → FastAPI/Django patterns from **this** repo, not invented greenfield unless Root is empty and owner said greenfield.

---

## Q — PLAN QUALITY GATE (no code)

Strict checklist:

- [ ] Stack profile complete (Side + Language + Framework; Root if monorepo)  
- [ ] Build/Verify command matches that stack  
- [ ] Goal + DoD + anti-goals  
- [ ] Every task: path + Done when + Verify  
- [ ] Allow-list non-empty; DO NOT TOUCH for risky areas  
- [ ] Diff budget set  
- [ ] Golden example referenced (or N/A reason)  
- [ ] No blocking open questions  

Fail → fix plan. Pass + approve-plan → STOP until `تایید شد`. Pass + auto → X.

---

## X — IMPLEMENTATION

1. Plan is law; match **Language/Framework** conventions of the repo.  
2. Tasks in order; allow-list only; amendments for new files.  
3. Diff budget; no frozen-contract drift; no rule invention.  
4. Do not mix another language mid-phase without plan amendment + owner if Strict.

---

## V — VERIFY GATE

1. Run plan Build/Verify with `rtk` (stack-specific).  
2. Task Done-when checkboxes.  
3. Diff ⊆ allow-list; file count ≤ MaxFiles.  
4. `verify-feature` adapted to stack build.  
5. Development report with task evidence → commit → next or stop.

---

## Safe automation

| Allowed auto | Never auto |
|--------------|------------|
| MCP investigation | Guessing Language/Framework |
| Drafting plan | Stage 2 without phrase |
| `Gate: auto` after Q | Migrations / destructive DB |
| `all-remaining` after V | Push / PR; silent allow-list breach |

Vague Must **or** unresolved stack → refuse `Gate: auto`.

---

## Outer Stage 1 / 2

Stage 1 end: summary + await Stage 2 phrase + HARD STOP.  
Stage 2: real runner per phase-map (Postman/Playwright/pytest-e2e/…).

---

## Hard blockers

Dirty overlap · contract conflict · missing surfaces · blocking questions · **unresolved stack** · production target · unsafe commit · Strict gaps under auto

Resume: `Resume phase-orchestrator`

---

## Examples

Python API phase:

```text
/phase-orchestrator
Feature: Orders
Side: backend
Language: python
Framework: fastapi
Root: apps/api
Build: uv run pytest
Start: 1
Mode: single-phase
Gate: approve-plan
Strict: on
```

Flutter UI phase:

```text
/phase-orchestrator
Feature: Orders
Side: frontend
Language: dart
Framework: flutter
Root: mobile
Build: flutter test
Start: 2
Mode: single-phase
Gate: approve-plan
Strict: on
```

.NET (legacy Side-only + detection):

```text
/phase-orchestrator
Feature: Calendar
Side: backend
Language: csharp
Framework: aspnet
Root: Customer/Api
Start: next
Mode: single-phase
Gate: approve-plan
Strict: on
```

Automation (stack must already be clear in map):

```text
/phase-orchestrator
Feature: Orders
Side: backend
Language: python
Framework: fastapi
Start: next
Mode: all-remaining
Gate: auto
Strict: on
```
