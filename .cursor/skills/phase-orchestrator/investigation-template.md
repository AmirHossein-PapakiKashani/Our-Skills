# Phase `<id>` — Investigation

> Micro-step I only. No code. Evidence over guesses.

- Feature:
- Stack profile: Side=… Language=… Framework=… Root=…
- Map phase:
- Phase map row summary:
- Strict: on | off

## 0. Stack resolution

| Source | Value |
|--------|-------|
| Kickoff | … |
| Phase-map row | … |
| Defaults / detected | … |
| **Resolved** | Side=… Language=… Framework=… Root=… Build=… |

If unresolved → stop (do not continue to Plan).

## 1. Surfaces in scope

| Surface (route/screen/API) | Evidence path | Notes |
|----------------------------|---------------|-------|
| … | `path` | … |

## 2. Blast radius files

| Path | Why related | In / Out for this phase |
|------|-------------|-------------------------|
| … | … | In / Out / Compat-only |

## 3. Must / Should (this phase)

| ID | Must/Should | Description | Status |
|----|-------------|-------------|--------|
| … | Must | … | Pending |

## 4. Golden examples (required if Strict)

### Example A

- Kind: HTTP | UI | fixture  
- Setup:  
- Input:  
- Expected output / assertion:  
- Source: doc path or captured sample path  

If none: `N/A — [reason]` (blocks Gate:auto until resolved)

## 5. Must not break (compatibility)

- …

## 6. Blast radius answer

What existing behavior could this phase break?

- `[handler/screen]`: … / not affected because …

## 7. Open questions

| # | Question | Blocks plan? |
|---|----------|--------------|
| 1 | … | yes/no |

## 8. MCP / tools used

- search_graph / search_code / trace_path / …
