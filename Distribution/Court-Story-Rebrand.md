# Court Story Build 32

The TestFlight record was renamed before the installed apps. Build 31 still used the former visible name and TT artwork. Build 32 completes that branding change without renaming the app's permanent bundle IDs, App Group, widget kinds, URL scheme, persistence keys or library file locations.

Both platform icons now show a high-contrast CS tennis-ball monogram. The full system display name and spoken Home Screen name are Court Story on iPhone and Apple Watch; the complication extension has the same full name. CS is not an accessibility label.

Updated surfaces include onboarding, Siri descriptions and responses, Calendar and Health permission explanations, Watch connectivity status, new Calendar-event notes, private-backup export names and messages, offline privacy information, the public privacy page and TestFlight copy. Removed company attribution from the app's privacy policy. Existing user records, previously exported files and past Calendar notes are not destructively rewritten.

Source regression tests reject retired visible branding, pin the approved icon hash and protect stable storage and sync identifiers. Archive and signed-IPA checks reject shortened or stale app names in any component, old permission copy and old branding in compiled executables. Apple's native asset inspection checks both compiled icon catalogues before upload.

Publication status: pending the full native validation and upload for this exact source revision. Do not claim build 32 is available until Apple reports successful processing and internal build assignment is verified.

Court Story 0.1.0 (31) remains in Apple's external beta review queue. Do not cancel that review merely to publish an internal branding update. Sidney's existing invitation was already accepted; Apple's resend endpoint returned TESTER_INVITE.ALREADY_ACCEPTED, so no replacement invitation was sent. Email the verified update details once build 32 is available.
