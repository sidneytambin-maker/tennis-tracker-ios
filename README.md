# Tennis Tracker iOS

This folder contains the native iOS Tennis Tracker project. The existing Windows project at `C:\Users\User\dodge Dropbox\sidney tambin\shared folders\klaudia and sidney\TennisTracker` is a read-only reference implementation and must not be used as the iOS working folder.

## Current scope

The first phone installation proved the pipeline from Windows source files to a free macOS cloud build, then to Windows signing and sideloading using a normal Apple Account. The current app now starts the real native iPhone version of Tennis Tracker.

The app contains:

- A native iPhone tab bar prioritising Dashboard, Matches, Tournaments, Training, and Player, with Settings lower priority when iOS shows More.
- Player profiles with blind-tennis sight categories and allowed-bounce wording.
- Match history, match detail, match editing, performance notes, set scores, and tiebreak notes.
- Live best-of-three scoring with love, 15, 30, 40, deuce, advantage, games, sets, tiebreaks, undo, haptics, and VoiceOver announcements.
- Tournament records with preparation notes, review notes, stages, formats, and outstanding linked-match counts.
- Training records with venues, duration, focus, effort, confidence, energy, pain, conditions, equipment, and notes.
- Dashboard summaries that mirror the Windows app's calm key cards, needs-attention items, next focus, recent matches, and training totals.
- Settings for tracking mode, form detail, score announcements, haptics, and dashboard visibility.
- Native Dynamic Type support, standard controls, headings, labels, status text, and accessible text summaries for statistics.

## Project structure

- `TennisTracker/App/TennisTrackerApp.swift`: SwiftUI app entry point.
- `TennisTracker/App/TennisTrackerRootView.swift`: the native tab-based app shell.
- `TennisTracker/Models/TennisModels.swift`: player, match, tournament, training, settings, sight-level, and tracking-mode data.
- `TennisTracker/Store/TennisStore.swift`: native on-device JSON persistence in Application Support.
- `TennisTracker/Scoring/TennisScoring.swift`: tennis scoring engine.
- `TennisTrackerShared/TennisWatchSyncModels.swift`: shared iPhone and Apple Watch sync payloads, conflict rules, and Watch activity factory helpers.
- `TennisTrackerWatchApp`: Apple Watch companion app with Today, Track, Live, and Recent pages.
- `TennisTracker/Stats/TennisStatistics.swift`: dashboard and report-style summaries.
- `TennisTracker/Views`: SwiftUI screens for each main feature area.
- `TennisTrackerTests`: tests for scoring and statistics.
- `project.yml`: XcodeGen recipe used to create the Xcode project on macOS.
- `codemagic.yaml`: free Codemagic workflow.
- `.github/workflows/ios-free-build.yml`: GitHub Actions macOS workflow used because GitHub was already authenticated locally and can run a free included-minutes macOS build.
- `Scripts/build_unsigned_ipa.sh`: macOS build script that packages an unsigned IPA.
- `Scripts/check_windows_prereqs.ps1`: checks Git, Apple support software, Apple services, and iPhone detection on Windows.
- `Scripts/download_latest_github_artifact.ps1`: downloads the newest successful GitHub Actions IPA artifact into `builds`.
- `Scripts/open_sideloadly_with_latest_ipa.ps1`: opens Sideloadly with the newest downloaded IPA.

## Reference Windows app findings

The Windows Tennis Tracker app is a native WPF application targeting `.NET` on Windows. It records player profiles, training sessions, matches, tournaments, dashboards, reports, settings, and local SQLite data.

Accessibility is already treated as core in the Windows version. The reference app uses named controls, heading levels, keyboard focus, standard WPF controls, and an assertive live status text area for screen-reader feedback. The iOS proof of concept mirrors that principle with native SwiftUI accessibility labels, values, heading traits, focus movement, Dynamic Type, and explicit VoiceOver announcements.

Relevant tennis terminology from the Windows app includes player, match, training, tournament, singles, doubles, opponent, result, set scores, tiebreak, win, loss, sight level, allowed bounces, and tracking modes. The iPhone app now implements the core workflow in native SwiftUI while keeping the Windows app as the reference.

