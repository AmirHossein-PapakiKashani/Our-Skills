# Phase report templates

Sanitize all evidence (no tokens, passwords, connection strings, PII).

---

## `Phase-<id>-development.md`

```markdown
# Phase <id> — Development

- Feature:
- Stack:
- Branch:
- Commit:
- Build: PASS / FAIL
- Status: Development Complete | Blocked

## Scope delivered
- …

## Contracts checked (internal)
| ID | Result | Notes |
|----|--------|-------|
| … | Pending→OK | …

## Files touched
- path — why

## Compatibility
- Legacy still working: …

## Open decisions / limitations
- none | …

## Next
- Continue Phase <id+1> (Stage 1) OR awaiting Stage 2 if last
```

---

## `Phase-<id>-verification.md`

(Alias allowed: `Phase-<id>-postman.md` for API-only projects.)

```markdown
# Phase <id> — Verification

- Runner: Postman | Playwright | …
- Target: local/staging (no secrets)
- Status: Verified | Blocked

## Must scenarios
| ID | Status | Evidence (sanitized) |
|----|--------|----------------------|
| S01 | Covered | status 200, key fields … |

## Fixes during this phase
- commit … — …

## Regressions re-run
- …
```

---

## `development-summary.md`

```markdown
# Development summary — Stage 1

- Feature / branch:
- Phases completed:
- Commits (phase → hash):
- Build: PASS
- Known limitations:
- Stage 2 plan (not executed): runner, entry path, users doc, cleanup

## Owner action
Say: Start Stage 2 / Start E2E / Start Postman / شروع تست
```

---

## `verification-summary.md`

(Alias: `postman-summary.md`)

```markdown
# Verification summary — Stage 2

- Pass / fail counts:
- Evidence artifact path:
- All phases Verified: yes/no
- Commits during Stage 2:
- Project Complete: yes/no
```
