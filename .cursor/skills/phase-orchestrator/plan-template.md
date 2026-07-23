# Phase `<id>` — Binding Implementation Plan

> From Investigation only. Micro-step X may only perform numbered tasks.  
> Quality Gate Q must pass before Implementation.

- Feature:
- Stack profile:
  - Side: backend | frontend | fullstack | shared
  - Language: python | csharp | typescript | …
  - Framework: fastapi | aspnet | next | flutter | …
  - Root: `path` (monorepo package)
  - Build/Verify: `rtk …`
- Map phase:
- Investigation doc:
- Gate: approve-plan | auto
- Strict: on | off
- Status: Draft | Q-passed | Approved | Amended
- Diff budget: MaxFiles=15 | MaxLoc=

## 1. Goal

One paragraph.

## 2. Definition of Done (testable)

- [ ] …
- [ ] Build: `rtk …` exits 0
- [ ] …

## 3. Anti-goals (do NOT do)

- …
- Needs owner decision: …

## 4. Contract freeze (must not drift mid-phase)

- Routes / DTO fields / UI copy: …

## 5. Ordered tasks

| # | Action | Target path(s) | Done when | Verify (`rtk …` or N/A) |
|---|--------|----------------|-----------|-------------------------|
| 1 | … | `path` | … | `rtk …` |
| 2 | … | `path` | … | N/A — … |

## 6. Files allow-list

**CREATE**

- `path` — task #

**MODIFY**

- `path` — task #

**DO NOT TOUCH**

- `path` — why

## 7. Must demos ↔ tasks

| Contract ID | Requirement | Task # |
|-------------|-------------|--------|
| … | … | 1 |

## 8. Golden example reference

- Points to Investigation §4 Example A (or N/A reason)

## 9. Build & self-check (Verify Gate)

```text
RTK ▸ rtk <build>
RTK ▸ rtk <optional tests>
```

## 10. Risks & rollback

- Risk: …
- Rollback: …

## 11. Commit intent

```text
feat(scope): …
```

## Amendments (during X only)

| When | Change | Reason | Needs owner? |
|------|--------|--------|--------------|
| ISO-8601 | … | … | yes/no |