## Accessibility guidance used

The iPhone app follows Apple's SwiftUI accessibility model by using native controls, explicit labels and values where needed, heading traits for important summaries, VoiceOver announcements for live scoring, Dynamic Type, and text-first statistical summaries. Current Apple guidance reviewed during this phase:

- Apple SwiftUI accessibility modifiers: https://developer.apple.com/documentation/swiftui/view-accessibility
- Apple Human Interface Guidelines, Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple WWDC guidance on accessible charts: https://developer.apple.com/videos/play/wwdc2021/10122/
- Apple SwiftUI chart accessibility descriptor: https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor%28_%3A%29
- Apple AXChart: https://developer.apple.com/documentation/accessibility/axchart

## Required free accounts

- A free Codemagic personal account.
- A source repository account supported by Codemagic, such as GitHub, GitLab, or Bitbucket.
- Your normal Apple Account for Sideloadly signing.

Do not enable Codemagic billing. Do not enrol in the paid Apple Developer Program. Do not configure App Store Connect or TestFlight for this phase.

As checked on 27 August 2026, Codemagic documents 500 free macOS M2 build minutes per month for individual personal accounts, reset on the first day of each month. Apple documents that Xcode Personal Team provisioning profiles expire after 7 days and that free accounts have limited App IDs and devices. Sideloadly documents support for free Apple IDs on Windows, with sideloaded apps valid for 7 days.

GitHub Actions is also a valid free cloud macOS build route while the account stays within its included free private-repository minutes. This project currently uses GitHub Actions first because the private repository is already created and authenticated on this Windows PC, while Codemagic still requires an interactive browser sign-in.

Sources:

- Codemagic pricing: https://docs.codemagic.io/billing/pricing/
- Codemagic unsigned iOS build guidance: https://docs.codemagic.io/yaml-code-signing/ios-simulator-builds/
- Apple membership comparison: https://developer.apple.com/support/compare-memberships/
- Sideloadly: https://sideloadly.io/
- SideStore install docs: https://docs.sidestore.io/docs/installation/install
- AltStore Classic downloads: https://altstore.io/
- GitHub Actions billing: https://docs.github.com/en/billing/concepts/product-billing/github-actions

## Actual repository

The iOS project is stored in a private GitHub repository:

`https://github.com/sidneytambin-maker/tennis-tracker-ios`

Current branch:

`codex/ios-poc`

Do not commit Apple Account passwords, Codemagic tokens, signing certificates, provisioning profiles, downloaded IPA files, or build artifacts.

## Installed Windows software

Installed on this Windows PC during setup:

- Apple Mobile Device Support `19.4.0.10`
- iTunes `12.13.10.3`
- iCloud for Windows legacy `7.21.0.23`
- Bonjour service, installed as an iCloud dependency
- Sideloadly `0.60.0`

Apple Mobile Device Service and Bonjour Service were running after installation.

## Local Git setup

This folder should be its own repository. From this folder:

```powershell
git init
git add .
git commit -m "Create iOS proof of concept"
```

Then push it to the free repository provider you want Codemagic to read from. GitHub is the simplest common choice, but any free Codemagic-supported provider is acceptable.

## GitHub Actions cloud build

This is the currently active cloud build route.

To run it from Windows:

```powershell
gh workflow run "iOS free development build" --ref codex/ios-poc
```

To watch it:

```powershell
gh run watch
```

Expected result: GitHub runs on a hosted macOS runner, installs XcodeGen, generates the Xcode project, runs the tests, builds an unsigned physical-device IPA, and uploads an artifact named `tennis-tracker-ios-development-unsigned`.

Actual result on 27 August 2026:

