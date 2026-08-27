$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$buildsRoot = Join-Path $projectRoot "builds"
$sideloadly = Join-Path $env:LOCALAPPDATA "Sideloadly\sideloadly.exe"

if (-not (Test-Path $sideloadly)) {
    throw "Sideloadly was not found at $sideloadly"
}

$ipa = Get-ChildItem -Path $buildsRoot -Filter "TennisTracker-development-unsigned-*.ipa" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $ipa) {
    throw "No Tennis Tracker IPA was found in $buildsRoot. Run Scripts\download_latest_github_artifact.ps1 first."
}

Start-Process -FilePath $sideloadly -ArgumentList ('"' + $ipa.FullName + '"')
Write-Host "Opened Sideloadly with:"
Write-Host $ipa.FullName
