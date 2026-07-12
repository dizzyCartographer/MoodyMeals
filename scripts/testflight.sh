#!/bin/bash
# TestFlight lane (TF-1) — archive, export, and (with --upload) push to App
# Store Connect. Safe by default: without --upload it produces an .ipa in
# build/export/ for Transporter, touching nothing external.
#
# Requires: Xcode signed into Maria's Apple account (team RC99K6SXQX), and —
# for --upload — the App Store Connect app record for com.mariayarley.Moody
# (one-time, see docs/TESTFLIGHT.md).
set -euo pipefail
cd "$(dirname "$0")/.."

UPLOAD=0
[[ "${1:-}" == "--upload" ]] && UPLOAD=1

# Monotonic build number nobody has to remember to bump.
BUILD_NUMBER=$(git rev-list --count HEAD)
echo "▸ build number $BUILD_NUMBER (git commit count)"

echo "▸ regenerating project"
xcodegen generate

echo "▸ safety gate: full engine suite (nothing ships over a red test)"
xcodebuild test -project Moody.xcodeproj -scheme MoodyEngine \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet

echo "▸ archiving (Release, device)"
xcodebuild archive -project Moody.xcodeproj -scheme Moody \
  -destination 'generic/platform=iOS' \
  -archivePath build/Moody.xcarchive \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  -allowProvisioningUpdates -quiet

if [[ $UPLOAD == 1 ]]; then
  echo "▸ uploading to App Store Connect"
  xcodebuild -exportArchive -archivePath build/Moody.xcarchive \
    -exportOptionsPlist scripts/ExportOptions-upload.plist \
    -exportPath build/export -allowProvisioningUpdates
  echo "✓ uploaded — it appears in TestFlight after Apple's processing (~5–15 min)"
else
  echo "▸ exporting .ipa (no upload)"
  xcodebuild -exportArchive -archivePath build/Moody.xcarchive \
    -exportOptionsPlist scripts/ExportOptions-export.plist \
    -exportPath build/export -allowProvisioningUpdates
  echo "✓ IPA at build/export/Moody.ipa — drop on Transporter, or rerun with --upload"
fi