- Successful run: `33104948788`
- Commit built: `b6b4436`
- Artifact downloaded to: `builds\TennisTracker-phase-one-unsigned-33104948788.ipa`
- Current development builds download to: `builds\TennisTracker-development-unsigned-<run id>.ipa`
- Verified package contents include `Payload/TennisTracker.app/TennisTracker`
- First native development app build succeeded on run `33111054153`.
- The native development IPA downloaded to `builds\TennisTracker-development-unsigned-33111054153.ipa`.
- Sideloadly accepted that development IPA and refreshed the local installation record for the connected iPhone.

To download the newest successful artifact again:

```powershell
.\Scripts\download_latest_github_artifact.ps1
```

## Codemagic setup with NVDA

1. Open https://codemagic.io/start in your browser.
2. Sign up or sign in with your Google account.
3. If a CAPTCHA, Google sign-in prompt, email verification, or two-factor prompt appears, complete it personally. Do not share the code or password with Codex.
4. After sign-in, find the main navigation landmark, then the control named `Add application` or `Add app`.
5. Choose the repository provider that contains this iOS project.
6. Choose the repository for this folder.
7. When Codemagic asks for a workflow source, choose the option to use `codemagic.yaml` from the repository.
8. Start the workflow named `iOS free proof of concept`.
9. Confirm that the selected machine is a free personal macOS M2 build. Do not choose a paid team or billing option.

Expected result: the build runs tests, creates `TennisTracker-unsigned.ipa`, and exposes it in the build artifacts.

## Download the IPA

1. In Codemagic, open the finished build.
2. Navigate by heading to `Artifacts`.
3. Find the link named `TennisTracker-unsigned.ipa`.
4. Download it to Windows.
5. Also download or read `build-summary.txt`.

If the build fails before artifacts are created, open the failed step by heading and copy the failing error text into Codex. Do not copy secrets or account tokens.

## Windows signing and iPhone installation with Sideloadly

Sideloadly is the recommended first signing route because it is Windows-compatible and documents support for free Apple IDs.

Install prerequisites:

1. Install iTunes and iCloud from Apple web installers, not the Microsoft Store versions. Sideloadly states this is required on Windows.
2. Install Sideloadly from https://sideloadly.io/ or with Windows Package Manager using package `iOSGods.Sideloadly`.
3. Connect the iPhone by USB.
4. If the iPhone asks whether to trust this computer, choose `Trust` and enter the iPhone passcode.

Actual device status on 27 August 2026:

- Windows detected `Apple iPhone`.
- Sideloadly detected `Sidney's iPhone (27.0) 00008140-00120D84267B001C @USB`.
- Sideloadly required one-time administrator setup for local anisette. That warning was accepted and the Sideloadly main window reopened.
- Sideloadly successfully completed signing and installation after Apple Account password authentication and a six-digit Apple verification code.
- Final Sideloadly status: `Done.` and `100%`.

To check prerequisites again:

```powershell
.\Scripts\check_windows_prereqs.ps1
```

To open Sideloadly with the newest downloaded Tennis Tracker IPA:

```powershell
.\Scripts\open_sideloadly_with_latest_ipa.ps1
```

Sign and install:

1. Open Sideloadly on Windows.
2. Use NVDA object navigation or tab navigation to find the IPA file field or browse button.
3. Choose `TennisTracker-unsigned.ipa`.
4. Find the Apple ID field and enter your Apple Account email address.
5. Start the sideload/install action.
6. When the `Apple ID Authentication` dialog asks for `Password for sidney.tambin@googlemail.com`, enter the Apple Account password. Sideloadly states in this dialog that app-specific passwords are not supported.
7. When the `Apple ID Authentication` dialog asks for a verification code, read the six-digit code from the trusted Apple device, type it into the blank edit field, then activate `OK`.
8. Wait for Sideloadly to report `Done.` and `100%`.

On the iPhone:

1. Open `Settings`.
2. Go to `General`.
3. Open `VPN & Device Management`.
4. Under `Developer App`, choose the item named after your Apple Account.
5. Choose `Trust [your Apple Account name]`.
6. Confirm with `Trust`.
7. Return to the Home Screen and open `Tennis Tracker`.

## Seven-day limitation

