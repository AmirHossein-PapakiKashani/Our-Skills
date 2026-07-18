# Elay Backend — Agent Reference Files

Extracted and supporting docs for `.cursor/skills/`.  
**Master manual (architecture Sections 1–32):** `AGENTS.md` only.

## File index

| File | Used by | Purpose |
|------|---------|---------|
| `section-33-34-full.md` | `scenario-contract` | Scenario Contract + Investigation protocol |
| `namespaces.md` | `cqrs-scaffold` | Namespace rules (AGENTS.md Section 25.1) |
| `file-locations.md` | `cqrs-scaffold` | Folder paths per layer (Section 25.2) |
| `templates.md` | `cqrs-scaffold` | CQRS code templates (AGENTS.md Section 25.3 — full copy) |
| `migrations-quickref.md` | `cqrs-scaffold`, `verify-feature` | EF migration commands (Section 26) |
| `api-testing-quickref.md` | `verify-feature` | Login + endpoint test (Section 32) |
| `postman-test-users.md` | `verify-feature`, Postman work | Canonical Customer ChatTest users (U1–U4) for integration collections |

## What stays in AGENTS.md only (not duplicated here)

Sections 1–24 (architecture), 27 (debug), 29 (Blazor UI), 30 (commit), 31 (shell).
Agents read `AGENTS.md` for these; `references/` holds extracted quickrefs for skills.

## Related project config

| Path | Purpose |
|------|---------|
| `.cursor/skills/` | Orchestrator workflow skills |
| `.cursor/rules/` | RTK, codebase-memory, enforcement gates |
| `.cursor/hooks.json` | RTK rewrite + Grep/Glob block for `.cs` |
| `.cursorrules` | Short RTK + MCP reminder |
