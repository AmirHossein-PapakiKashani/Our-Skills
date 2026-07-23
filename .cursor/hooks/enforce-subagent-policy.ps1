# Reminds subagents about mandatory RTK + codebase-memory policy (global).

$ErrorActionPreference = 'SilentlyContinue'

$policy = @'
MANDATORY (global Cursor policy):
- Shell: prefix every segment with rtk (e.g. rtk git status ; rtk dotnet build).
- Code search: codebase-memory MCP (search_graph, search_code, get_code_snippet, trace_path).
- FORBIDDEN: Grep/Glob for source code (*.cs, *.ts, *.py, handlers, endpoints).
- Show RTK ▸ rtk <command> before each Shell call.
- If project has .cursor/skills or AGENTS.md — follow those too.
'@

$inputText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputText)) {
    Write-Output '{}'
    exit 0
}

@{
    permission    = 'allow'
    user_message  = 'Subagent must use RTK shell + codebase-memory MCP (no Grep/Glob for source).'
    agent_message = $policy
} | ConvertTo-Json -Compress
exit 0
