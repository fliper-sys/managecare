# Builds the Flutter Windows release and packages it into ManageCareSetup-<version>.exe
# Usage: powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

$isccCandidates = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    Write-Error "Inno Setup compiler not found. Install it with: winget install JRSoftware.InnoSetup"
    exit 1
}

Push-Location $repoRoot
try {
    Write-Host "Building Flutter Windows release..." -ForegroundColor Cyan
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build windows failed"
    }

    Write-Host "Compiling installer..." -ForegroundColor Cyan
    & $iscc "installer\ManageCare.iss"
    if ($LASTEXITCODE -ne 0) {
        throw "ISCC compile failed"
    }

    Write-Host "Done. Installer is in installer\Output\" -ForegroundColor Green
}
finally {
    Pop-Location
}
