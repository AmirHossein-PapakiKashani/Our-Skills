# Windows wrapper for RTK Cursor hook — pipes stdin/stdout reliably.

$ErrorActionPreference = 'SilentlyContinue'

$rtk = 'C:\Users\PC 1\.local\bin\rtk.exe'
if (-not (Test-Path $rtk)) {
    $rtk = 'rtk'
}

$inputText = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($inputText)) {
    Write-Output '{}'
    exit 0
}

try {
    $output = $inputText | & $rtk hook cursor 2>&1
    if ($null -eq $output) {
        Write-Output '{}'
        exit 0
    }

    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        Write-Output '{}'
        exit 0
    }

    Write-Output $text
    exit 0
}
catch {
    Write-Output '{}'
    exit 0
}
