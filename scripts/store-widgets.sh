#!/bin/bash
# Renders the widgets for the store images with today's real data, in Spanish: saves the public snapshot and history
# to build/store-data, then runs WidgetSnapshotTests/testStoreWidgets. Output: build/widget-snapshots/store-*.png.
set -euo pipefail
cd "$(dirname "$0")/.."
BASE="https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents/public"
mkdir -p build/store-data
for doc in snapshot history; do
    curl -fsS "$BASE/$doc" | /usr/bin/python3 -I -c "import json,sys; print(json.load(sys.stdin)['fields']['payload']['stringValue'])" > "build/store-data/$doc.json"
done
make generate >/dev/null
xcodebuild test -quiet -project ios/EmbalseSanJuan.xcodeproj -scheme EmbalseSanJuan \
    -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO \
    -testLanguage es -testRegion ES -only-testing:EmbalseKitTests/WidgetSnapshotTests/testStoreWidgets
ls build/widget-snapshots/store-*.png
