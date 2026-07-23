---
name: code-review
description: >-
  Review code or PRs for backend quality: architecture, CQRS/handlers, security,
  Result usage, soft-delete, and build health. Use for code review, review PR,
  check changes, or audit code. Prefers project AGENTS.md when present.
---

# Code Review — Backend (Global)

Prefer project `code-review` skill / AGENTS checklist when present.

## Process

1. Scope: branch diff, uncommitted diff, or named files (ask if unclear)
2. Discover via MCP (`detect_changes`, `search_graph`) — not Grep-first
3. Review against project rules; fall back to checklist below
4. Output findings by severity

## Checklist (defaults)

### Architecture

- [ ] Layering respected (no Domain → Infrastructure leaks)
- [ ] Namespaces/folders match project conventions
- [ ] No duplicate endpoint/handler for same behavior

### Handlers / services

- [ ] Success check before Result `.Value`
- [ ] `CancellationToken` forwarded
- [ ] Errors are typed/business Results, not silent swallows
- [ ] Mapper matches project (no new mapping stack)

### Data

- [ ] Soft vs hard delete matches project
- [ ] Audit fields not double-set if interceptor exists
- [ ] Reads use no-tracking when appropriate
- [ ] No hand-edited migration noise in feature PRs

### API / security

- [ ] Auth on mutating/sensitive routes
- [ ] No secrets in diffs
- [ ] Input validation present where siblings have it
- [ ] Status codes match project convention

### Build

- [ ] `rtk` build/test for affected projects passes (or note Blocked)

## Output format

- 🔴 Critical — must fix
- 🟡 Suggestion — should fix
- 🟢 Nice to have

Each finding: file path, what’s wrong, what to do instead.
