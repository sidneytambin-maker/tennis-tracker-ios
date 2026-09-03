$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$buildsRoot = Join-Path $projectRoot "builds"

$ipa = Get-ChildItem -Path $buildsRoot -Filter "TennisTracker-development-unsigned-*.ipa" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $ipa) {
    throw "No Tennis Tracker IPA was found in $buildsRoot. Run Scripts\download_latest_github_artifact.ps1 first."
}

$contents = tar -tf $ipa.FullName
$watchPath = "Payload/TennisTracker.app/Watch/TennisTrackerWatchApp.app/"
$wrongPluginPath = "Payload/TennisTracker.app/PlugIns/TennisTrackerWatchApp.app/"

if ($contents -contains $wrongPluginPath) {
    throw "The Watch app is embedded in PlugIns instead of Watch. Rebuild after regenerating the Xcode project."
}

if (-not ($contents -contains $watchPath)) {
    throw "The IPA does not contain $watchPath"
}

Write-Host "Verified embedded Watch app:"
Write-Host $watchPath
Write-Host "IPA:"
Write-Host $ipa.FullName
