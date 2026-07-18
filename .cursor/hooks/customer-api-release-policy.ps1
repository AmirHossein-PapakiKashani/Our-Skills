$ErrorActionPreference = 'Stop'

function Write-Allow {
    @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'allow'
        }
    } | ConvertTo-Json -Compress
}

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Allow
    exit 0
}

try {
    $payload = $raw | ConvertFrom-Json
    $command = [string]$payload.tool_input.command
}
catch {
    Write-Allow
    exit 0
}

if ($command -notmatch '(?i)\bdotnet\s+publish\b') {
    Write-Allow
    exit 0
}
if ($command -notmatch '(?i)Customer[\\/]Api') {
    Write-Allow
    exit 0
}

$hasReleaseConfiguration = $command -match '(?i)(-c|--configuration)\s+Release\b'
$hasReleaseOutput = $command -match '(?i)(-o|--output)\s+["'']?D:[\\/]Release\b'

if (-not $hasReleaseConfiguration -or -not $hasReleaseOutput) {
    @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = 'Customer API releases must use -c Release and -o D:\Release. Read Customer/Api/Docs/CustomerApiPublishAndPackage.md.'
        }
    } | ConvertTo-Json -Compress
    exit 0
}

@{
    hookSpecificOutput = @{
        hookEventName = 'PreToolUse'
        additionalContext = 'After publishing Customer API, verify Api.dll and Api.exe, create D:\Release\Release.rar outside the folder first, then run WinRAR t on the final archive.'
    }
} | ConvertTo-Json -Compress
