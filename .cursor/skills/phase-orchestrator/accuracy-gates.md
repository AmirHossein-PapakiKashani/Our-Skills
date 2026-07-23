# Accuracy gates (Phase Orchestrator)

Enforced when `Strict: on` (default).

## Plan Quality Gate (Q)

| Check | Fail action |
|-------|-------------|
| Stack profile incomplete (Side/Language/Framework) | Resolve via kickoff/map or STOP |
| Verify command mismatches stack | Fix Build to match Language/Framework |
| DoD missing or vague (“make it work”) | Rewrite DoD as observable checks |
| Task without path / Done when / Verify | Add or remove task |
| Empty allow-list | Block X |
| Allow-list outside declared Root (monorepo) | Fix paths or amend Root |
| No diff budget | Set MaxFiles (default 15) |
| No golden example and no N/A reason | Block `Gate: auto`; prefer approve-plan |
| Blocking open question still open | Stop for owner |

## Verify Gate (V)

| Check | Fail action |
|-------|-------------|
| Build/typecheck red | Fix within plan |
| Task Done-when unchecked | Finish or amend plan |
| File outside allow-list in diff | Revert or amend+approve |
| Over MaxFiles | Stop / split phase |
| Frozen contract drifted | Revert drift or owner approval |

## Diff budget defaults

- `MaxFiles`: 15 (override in plan or kickoff `MaxFiles:`)
- `MaxLoc`: optional; if set, count approximate changed lines from diff

## Amendment policy

Trivial (auto OK under Strict): fix typo in path that investigation already proved.  
Non-trivial (need owner if `approve-plan` or Strict): new endpoint, new table, new UI flow, contract change.

## Stage 1 vs Stage 2 evidence

- Stage 1 V: build + planned unit/self-check + allow-list discipline  
- Stage 2: real Postman/Playwright Must scenarios — never claim “API Verified” in Stage 1
