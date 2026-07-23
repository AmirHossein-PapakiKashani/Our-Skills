# Phase map — [FEATURE NAME]

> Copy to `docs/phase-map.md` and replace placeholders.
> Stack: `backend` | `frontend` | `fullstack`

## Sources of truth

| Doc | Role |
|-----|------|
| `docs/[Feature]-Implementation-Guide.md` | What each phase implements |
| `docs/[Feature]-ScenarioContracts.md` | Must / Should scenarios |
| `docs/[Feature]-API.md` or OpenAPI | Contracts (backend) |
| `docs/[Feature]-UI.md` or Figma link | Screens / flows (frontend) |

## Phases

| Phase | Focus | Primary surfaces | Contracts | Must demo |
|-------|-------|------------------|-----------|-----------|
| 0 | Baseline / freeze | measure current behavior | L | notes only |
| 1 | [name] | route or screen | A | one sentence |
| 2 | [name] | … | B | … |
| 3 | [name] | … | C | … |

Add/remove rows as needed. Keep **strict order** unless Dependency chain says otherwise.

## Dependency chain

```text
0 → 1 → 2 → 3 → …
```

List any parallel-safe phases explicitly (e.g. `4 and 5 after 3`).

## Compatibility / non-goals

- Must keep working until phase X: […]
- Out of scope unless owner expands: […]
- Do not invent business rules; escalate product decisions

## Reports directory

`docs/Phase-Reports/`

- `Phase-<id>-development.md`
- `Phase-<id>-verification.md`
- `development-summary.md`
- `verification-summary.md`

## Stage 2 runner (fill before Stage 2)

| Field | Value |
|-------|-------|
| Runner | Postman / Newman / Playwright / Cypress / other |
| Entry | path to collection or e2e script |
| Base URL / app URL | local/staging only |
| Test users doc | path (never put passwords in this file) |
