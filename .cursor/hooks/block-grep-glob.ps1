# Global Cursor hook — blocks Grep/Glob for source-code exploration.
# Forces codebase-memory MCP. Allows config/markup/asset file types only.

$ErrorActionPreference = 'SilentlyContinue'

$allowedSuffixes = @(
    '.razor', '.json', '.css', '.scss', '.sass', '.less',
    '.md', '.markdown', '.mdx', '.mdc',
    '.yml', '.yaml', '.toml',
    '.txt', '.config', '.props', '.targets', '.editorconfig',
    '.http', '.xml', '.gitignore', '.dockerignore',
    '.csproj', '.sln', '.fsproj', '.vbproj',
    '.html', '.htm', '.svg', '.ico', '.env', '.env.example',
    '.lock', '.npmrc', '.nvmrc', '.prettierrc'
)

function Test-AllowedTarget([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    $lower = $value.ToLowerInvariant()
    foreach ($suffix in $allowedSuffixes) {
        if ($lower.EndsWith($suffix)) { return $true }
    }
    if ($lower -match '(^|[\\/])(readme|license|changelog)(\.|$)') { return $true }
    return $false
}

function Test-AllowedGlobPattern([string]$pattern) {
    if ([string]::IsNullOrWhiteSpace($pattern)) { return $false }
    $lower = $pattern.ToLowerInvariant()
    foreach ($suffix in $allowedSuffixes) {
        $bare = $suffix.TrimStart('.')
        if ($lower -like "*$bare*") { return $true }
    }
    if ($lower -like '*readme*' -or $lower -like '*license*') { return $true }
    return $false
}

$denyMessage = @'
GREP/GLOB BLOCKED by global Cursor hook.

Use codebase-memory MCP (server: codebase-memory-mcp / user-codebase-memory-mcp):
  1. index_status → index_repository (if project not indexed)
  2. search_graph — symbols (name_pattern / semantic_query / query)
  3. search_code — string literals, error messages
  4. get_code_snippet — read symbol body
  5. trace_path — callers and callees

Grep/Glob allowed ONLY for: .json, .md, .css, .yaml, .config, .html, .csproj, etc.

If MCP empty: re-index with index_repository (mode=full, persistence=true), then retry MCP.
If user explicitly asked for raw grep: state that in reply and ask them to confirm.
'@

$inputText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputText)) {
    Write-Output '{}'
    exit 0
}

try {
    $payload = $inputText | ConvertFrom-Json
} catch {
    Write-Output '{}'
    exit 0
}

$toolName = $payload.tool_name
$toolInput = $payload.tool_input

if ($toolName -eq 'Grep') {
    $glob = [string]$toolInput.glob
    $path = [string]$toolInput.path

    if ((Test-AllowedTarget $glob) -or (Test-AllowedTarget $path)) {
        Write-Output '{}'
        exit 0
    }

    @{
        permission    = 'deny'
        user_message  = 'Grep blocked globally — use codebase-memory MCP'
        agent_message = $denyMessage
    } | ConvertTo-Json -Compress
    exit 0
}

if ($toolName -eq 'Glob') {
    $pattern = [string]$toolInput.glob_pattern

    if (Test-AllowedGlobPattern $pattern) {
        Write-Output '{}'
        exit 0
    }

    @{
        permission    = 'deny'
        user_message  = 'Glob blocked globally — use codebase-memory MCP search_graph'
        agent_message = $denyMessage
    } | ConvertTo-Json -Compress
    exit 0
}

Write-Output '{}'
exit 0
