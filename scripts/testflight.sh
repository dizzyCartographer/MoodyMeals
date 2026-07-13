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

# xcodebuild -exportArchive can exit 0 even when App Store validation
# rejects the upload (seen 2026-07-12, error 90474) — gate on its own
# success marker instead of the exit code.
run_export() {
  local plist="$1" out
  out=$(xcodebuild -exportArchive -archivePath build/Moody.xcarchive \
    -exportOptionsPlist "$plist" \
    -exportPath build/export -allowProvisioningUpdates 2>&1) || true
  echo "$out"
  grep -q "EXPORT SUCCEEDED" <<<"$out"
}

if [[ $UPLOAD == 1 ]]; then
  echo "▸ uploading to App Store Connect"
  run_export scripts/ExportOptions-upload.plist \
    || { echo "✗ upload rejected — Apple's reason is in the output above"; exit 1; }
  echo "✓ uploaded — it appears in TestFlight after Apple's processing (~5–15 min)"
else
  echo "▸ exporting .ipa (no upload)"
  run_export scripts/ExportOptions-export.plist \
    || { echo "✗ export failed — see output above"; exit 1; }
  echo "✓ IPA at build/export/Moody.ipa — drop on Transporter, or rerun with --upload"
fi
