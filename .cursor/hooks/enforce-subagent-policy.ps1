# Reminds subagents about mandatory RTK + codebase-memory policy.

$ErrorActionPreference = 'SilentlyContinue'

$policy = @'
MANDATORY (Elay Backend):
- Shell: prefix every segment with rtk (rtk git status ; rtk dotnet build Elay.sln).
- Code search: codebase-memory MCP (search_graph, search_code, get_code_snippet, trace_path).
- FORBIDDEN: Grep/Glob for .cs, handlers, endpoints, classes.
- Show RTK ▸ rtk <command> before each Shell call.
'@

$inputText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputText)) {
    Write-Output '{}'
    exit 0
}

@{
    permission    = 'allow'
    user_message  = 'Subagent must use RTK shell + codebase-memory MCP (no Grep/Glob for C#).'
    agent_message = $policy
} | ConvertTo-Json -Compress
exit 0
