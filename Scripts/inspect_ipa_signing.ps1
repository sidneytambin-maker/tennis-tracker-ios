param(
    [string]$IpaPath = "",
    [string]$AppPath = "",

    [string]$ExpectedIphoneBundleId = "",
    [string]$ExpectedWatchBundleId = "",
    [string]$ExpectedWatchCompanionBundleId = "",
    [switch]$ReportOnly
)

$ErrorActionPreference = "Stop"

if (-not $IpaPath -and -not $AppPath) {
    throw "Provide either -IpaPath or -AppPath."
}

if ($IpaPath -and $AppPath) {
    throw "Provide only one input: -IpaPath or -AppPath."
}

if ($IpaPath -and -not (Test-Path -LiteralPath $IpaPath)) {
    throw "IPA was not found: $IpaPath"
}

if ($AppPath -and -not (Test-Path -LiteralPath $AppPath)) {
    throw "App bundle was not found: $AppPath"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$workRoot = Join-Path $repoRoot "work\ipa-signing-inspection"
$expandRoot = Join-Path $workRoot ("expanded-" + (Get-Date -Format "yyyyMMdd-HHmmss-ffff"))

New-Item -ItemType Directory -Force -Path $expandRoot | Out-Null

if ($IpaPath) {
    $zipCopy = Join-Path $workRoot ("input-" + (Get-Date -Format "yyyyMMdd-HHmmss-ffff") + ".zip")
    Copy-Item -LiteralPath $IpaPath -Destination $zipCopy -Force
    Expand-Archive -LiteralPath $zipCopy -DestinationPath $expandRoot -Force
    $inputDescription = $IpaPath
} else {
    $payloadRoot = Join-Path $expandRoot "Payload"
    New-Item -ItemType Directory -Force -Path $payloadRoot | Out-Null
    Copy-Item -LiteralPath $AppPath -Destination $payloadRoot -Recurse -Force
    $inputDescription = $AppPath
}

$pythonCandidates = @()
if ($env:LOCALAPPDATA) {
    $pythonCandidates += @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe")
    )
}
$pythonCandidates += @("python3", "python", "py")

$python = $null
foreach ($candidate in $pythonCandidates) {
    if (Test-Path -LiteralPath $candidate) {
        $python = [pscustomobject]@{ Source = $candidate }
        break
    }

    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($command -and $command.Source -notmatch "WindowsApps\\python(?:3)?\.exe$") {
        $python = $command
        break
    }
}

if (-not $python) {
    throw "Python is required for IPA signing inspection."
}

$inspector = @'
import json
import plistlib
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
def arg_value(index):
    if index >= len(sys.argv):
        return ""
    value = sys.argv[index]
    return "" if value == "__EMPTY__" else value

expected_iphone = arg_value(2)
expected_watch = arg_value(3)
expected_companion = arg_value(4)

def read_plist(path):
    if not path.exists():
        return None
    with path.open("rb") as f:
        return plistlib.load(f)

def decode_mobileprovision(path):
    if not path.exists():
        return None
    data = path.read_bytes()
    match = re.search(rb"<\?xml.*?</plist>", data, re.S)
    if not match:
        return {"present": True, "decoded": False}
    profile = plistlib.loads(match.group(0))
    devices = profile.get("ProvisionedDevices") or []
    certs = profile.get("DeveloperCertificates") or []
    entitlements = profile.get("Entitlements") or {}
    return {
        "present": True,
        "decoded": True,
        "name": profile.get("Name"),
        "uuid": profile.get("UUID"),
        "team_identifier": profile.get("TeamIdentifier"),
        "application_identifier_prefix": profile.get("ApplicationIdentifierPrefix"),
        "creation_date": str(profile.get("CreationDate")),
        "expiration_date": str(profile.get("ExpirationDate")),
        "platform": profile.get("Platform"),
        "provisioned_device_count": len(devices),
        "developer_certificate_count": len(certs),
        "entitlements": entitlements,
    }

def bundle_report(path):
    info = read_plist(path / "Info.plist") or {}
    profile = decode_mobileprovision(path / "embedded.mobileprovision")
    code_resources = path / "_CodeSignature" / "CodeResources"
    executable = info.get("CFBundleExecutable")
    executable_path = path / executable if executable else None
    return {
        "path": str(path.relative_to(root)),
        "exists": path.exists(),
        "bundle_id": info.get("CFBundleIdentifier"),
        "display_name": info.get("CFBundleDisplayName") or info.get("CFBundleName"),
        "executable": executable,
        "executable_present": bool(executable_path and executable_path.exists()),
        "minimum_os": info.get("MinimumOSVersion"),
        "supported_platforms": info.get("CFBundleSupportedPlatforms"),
        "wk_companion_app_bundle_identifier": info.get("WKCompanionAppBundleIdentifier"),
        "wk_watchkit_app": info.get("WKWatchKitApp"),
        "embedded_provisioning_present": bool(profile),
        "embedded_provisioning": profile,
        "code_resources_present": code_resources.exists(),
        "code_resources_bytes": code_resources.stat().st_size if code_resources.exists() else 0,
    }

