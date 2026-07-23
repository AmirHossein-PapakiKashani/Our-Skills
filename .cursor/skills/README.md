# Global Cursor Skills (User-level)

Available in **all** workspaces via `~/.cursor/skills/`.
Project `.cursor/skills/` always wins when both exist.

| Skill | When |
|-------|------|
| **orchestrator** | Start of any backend task — routes to other skills |
| **phase-orchestrator** | Accuracy-first: I→P→Q→X→V per phase; safe automation optional; Stage 2 E2E separate |
| **phase-cycle** | Two-stage multi-phase delivery (code-first Stage 1); Stage 2 real E2E |
| **onboard** | New/unknown repo — index, build, architecture brief |
| **scenario-contract** | Sensitive domains or new Command/Query — investigate + approve gate |
| **cqrs-scaffold** | .NET CQRS vertical slice after plan/approval |
| **verify-feature** | After code changes — build + smoke + coverage |
| **code-review** | PR / diff review |
| **api-smoke-test** | Local HTTP smoke tests |

## Flow

```
User request
  → orchestrator (classify)
  → phase-orchestrator? (I → P → Q → X → V)
  → phase-cycle? (legacy continuous Stage 1)
  → scenario-contract? → WAIT for approved / تایید شد
  → cqrs-scaffold or fix
  → verify-feature
  → done
```

## Kickoff

```
/orchestrator
Feature: [name]
Context: [service / bounded context]
Task: [one paragraph]
```

```
/phase-orchestrator
Feature: [name]
Stack: backend|frontend|fullstack
Start: next
Mode: single-phase
Gate: approve-plan
Strict: on
```

```
/phase-cycle
Feature: [name]
Stack: backend|frontend|fullstack
Start: next
Mode: all-remaining
```

Templates: `~/.cursor/templates/phase-orchestrator/` and `~/.cursor/templates/phase-cycle/`.
