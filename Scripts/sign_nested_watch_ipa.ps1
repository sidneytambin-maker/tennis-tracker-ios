param(
    [Parameter(Mandatory = $true)]
    [string]$InputIpaPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputIpaPath,

    [string]$SigningIdentityP12Path = "",

    [string]$SigningKeyPath = "",

    [string]$SigningCertificatePath = "",

    [Parameter(Mandatory = $true)]
    [string]$IphoneProvisionPath,

    [Parameter(Mandatory = $true)]
    [string]$WatchProvisionPath,

    [Parameter(Mandatory = $true)]
    [string]$FinalIphoneBundleId,

    [Parameter(Mandatory = $true)]
    [string]$FinalWatchBundleId,

    [string]$ZsignPath = "",
    [string]$SigningPassword = "",
    [switch]$AllowNonWatchOsProfile,
    [switch]$EmbedWatchInPlugIns
)

$ErrorActionPreference = "Stop"

function Resolve-RequiredPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Name was not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-Python {
    $pythonCandidates = @()
    if ($env:LOCALAPPDATA) {
        $pythonCandidates += @(
            (Join-Path $env:LOCALAPPDATA "Programs\Python\Python312\python.exe"),
            (Join-Path $env:LOCALAPPDATA "Programs\Python\Python311\python.exe")
        )
    }
    $pythonCandidates += @("python3", "python", "py")

    foreach ($candidate in $pythonCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }

        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command -and $command.Source -notmatch "WindowsApps\\python(?:3)?\.exe$") {
            return $command.Source
        }
    }

    throw "Python is required to patch and inspect the IPA."
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$workRoot = Join-Path $repoRoot "work\nested-watch-signing"
$expandRoot = Join-Path $workRoot ("expanded-" + (Get-Date -Format "yyyyMMdd-HHmmss-ffff"))

$inputIpa = Resolve-RequiredPath $InputIpaPath "Input IPA"
if ($SigningIdentityP12Path) {
    $signingIdentity = Resolve-RequiredPath $SigningIdentityP12Path "Signing identity"
} else {
    $signingKey = Resolve-RequiredPath $SigningKeyPath "Signing key"
    $signingCertificate = Resolve-RequiredPath $SigningCertificatePath "Signing certificate"
}
$iphoneProvision = Resolve-RequiredPath $IphoneProvisionPath "iPhone provisioning profile"
$watchProvision = Resolve-RequiredPath $WatchProvisionPath "Watch provisioning profile"

if (-not $ZsignPath) {
    $defaultZsign = Join-Path (Split-Path -Parent $repoRoot) "referenced-chatgpt-conversation-this-is-an\work\zsign\zsign.exe"
    if (Test-Path -LiteralPath $defaultZsign) {
        $ZsignPath = $defaultZsign
    }
}

$zsign = Resolve-RequiredPath $ZsignPath "zsign"
$python = Get-Python

New-Item -ItemType Directory -Force -Path $expandRoot | Out-Null
$zipCopy = Join-Path $workRoot ("input-" + (Get-Date -Format "yyyyMMdd-HHmmss-ffff") + ".zip")
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
Copy-Item -LiteralPath $inputIpa -Destination $zipCopy -Force
& tar.exe -xf $zipCopy -C $expandRoot
if ($LASTEXITCODE -ne 0) {
    throw "Failed to expand the input IPA."
}

$iphoneApp = Get-ChildItem -LiteralPath (Join-Path $expandRoot "Payload") -Directory -Filter "*.app" | Select-Object -First 1
if (-not $iphoneApp) {
    throw "No iPhone app bundle was found in the IPA payload."
}

$watchApp = Get-ChildItem -LiteralPath (Join-Path $iphoneApp.FullName "PlugIns") -Directory -Filter "*.app" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $watchApp) {
    $watchApp = Get-ChildItem -LiteralPath (Join-Path $iphoneApp.FullName "Watch") -Directory -Filter "*.app" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $watchApp) {
    throw "No embedded Watch app was found at Payload/<App>.app/PlugIns or Payload/<App>.app/Watch."
}

if ($EmbedWatchInPlugIns -and $watchApp.FullName -notlike "*\PlugIns\*") {
    $pluginsFolder = Join-Path $iphoneApp.FullName "PlugIns"
    New-Item -ItemType Directory -Force -Path $pluginsFolder | Out-Null
    $pluginWatchApp = Join-Path $pluginsFolder $watchApp.Name
    if (Test-Path -LiteralPath $pluginWatchApp) {
        Remove-Item -LiteralPath $pluginWatchApp -Recurse -Force
    }
    Move-Item -LiteralPath $watchApp.FullName -Destination $pluginWatchApp
    $watchFolder = Join-Path $iphoneApp.FullName "Watch"
    if ((Test-Path -LiteralPath $watchFolder) -and -not (Get-ChildItem -LiteralPath $watchFolder -Force)) {
        Remove-Item -LiteralPath $watchFolder -Force
    }
    $watchApp = Get-Item -LiteralPath $pluginWatchApp
    Write-Host "Embedded Watch app under Payload/<App>.app/PlugIns for current watchOS packaging."
}

$patchScript = @"
import plistlib
import re
import sys
from pathlib import Path

iphone_info = Path(sys.argv[1])
watch_info = Path(sys.argv[2])
watch_profile = Path(sys.argv[3])
final_iphone = sys.argv[4]
final_watch = sys.argv[5]
iphone_profile = Path(sys.argv[6])
iphone_entitlements_path = Path(sys.argv[7])
watch_entitlements_path = Path(sys.argv[8])

with iphone_info.open("rb") as f:
    iphone = plistlib.load(f)
iphone["CFBundleIdentifier"] = final_iphone
with iphone_info.open("wb") as f:
    plistlib.dump(iphone, f, sort_keys=False)

