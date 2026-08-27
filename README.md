# Tennis Tracker iOS proof of concept

This folder contains phase one of the native iOS Tennis Tracker project. The existing Windows project at `C:\Users\User\dodge Dropbox\sidney tambin\shared folders\klaudia and sidney\TennisTracker` is a read-only reference implementation and must not be used as the iOS working folder.

## Current scope

Phase one is deliberately small. It proves the pipeline from Windows source files to a free macOS cloud build, then to a Windows signing and sideloading step using a normal Apple Account.

The proof-of-concept app contains:

- Navigation title: `Tennis Tracker`
- Heading: `Development build`
- Button: `Player One wins point`
- Button: `Player Two wins point`
- Current test score exposed as text and as a VoiceOver accessibility value
- VoiceOver announcement after every score change
- Native Dynamic Type support

## Project structure

- `TennisTracker/App/TennisTrackerApp.swift`: SwiftUI app entry point.
- `TennisTracker/App/ScoreboardView.swift`: accessible proof-of-concept screen.
- `TennisTracker/Scoring/TestScore.swift`: tennis point progression and announcement wording.
- `TennisTrackerTests/TestScoreTests.swift`: tests for the scoring and spoken output.
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

Relevant tennis terminology from the Windows app includes player, match, training, tournament, singles, doubles, opponent, result, set scores, tiebreak, win, loss, and tracking modes. Phase one only implements point scoring because the request is to prove the pipeline before porting the full app.

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

The phase-one iOS project is stored in a private GitHub repository:

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
gh workflow run "iOS free proof-of-concept build" --ref codex/ios-poc
```

To watch it:

```powershell
gh run watch
```

Expected result: GitHub runs on a hosted macOS runner, installs XcodeGen, generates the Xcode project, runs the tests, builds an unsigned physical-device IPA, and uploads an artifact named `tennis-tracker-ios-phase-one-unsigned`.

Actual result on 27 August 2026:

- Successful run: `33104948788`
- Commit built: `b6b4436`
- Artifact downloaded to: `builds\TennisTracker-phase-one-unsigned-33104948788.ipa`
- Verified package contents include `Payload/TennisTracker.app/TennisTracker`

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
- A signing attempt reached Apple Account authentication, but Apple rejected the supplied password with Sideloadly error `Login failed (-22406): Enter the correct password for this Apple Account.` Do not keep retrying with the same password because repeated failures can lock the Apple Account.

To check prerequisites again:

```powershell
.\Scripts\check_windows_prereqs.ps1
```

To open Sideloadly with the newest downloaded Tennis Tracker IPA:

```powershell
.\Scripts\open_sideloadly_with_latest_ipa.ps1
```

Current signing blocker:

If Sideloadly reports `Login failed (-22406): Enter the correct password for this Apple Account`, update the local temporary password file with the current correct Apple Account password, or sign in manually when Sideloadly asks. Do not commit the password file. Do not paste the password into chat.

If Sideloadly reports `Login failed (-20209): This Apple Account has been locked for security reasons`, unlock the Apple Account through Apple's account recovery page before trying Sideloadly again.

Sign and install:

1. Open Sideloadly on Windows.
2. Use NVDA object navigation or tab navigation to find the IPA file field or browse button.
3. Choose `TennisTracker-unsigned.ipa`.
4. Find the Apple ID field and enter your Apple Account email address.
5. Start the sideload/install action.
6. If Apple asks for a password, app-specific password, two-factor code, CAPTCHA, or account approval, complete that personally.
7. Wait for Sideloadly to report that installation has completed.

On the iPhone:

1. Open `Settings`.
2. Go to `General`.
3. Open `VPN & Device Management`.
4. Under `Developer App`, choose the item named after your Apple Account.
5. Choose `Trust [your Apple Account name]`.
6. Confirm with `Trust`.
7. Return to the Home Screen and open `Tennis Tracker`.

## Seven-day limitation

With Apple free personal development provisioning, the installed app expires after 7 days. Apple also limits free Personal Team App IDs and registered devices. To keep the proof-of-concept free, refresh or reinstall the app before or after expiry using Sideloadly. Do not enrol in the paid Apple Developer Program for phase one.

## Refresh or reinstall after code changes

1. Make and commit source changes in this folder.
2. Push to the connected repository.
3. Run the Codemagic workflow again.
4. Download the new `TennisTracker-unsigned.ipa`.
5. Open Sideloadly and install the new IPA with the same Apple Account.
6. Launch `Tennis Tracker` on the iPhone and repeat the VoiceOver checks below.

## VoiceOver test procedure

1. On the iPhone, turn on VoiceOver.
2. Open `Tennis Tracker`.
3. Confirm VoiceOver announces the app title or screen content.
4. Navigate by headings and confirm the heading is `Development build`.
5. Swipe to the score and confirm VoiceOver says `Current test score` and the current value, initially `Player One Love, Player Two Love`.
6. Swipe to `Player One wins point`, button. Double-tap it.
7. Confirm VoiceOver announces that Player One won the point and gives the updated score.
8. Swipe to `Player Two wins point`, button. Double-tap it.
9. Confirm VoiceOver announces that Player Two won the point and gives the updated score.
10. Continue testing to `Deuce`, `Advantage Player One`, `Advantage Player Two`, and game winner announcements.
11. Increase iPhone text size and repeat the main navigation and button tests.

## Current limitations

- Codex cannot complete your Apple Account sign-in, Google sign-in, CAPTCHA, two-factor authentication, device trust prompt, or legal acceptance.
- Codex cannot truthfully mark phase one successful until the Codemagic build artifact has been downloaded, signed, installed, launched, and tested on your physical iPhone.
- The IPA produced by Codemagic is unsigned. The intended experiment is that Sideloadly signs it on Windows using your free Apple Account.
- If Sideloadly cannot sign the Codemagic unsigned IPA, stop and record the exact Sideloadly error. The fallback to investigate is SideStore or AltStore Classic, but the workflow must remain legitimate and free.
- This phase intentionally does not include App Store Connect, TestFlight, paid Apple Developer Program distribution, or the full Windows Tennis Tracker feature set.
