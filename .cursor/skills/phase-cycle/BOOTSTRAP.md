# Bootstrap a phase cycle on any project

Use once per feature (or epic). Agent + owner fill these before Stage 1.

## 1. Decide stack

- `backend` — APIs/services
- `frontend` — web/mobile UI
- `fullstack` — phases may touch both; map must say which side each phase owns

## 2. Copy templates into the repo

From PowerShell (repo root):

```powershell
$src = "$env:USERPROFILE\.cursor\templates\phase-cycle"
mkdir docs, docs\Phase-Reports, .cursor -Force | Out-Null
copy "$src\phase-map.template.md" docs\phase-map.md
copy "$src\state.template.json" .cursor\phase-cycle-state.json
# Optional: keep report-templates.md as docs/Phase-Reports/README.md
copy "$src\report-templates.md" docs\Phase-Reports\README.md
```

Or ask the agent: `Bootstrap phase-cycle for feature X on this repo`.

## 3. Fill `docs/phase-map.md`

For every phase define:

1. **Id** (0..N or slug) and short name  
2. **Scope** (what ships / what is out of scope)  
3. **Primary surfaces** (routes, screens, packages)  
4. **Scenario contracts** (link + Must demo one-liner)  
5. **Dependencies** (which phases must precede)  
6. **Compatibility** (legacy that must keep working)

Do not start Stage 1 with an empty map.

## 4. Point scenario + implementation docs

Either embed links in the phase map or create:

- `docs/<Feature>-Implementation-Guide.md` (phase sections)
- `docs/<Feature>-ScenarioContracts.md` (Must/Should tables)

Frontend: scenarios can be user journeys (“user opens menu → sees 4 tiles”).  
Backend: scenarios are API contracts (status, body, authz).

## 5. Initialize state

Edit `.cursor/phase-cycle-state.json`:

- `feature`, `stack`, `phaseOrder`, `phaseMapPath`, `reportsDir`
- `authorization.fullCycleDevelopment: false` until Stage 1 kickoff
- `authorization.verification: false` until Stage 2 kickoff

## 6. Kick off Stage 1

```text
/phase-cycle
Feature: My Epic
Stack: backend
Start: next
Mode: all-remaining
PhaseMap: docs/phase-map.md
```

## Frontend notes

- Stage 1: components, routes, state, storybook/unit as map requires — still **no** claiming E2E Verified
- Stage 2: Playwright/Cypress (or project E2E) against a real running app; visual mocks alone ≠ Passed for Must rows marked E2E
- Prefer stable `data-testid` / roles named in the scenario doc

## Fullstack notes

- Each phase row must say `BE` / `FE` / `BOTH`
- Prefer BE contract freeze before FE consumption phases when possible
- Stage 2 may require API suite then UI suite for the same phase — map Must rows accordingly
