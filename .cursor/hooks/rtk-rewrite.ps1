# Legacy RTK hook script (fallback). Primary hook: "rtk hook cursor" in hooks.json.

$ErrorActionPreference = 'SilentlyContinue'

$rtk = Join-Path $env:USERPROFILE '.local\bin\rtk.exe'
if (-not (Test-Path -LiteralPath $rtk)) {
    $rtk = 'rtk'
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

[PSCustomObject]@{
    permission    = 'allow'
    updated_input = [PSCustomObject]@{ command = $rewritten.Trim() }
} | ConvertTo-Json -Compress -Depth 3
