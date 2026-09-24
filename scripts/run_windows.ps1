param(
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

$rustup = Get-Command rustup.exe -ErrorAction SilentlyContinue
if (-not $rustup) {
    $candidates = @(
        $(if ($env:CARGO_HOME) { Join-Path $env:CARGO_HOME 'bin' })
        $(if ($env:USERPROFILE) { Join-Path $env:USERPROFILE '.cargo\bin' })
        'D:\worksoft\.cargo\bin'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'rustup.exe')) {
            $env:PATH = "$candidate;$env:PATH"
            if (-not $env:CARGO_HOME) {
                $env:CARGO_HOME = Split-Path -Parent $candidate
            }
            $rustup = Get-Command rustup.exe -ErrorAction SilentlyContinue
            break
        }
    }
}
if (-not $rustup) {
    throw 'rustup.exe was not found. Install Rust or add its bin directory to PATH.'
}

$pluginLink = Join-Path $projectRoot 'windows\flutter\ephemeral\.plugin_symlinks\smtc_windows'
$link = Get-Item -LiteralPath $pluginLink -Force -ErrorAction SilentlyContinue
if ($link -and $link.LinkType -eq 'SymbolicLink' -and
    -not (Test-Path -LiteralPath $link.Target)) {
    throw "smtc_windows Pub cache target is missing: $($link.Target). Run flutter pub get."
}

$flutter = Get-Command flutter.bat -ErrorAction Stop
Write-Host "Rust: $($rustup.Source)"
Write-Host "Flutter: $($flutter.Source)"
if ($CheckOnly) {
    return
}

Push-Location $projectRoot
try {
    & $flutter.Source run -d windows
    if ($LASTEXITCODE -ne 0) {
        throw "flutter run failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
