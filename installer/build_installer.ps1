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

function Test-ZipArchive {
    param([string]$Path)

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $archive.Dispose()
        return $true
    }
    catch [System.IO.InvalidDataException] {
        return $false
    }
    catch [System.IO.IOException] {
        return $false
    }
}

Push-Location $repoRoot
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $buildDir = Join-Path $repoRoot "build\windows\x64"
    $firebaseArchives = Get-ChildItem -Path $buildDir -Filter "firebase_cpp_sdk_windows_*.zip" -File -ErrorAction SilentlyContinue

    foreach ($archive in $firebaseArchives) {
        if (-not (Test-ZipArchive -Path $archive.FullName)) {
            Write-Warning "Removing incomplete Firebase SDK download: $($archive.Name)"
            Remove-Item -LiteralPath $archive.FullName
        }
    }

    $buildSucceeded = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host "Building Flutter Windows release (attempt $attempt of 3)..." -ForegroundColor Cyan
        flutter build windows --release
        $buildExitCode = $LASTEXITCODE
        if ($buildExitCode -eq 0) {
            $buildSucceeded = $true
            break
        }

        $incompleteArchives = Get-ChildItem -Path $buildDir -Filter "firebase_cpp_sdk_windows_*.zip" -File -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-ZipArchive -Path $_.FullName) }
        if (-not $incompleteArchives) {
            throw "flutter build windows failed with exit code $buildExitCode"
        }

        foreach ($archive in $incompleteArchives) {
            Write-Warning "Removing incomplete Firebase SDK download: $($archive.Name)"
            Remove-Item -LiteralPath $archive.FullName
        }

        if ($attempt -eq 3) {
            throw "Flutter Windows build failed after 3 attempts because the Firebase SDK download was incomplete"
        }

        $delaySeconds = 5 * $attempt
        Write-Warning "Retrying the Firebase SDK download in $delaySeconds seconds..."
        Start-Sleep -Seconds $delaySeconds
    }

    if (-not $buildSucceeded) {
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