with watch_info.open("rb") as f:
    watch = plistlib.load(f)
watch["CFBundleIdentifier"] = final_watch
watch["WKCompanionAppBundleIdentifier"] = final_iphone
with watch_info.open("wb") as f:
    plistlib.dump(watch, f, sort_keys=False)

def decode_profile(path, description):
    data = path.read_bytes()
    match = re.search(rb"<\?xml.*?</plist>", data, re.S)
    if not match:
        raise SystemExit(f"Could not decode the {description} provisioning profile.")
    return plistlib.loads(match.group(0))

def write_entitlements(profile, final_bundle_id, output_path, description):
    entitlements = dict(profile.get("Entitlements") or {})
    prefix = profile.get("ApplicationIdentifierPrefix") or profile.get("TeamIdentifier") or []
    if not prefix:
        raise SystemExit(f"The {description} provisioning profile does not contain an application identifier prefix.")
    entitlements["application-identifier"] = f"{prefix[0]}.{final_bundle_id}"
    entitlements["com.apple.developer.team-identifier"] = prefix[0]
    entitlements.setdefault("get-task-allow", True)
    entitlements.setdefault("keychain-access-groups", [f"{prefix[0]}.*"])
    with output_path.open("wb") as f:
        plistlib.dump(entitlements, f, sort_keys=False)
    return entitlements

iphone_profile_data = decode_profile(iphone_profile, "iPhone")
watch_profile_data = decode_profile(watch_profile, "Watch")
write_entitlements(iphone_profile_data, final_iphone, iphone_entitlements_path, "iPhone")
watch_entitlements = write_entitlements(watch_profile_data, final_watch, watch_entitlements_path, "Watch")

application_identifier = watch_entitlements.get("application-identifier", "")
platforms = [str(p).lower() for p in watch_profile_data.get("Platform") or []]

if not application_identifier.endswith("." + final_watch):
    raise SystemExit(
        "Watch provisioning profile does not match Watch bundle id. "
        f"profile application-identifier={application_identifier!r}, expected suffix='.{final_watch}'"
    )

if "watchos" not in platforms:
    raise SystemExit(
        "Watch provisioning profile does not list watchOS as a supported platform. "
        f"platforms={watch_profile_data.get('Platform')!r}"
    )
"@

$patchFile = Join-Path $workRoot "patch-and-validate.py"
$iphoneEntitlementsPath = Join-Path $workRoot "iphone-entitlements.plist"
$watchEntitlementsPath = Join-Path $workRoot "watch-entitlements.plist"
Set-Content -LiteralPath $patchFile -Value $patchScript -Encoding UTF8
& $python $patchFile `
    (Join-Path $iphoneApp.FullName "Info.plist") `
    (Join-Path $watchApp.FullName "Info.plist") `
    $watchProvision `
    $FinalIphoneBundleId `
    $FinalWatchBundleId `
    $iphoneProvision `
    $iphoneEntitlementsPath `
    $watchEntitlementsPath
if ($LASTEXITCODE -ne 0 -and -not $AllowNonWatchOsProfile) {
    throw "The Watch provisioning profile is not valid for this Watch bundle."
} elseif ($LASTEXITCODE -ne 0) {
    Write-Warning "Proceeding even though Apple's Watch-bundle profile does not list watchOS; physical install will decide whether Apple accepts it."
}

if ($SigningIdentityP12Path) {
    $zsignArgsBase = @("-k", $signingIdentity)
} else {
    $zsignArgsBase = @("-k", $signingKey, "-c", $signingCertificate)
}
if ($SigningPassword) {
    $zsignArgsBase += @("-p", $SigningPassword)
}

& $zsign @zsignArgsBase "-m" $watchProvision "-e" $watchEntitlementsPath "-b" $FinalWatchBundleId "-f" $watchApp.FullName
if ($LASTEXITCODE -ne 0) {
    throw "Failed to sign the embedded Watch app."
}

& $zsign @zsignArgsBase "-m" $iphoneProvision "-e" $iphoneEntitlementsPath "-b" $FinalIphoneBundleId "-o" $OutputIpaPath $iphoneApp.FullName
if ($LASTEXITCODE -ne 0) {
    throw "Failed to sign the iPhone app wrapper."
}

# zsign signs nested Watch bundles again while signing the iPhone wrapper. Sign the
# Watch app last so its executable entitlements match its own provisioning profile.
& $zsign @zsignArgsBase "-m" $watchProvision "-e" $watchEntitlementsPath "-b" $FinalWatchBundleId "-f" $watchApp.FullName
if ($LASTEXITCODE -ne 0) {
    throw "Failed to re-sign the embedded Watch app after wrapper signing."
}

if (Test-Path -LiteralPath $OutputIpaPath) {
    Remove-Item -LiteralPath $OutputIpaPath -Force
}
Compress-Archive -Path (Join-Path $expandRoot "Payload") -DestinationPath $OutputIpaPath -Force

& (Join-Path $PSScriptRoot "inspect_ipa_signing.ps1") `
    -IpaPath $OutputIpaPath `
    -ExpectedIphoneBundleId $FinalIphoneBundleId `
    -ExpectedWatchBundleId $FinalWatchBundleId `
    -ExpectedWatchCompanionBundleId $FinalIphoneBundleId
if ($LASTEXITCODE -ne 0) {
    if ($AllowNonWatchOsProfile) {
        Write-Warning "Signed IPA inspection still reports the Apple profile platform field does not mention watchOS; continuing because -AllowNonWatchOsProfile was set."
    } else {
        throw "Signed IPA failed nested Watch signing inspection."
    }
}

Write-Host "Signed nested Watch IPA:"
Write-Host $OutputIpaPath