With Apple free personal development provisioning, the installed app expires after 7 days. Apple also limits free Personal Team App IDs and registered devices. To keep development free, refresh or reinstall the app before or after expiry using Sideloadly. Do not enrol in the paid Apple Developer Program for this workflow.

## Refresh or reinstall after code changes

1. Make and commit source changes in this folder.
2. Push to the connected repository.
3. Run the GitHub Actions workflow again.
4. Download the new `TennisTracker-unsigned.ipa`.
5. Open Sideloadly and install the new IPA with the same Apple Account.
6. Launch `Tennis Tracker` on the iPhone and repeat the VoiceOver checks below.

## VoiceOver refinement checklist

Version `0.7.0` is the product-coherence accessibility build. It fixes tournament-created matches using today’s date, keeps tournament and match links on stable IDs, shows real linked matches inside tournament detail, adds explicit tournament deletion choices for linked matches, moves manual time entry to five-minute steps, keeps Training in the primary tab order, and simplifies match entry around details, format, and result.

Version `0.7.1` proved the Apple Watch feasibility path. It preserved the iPhone app and added the first minimum companion Watch target so the free cloud build and Sideloadly signing path could be tested before deeper Watch features were built.

Version `0.8.0` is the first useful Apple Watch companion build. It adds native Watch pages for Today, Track, Live, and Recent; quick Watch creation of training sessions, matches, and tournaments; large VoiceOver-friendly point buttons; match progress save/resume using stable record IDs; Watch-to-iPhone sync commands; queued offline Watch changes; needs-details handoff back to iPhone; and deterministic revision/date conflict handling.

The iPhone navigation uses native tabs. Dashboard, Player, Matches, Tournaments, and Training are direct bottom tabs; Settings is reachable through the native `More` tab when iOS needs to collapse the sixth destination.

Manual test priority:

1. Turn on VoiceOver before launching `Tennis Tracker`.
2. Confirm first launch starts at `Welcome to Tennis Tracker`, not a populated dashboard.
3. Double-tap `Set up my player profile`.
4. Enter a player name or preferred name.
5. Continue through player type, sight level, match type, tracking mode, season, theme, score announcements, and haptics.
6. Double-tap `Finish setup`.
7. Confirm the Dashboard says welcome using the entered preferred name and shows empty real-data summaries.
8. Double-tap every destination: Dashboard, Player, Matches, Tournaments, Training, and Settings through More.
9. In Settings, change theme or scoring announcement mode and double-tap `Save settings`; confirm it announces `Settings saved`.
10. In Player, edit the profile and double-tap `Save`.
11. Open Tournaments from the tab bar, then add one tournament.
12. Add one training session and one match.
13. Link a match to a tournament or training session and confirm it appears in the related summaries.
14. Track match scoring and test named point buttons, automatic/reduced/off announcements, Hear full score, sudden-death deuce, Undo, Reset, Save Match Progress, and Finish Match.
15. Close and reopen the app; confirm the player profile and created records persist.
16. Confirm no old Player One, practice opponent, or sample training records appear.
17. Increase text size to an accessibility size and repeat tab, setup, settings, form, and live scoring activation checks.
18. On Apple Watch, confirm Tennis Tracker appears as a companion app. If it does not appear automatically, open the iPhone Watch app, find Tennis Tracker, and enable `Show App on Apple Watch`.
19. With VoiceOver on Apple Watch, check Today, Track, Live, and Recent. Record a training session, finish it, and confirm the iPhone dashboard shows the activity under `Activities Need Details`.
20. Record a Watch match, use both point buttons, Save Match Progress, resume the same match on iPhone, then Finish Match and confirm there is only one match record.

## Current limitations

- Codex cannot complete your Apple Account sign-in, Google sign-in, CAPTCHA, two-factor authentication, device trust prompt, or legal acceptance.
- Automated tests cannot prove real VoiceOver behaviour completely; they are guardrails alongside the physical VoiceOver checklist.
- The IPA produced by GitHub Actions is unsigned. Sideloadly signs it on Windows using your free Apple Account.
- This workflow intentionally does not include App Store Connect, TestFlight, or the paid Apple Developer Program.
