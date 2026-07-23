# Stack Profile — declare how each part is implemented

Use this so Phase Orchestrator does **not** assume .NET or any default stack.
You may mix stacks across phases (e.g. Phase 1 Python API, Phase 2 Flutter UI).

## 1. Kickoff fields (highest priority for current run)

```text
/phase-orchestrator
Feature: [name]
Side: [backend | frontend | fullstack | shared]
Language: [python | csharp | typescript | javascript | dart | go | java | other]
Framework: [fastapi | django | flask | aspnet | nest | express | next | react | vue | flutter | other]
Build: [optional — e.g. uv run pytest | rtk dotnet build | pnpm test]
Root: [optional path — e.g. apps/api | Customer/Api | mobile]
Start: next
Mode: single-phase
Gate: approve-plan
Strict: on
```

| Field | Meaning |
|-------|---------|
| `Side` | Which layer this run targets |
| `Language` | Implementation language |
| `Framework` | Framework / runtime style |
| `Build` | Default verify/build command for V gate (prefix with `rtk` in practice) |
| `Root` | Subfolder / package root in monorepo |

Legacy: `Stack: backend` alone still works → treat as `Side: backend` and **detect** Language/Framework from repo markers unless you set Language/Framework.

## 2. Feature-level defaults (in state / phase-map header)

Put once at top of `docs/phase-map.md`:

```markdown
## Stack defaults

| Side | Language | Framework | Root | Default verify |
|------|----------|-----------|------|----------------|
| backend | python | fastapi | `apps/api` | `rtk uv run pytest` |
| frontend | typescript | next | `apps/web` | `rtk pnpm test` |
```

Or single-stack projects:

```markdown
## Stack defaults
- Side: backend
- Language: csharp
- Framework: aspnet
- Root: `Customer/Api`
- Default verify: `rtk dotnet build Elay.sln`
```

## 3. Per-phase override (wins over defaults)

In the phases table, add columns (or a Stack cell):

| Phase | Side | Language | Framework | Root | Focus | …
|-------|------|----------|-----------|------|-------|
| 1 | backend | python | fastapi | `apps/api` | create order API | …
| 2 | frontend | dart | flutter | `mobile` | order list screen | …
| 3 | fullstack | — | — | — | wire contract | … |

For `fullstack` phases: either two task groups in the plan (BE then FE) with **two** stack profiles, or split into two map phases (preferred for accuracy).

## 4. Resolution order (agent must follow)

```text
1) Kickoff Side/Language/Framework/Build/Root for this run
2) Else phase row override in phase-map
3) Else phase-map "Stack defaults"
4) Else detect from repo (pyproject.toml, *.sln, package.json, pubspec.yaml, go.mod, …)
5) If still ambiguous → HARD STOP and ask owner (do not guess Python vs .NET)
```

## 5. What changes per stack in I / P / X / V

| Micro-step | Must adapt to stack |
|------------|---------------------|
| I | Search patterns for that ecosystem (routes, handlers, widgets) via MCP |
| P | Allow-list paths under `Root`; Verify commands match Build |
| X | Follow project conventions for that language; do not import another stack’s patterns |
| V | Run the stack’s build/test from plan §9 |

### Example verify snippets

```text
# Python
RTK ▸ rtk uv run pytest
RTK ▸ rtk python -m compileall apps/api

# .NET
RTK ▸ rtk dotnet build Elay.sln

# Node / TS
RTK ▸ rtk pnpm lint
RTK ▸ rtk pnpm test

# Flutter
RTK ▸ rtk flutter test
RTK ▸ rtk flutter analyze
```

## 6. Plan / investigation must record

Every plan header:

```text
Side: …
Language: …
Framework: …
Root: …
Build/Verify: …
```

If kickoff and phase-map disagree → prefer kickoff for this run, note conflict in plan, ask owner if risky.

## 7. Anti-patterns

- Do not scaffold FastAPI into a .NET-only phase because “Python was mentioned once”
- Do not use `cqrs-scaffold` (.NET) unless Language/Framework is csharp/aspnet **or** project skill exists and matches
- Do not mix languages in one phase without an explicit fullstack plan split