payload = root / "Payload"
apps = sorted(payload.glob("*.app"))
iphone = apps[0] if apps else None
if not iphone:
    raise SystemExit("No .app bundle found in Payload.")

def is_watch_app(path):
    info = read_plist(path / "Info.plist") or {}
    platforms = [str(platform).lower() for platform in info.get("CFBundleSupportedPlatforms") or []]
    families = [str(family) for family in info.get("UIDeviceFamily") or []]
    return bool(info.get("WKApplication") or "watchos" in platforms or "4" in families)

watch_apps = []
for container_name in ("PlugIns", "Watch"):
    container = iphone / container_name
    if container.exists():
        watch_apps.extend(path for path in sorted(container.glob("*.app")) if is_watch_app(path))
watch = watch_apps[0] if watch_apps else None

iphone_info = read_plist(iphone / "Info.plist") or {}
if (
    not watch
    and iphone_info.get("CFBundleSupportedPlatforms")
    and any(str(platform).lower() == "watchos" for platform in iphone_info.get("CFBundleSupportedPlatforms"))
):
    watch = iphone

report = {
    "input": sys.argv[5],
    "iphone": bundle_report(iphone),
    "watch": bundle_report(watch) if watch else {"exists": False},
    "checks": {},
}

checks = report["checks"]
checks["watch_bundle_present"] = bool(watch)
checks["iphone_code_resources_present"] = report["iphone"]["code_resources_present"]
checks["iphone_provisioning_present"] = report["iphone"]["embedded_provisioning_present"]
checks["watch_code_resources_present"] = bool(watch and report["watch"]["code_resources_present"])
checks["watch_provisioning_present"] = bool(watch and report["watch"]["embedded_provisioning_present"])
checks["iphone_bundle_matches_expected"] = (not expected_iphone) or report["iphone"]["bundle_id"] == expected_iphone
checks["watch_bundle_matches_expected"] = (not expected_watch) or (watch and report["watch"]["bundle_id"] == expected_watch)
checks["watch_companion_matches_expected"] = (
    (not expected_companion)
    or (watch and report["watch"]["wk_companion_app_bundle_identifier"] == expected_companion)
)

watch_profile = report["watch"].get("embedded_provisioning") if watch else None
watch_entitlements = (watch_profile or {}).get("entitlements") or {}
watch_app_id = watch_entitlements.get("application-identifier", "")
watch_bundle = report["watch"].get("bundle_id") if watch else ""
checks["watch_profile_mentions_watch_bundle"] = bool(
    watch_profile and watch_bundle and watch_app_id.endswith("." + watch_bundle)
)
checks["watch_profile_platform_mentions_watchos"] = bool(
    watch_profile and any(str(p).lower() == "watchos" for p in (watch_profile.get("platform") or []))
)

print(json.dumps(report, indent=2, sort_keys=True))

failed = [name for name, ok in checks.items() if ok is False]
if failed:
    print("\nFAILED CHECKS:")
    for name in failed:
        print(f"- {name}")
    raise SystemExit(2)
'@

$scriptPath = Join-Path $workRoot "inspect_ipa_signing.py"
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
Set-Content -LiteralPath $scriptPath -Value $inspector -Encoding UTF8

$expectedIphoneArg = if ($ExpectedIphoneBundleId) { $ExpectedIphoneBundleId } else { "__EMPTY__" }
$expectedWatchArg = if ($ExpectedWatchBundleId) { $ExpectedWatchBundleId } else { "__EMPTY__" }
$expectedCompanionArg = if ($ExpectedWatchCompanionBundleId) { $ExpectedWatchCompanionBundleId } else { "__EMPTY__" }

& $python.Source $scriptPath $expandRoot $expectedIphoneArg $expectedWatchArg $expectedCompanionArg $inputDescription
$inspectionExitCode = $LASTEXITCODE

if ($ReportOnly -and $inspectionExitCode -ne 0) {
    Write-Warning "IPA signing inspection found incomplete signing/provisioning, but -ReportOnly was set."
    exit 0
}

exit $inspectionExitCode
