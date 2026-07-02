# Harpy Windows setup helper
# Usage: .\scripts\setup.ps1

$ErrorActionPreference = "Stop"

$CrystalDir = Join-Path $env:LOCALAPPDATA "Programs\crystal"
$CrystalExe = Join-Path $CrystalDir "crystal.exe"
$ShardsExe = Join-Path $CrystalDir "shards.exe"

if (-not (Test-Path $CrystalExe)) {
    Write-Host "Crystal not found at $CrystalDir" -ForegroundColor Red
    Write-Host "Install with: winget install CrystalLang.Crystal"
    exit 1
}

# Make crystal/shards available in this session
if ($env:Path -notlike "*$CrystalDir*") {
    $env:Path = "$CrystalDir;$env:Path"
    Write-Host "Added Crystal to PATH for this session: $CrystalDir"
}

Write-Host ""
& $CrystalExe --version
& $ShardsExe --version
Write-Host ""

# Shards needs symlink support on Windows (Developer Mode or admin)
$devModeKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
$devMode = $false
if (Test-Path $devModeKey) {
    $devMode = (Get-ItemProperty $devModeKey -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
}

if (-not $devMode) {
    Write-Host "Developer Mode is not enabled. Shards requires symlinks on Windows." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Enable it once:"
    Write-Host "  1. Run: start ms-settings:developers"
    Write-Host "  2. Turn on 'Developer Mode'"
    Write-Host "  3. Close and reopen this terminal"
    Write-Host "  4. Run this script again"
    Write-Host ""
    $open = Read-Host "Open Developer settings now? [Y/n]"
    if ($open -ne "n" -and $open -ne "N") {
        Start-Process "ms-settings:developers"
    }
    exit 1
}

Write-Host "Installing shards dependencies..."
Set-Location (Split-Path $PSScriptRoot -Parent)
& $ShardsExe install

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Setup complete. Run the server with:"
    Write-Host "  crystal run src/harpy.cr"
}
