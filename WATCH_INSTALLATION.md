# Verified free Watch installation

On 4 September 2026, Watch build 19 was installed successfully through
`com.apple.streaming_zip_conduit` using `PackageType=Developer` and
`AllowInstallLocalProvisioned=true`. The service reported `InstallComplete` at
100% and `DataComplete`. A subsequent Watch application query reported the app
present and `ProfileValidated=true`. Device logs confirmed a successful foreground
launch and VoiceOver navigation of Tennis Tracker's screens.

## Diagnosed cause

The normal iPhone-to-Watch installation path left a placeholder. The Watch log
reported `MIInstallerErrorDomain Code=111`: the app used a free provisioning
profile, but installation from that source was not allowed. The direct developer
streaming route accepted that same Watch app and profile.

Do not move the companion into `PlugIns`. Keep
`Payload/TennisTracker.app/Watch/TennisTrackerWatchApp.app`.
Keep `WKApplication` for this single-target Watch app, without `WKWatchKitApp`.

The accepted Watch profile lists the iOS platform family. Requiring a literal
`watchOS` entry incorrectly rejected this profile locally; physical installation
and launch confirmed acceptance. Never edit the Apple-signed profile itself.

## Repeatable update

1. Build the unsigned IPA using the existing GitHub workflow.
2. Use `Scripts/sign_nested_watch_ipa.ps1` with the existing iPhone and Watch
   profiles. It requires a zsign release with multiple-profile support (tested
   with 1.1.2), signs the Watch before its parent, and checks executable pages,
   XML/DER entitlement hashes, Info.plist, and CodeResources.
3. Install the signed iPhone IPA through the existing developer installation
   tool. Preserve its bundle identifier and data.
4. Install the embedded companion directly using the command below. A paired
   iPhone must be USB-connected and the Watch available. Developer Mode must be
   enabled on the Watch.

```powershell
python Scripts/watch_developer_install.py install --repo . --ipa <signed-ipa-path>
python Scripts/watch_developer_install.py status --repo .
```

The installer reads the already-created private Watch metadata from
`work/signing-assets/watch/bundle.json`. It does not log passwords or device IDs.
It uses the open-source go-ios zipconduit protocol with developer installation
options, preserving all bytes of the signed Watch bundle.

`verify_macho_seals.py` checks signed content integrity; it does not replace
Apple's certificate trust or device authorization checks. Installation success,
an installed-app query, launch, and real activity sync are separate checks.
An iPhone install or visible Watch icon is never evidence that all four passed.

## Prevented signing regression

The earlier Watch-last script refreshed the parent's CodeResources after signing.
That invalidated the parent's signed slot 3. Multiple-profile signing fixes the
ordering without any post-signature edits. The verifier rejects that old IPA and
accepts both signatures produced by the corrected script.

## Sync status

WatchConnectivity reachability means availability for live messages. It can be
false while the Watch app sleeps. Application context is queued for background
delivery after session activation. It is not a receipt or proof that records
have arrived. Confirm the actual Watch records and a Watch-created record on the
iPhone before claiming two-way sync is physically verified.

References:

- https://developer.apple.com/documentation/watchconnectivity/wcsession/isreachable
- https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)
- https://developer.apple.com/documentation/xcode/using-the-latest-code-signature-format
- https://github.com/danielpaulus/go-ios/tree/main/ios/zipconduit
