# RTK preToolUse hook for Cursor on Windows.
# Reads Cursor hook JSON from stdin, rewrites shell commands via rtk rewrite,
# returns Cursor-compatible JSON (permission + updated_input).

$ErrorActionPreference = 'SilentlyContinue'
$rtk = 'C:\Users\kasha\.local\bin\rtk.exe'

if (-not (Test-Path -LiteralPath $rtk)) {
    Write-Output '{}'
    exit 0
}

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

$cmd = $payload.tool_input.command
if ([string]::IsNullOrWhiteSpace($cmd)) {
    Write-Output '{}'
    exit 0
}

$rewritten = & $rtk rewrite $cmd 2>$null
if ([string]::IsNullOrWhiteSpace($rewritten) -or $cmd -eq $rewritten) {
    Write-Output '{}'
    exit 0
}

@{
    permission    = 'allow'
    updated_input = @{ command = $rewritten.Trim() }
} | ConvertTo-Json -Compress
