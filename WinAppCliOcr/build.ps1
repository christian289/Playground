<#
.SYNOPSIS
    Build and package WinAppCliOcr
.PARAMETER Configuration
    Build configuration (Debug or Release)
.PARAMETER Package
    Create Velopack installer package
.PARAMETER Version
    Version number for the package (default: 1.0.0)
#>
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [switch]$Package,
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
$publishDir = "publish"

if ($Configuration -eq "Debug") {
    Write-Host "Building WinAppCliOcr (Debug)..." -ForegroundColor Cyan
    dotnet build WinAppCliOcr.csproj -c Debug
    if ($LASTEXITCODE -ne 0) { exit 1 }
    Write-Host "Build completed!" -ForegroundColor Green
    exit 0
}

# Release: Publish as single-file self-contained
Write-Host "Publishing WinAppCliOcr (Release, SingleFile, SelfContained)..." -ForegroundColor Cyan

dotnet publish WinAppCliOcr.csproj -c Release -o $publishDir
if ($LASTEXITCODE -ne 0) {
    Write-Host "Publish failed!" -ForegroundColor Red
    exit 1
}

$exeFile = Join-Path $publishDir "WinAppCliOcr.exe"
$exeSize = (Get-Item $exeFile).Length / 1MB

Write-Host "Published successfully!" -ForegroundColor Green
Write-Host "Output: $exeFile" -ForegroundColor Yellow
Write-Host "Size: $([math]::Round($exeSize, 2)) MB" -ForegroundColor Yellow

if ($Package) {
    Write-Host "`nCreating Velopack installer (v$Version)..." -ForegroundColor Cyan

    $releaseDir = "releases"
    if (-not (Test-Path $releaseDir)) {
        New-Item -ItemType Directory -Path $releaseDir | Out-Null
    }

    vpk pack `
        --packId "WinAppCliOcr" `
        --packVersion $Version `
        --packDir $publishDir `
        --mainExe "WinAppCliOcr.exe" `
        --outputDir $releaseDir

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Velopack packaging failed!" -ForegroundColor Red
        exit 1
    }

    Write-Host "`nVelopack package created!" -ForegroundColor Green
    Write-Host "Output directory: $releaseDir" -ForegroundColor Yellow
    Get-ChildItem $releaseDir | ForEach-Object {
        $size = $_.Length / 1MB
        Write-Host "  $($_.Name) - $([math]::Round($size, 2)) MB" -ForegroundColor Yellow
    }
}
