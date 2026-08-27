#!/bin/bash
set -euo pipefail

xcodebuild clean build \
  -project "TennisTrackeriOS.xcodeproj" \
  -scheme "TennisTracker" \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

mkdir -p artifacts/Payload
APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Release-iphoneos/TennisTracker.app" -type d | head -n 1)"

if [ -z "$APP_PATH" ]; then
  echo "Could not find the unsigned Tennis Tracker.app build output." >&2
  exit 1
fi

rm -rf artifacts/Payload/*
cp -R "$APP_PATH" artifacts/Payload/
(
  cd artifacts
  /usr/bin/zip -qry TennisTracker-unsigned.ipa Payload
)

cat > artifacts/build-summary.txt <<SUMMARY
Build artifact: TennisTracker-unsigned.ipa
Signing status: unsigned
Intended next step: download on Windows and sign/install with Sideloadly using a free Apple Account.
Bundle identifier: com.inclusophy.tennistracker.dev
SUMMARY
