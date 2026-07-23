---
name: onboard
description: >-
  Onboard a developer or AI agent to any backend repo. Checks codebase-memory
  index, build, config, and summarizes architecture. Use for onboard, project
  setup, start working, or introduce codebase.
---

# Onboard — Any Backend Repo

Prefer project `.cursor/skills/onboard` if present.

## Step 1 — Index

- MCP: `list_projects` / `index_status`
- If missing → `index_repository(repo_path=<workspace>, mode=full, persistence=true)`
- Optionally suggest committing `.codebase-memory/` artifacts if the team shares them

## Step 2 — Build / restore

Detect solution/package manager:

| Marker | Command |
|--------|---------|
| `*.sln` | `rtk dotnet build <solution>` |
| `package.json` | `rtk npm install` then `rtk npm run build` (or project script) |
| `pyproject.toml` / `requirements.txt` | project’s documented install + check |
| `go.mod` | `rtk go build ./...` |

Show `RTK ▸` before Shell.

## Step 3 — Config sanity (read-only)

Look for `appsettings*.json`, `.env.example`, `docker-compose*.yml` — summarize required secrets **without printing secret values**.

## Step 4 — Architecture briefing

From `get_architecture` + README/AGENTS:

- Entry points (API / workers)
- Layers / bounded contexts
- Auth mechanism
- How to run locally
- Where agents must look: `.cursor/rules`, `AGENTS.md`, skills

## Step 5 — Output

Short Persian (RTL) or English summary:

1. Index status
2. Build status
3. How to start the app
4. Top 5 conventions the agent must not violate
