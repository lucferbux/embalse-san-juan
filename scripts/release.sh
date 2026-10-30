#!/bin/bash
# Archives the iOS app (with its widgets and Apple Watch app) and uploads it to App Store Connect.
# Uploading can't be undone: a build number can never be used twice. Bump CURRENT_PROJECT_VERSION in
# ios/project.yml first. Nothing here submits for review.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

git diff --quiet && git diff --cached --quiet || { echo "Commit your changes first: never archive uncommitted work." >&2; exit 1; }
make check

cat >"$OUT/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>7Y2Y846R76</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST

# The API key, so uploads don't depend on Xcode's signed-in account.
KEY_ID="${ASC_KEY_ID:-KMSBU6865L}"
AUTH=(-allowProvisioningUpdates
    -authenticationKeyID "$KEY_ID"
    -authenticationKeyIssuerID "${ASC_ISSUER_ID:-69a6de88-17cf-47e3-e053-5b8c7c11a4d1}"
    -authenticationKeyPath "${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8}")

xcodebuild archive -quiet -project ios/EmbalseSanJuan.xcodeproj -scheme EmbalseSanJuan -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$OUT/Embalse.xcarchive" "${AUTH[@]}"
xcodebuild -exportArchive -archivePath "$OUT/Embalse.xcarchive" -exportOptionsPlist "$OUT/ExportOptions.plist" \
    -exportPath "$OUT/export" "${AUTH[@]}" 2>&1 | grep -E 'Upload succeeded|EXPORT|error:'
