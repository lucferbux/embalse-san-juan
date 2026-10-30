#!/bin/bash
# Takes App Store screenshots from a Debug build, which opens each screen from launch arguments.
#
#   scripts/export-screenshots.sh              # iPhone 6.9", iPad 13", iPhone Duo outer, Apple Watch
#   scripts/export-screenshots.sh --duo-inner  # only iPhone Duo's inner display (open it first, see below)
#
# Sizes App Store Connect accepts for these classes:
#   iPhone 6.9"       1320x2868
#   iPad 13"          2064x2752
#   iPhone Duo outer  1398x2034
#   iPhone Duo inner  2007x2853
#
# The iPhone Duo simulator boots closed. Only Device Hub can open it (Xcode > Open Developer Tool >
# Device Hub): neither simctl nor XCTest can change the pose. Open it there, then run --duo-inner.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="ios/EmbalseSanJuan.xcodeproj"
DERIVED="build/DerivedData"
OUT="fastlane/screenshots/es-ES"
WATCH_OUT="fastlane/screenshots_watch/es-ES"
BUNDLE="com.lucferbux.embalsesanjuan"
mkdir -p "$OUT" "$WATCH_OUT"

udid_of() {
    xcrun simctl list devices available -j | /usr/bin/python3 -I -c "
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for device in devices:
        if device['name'] == name:
            print(device['udid'])
            sys.exit(0)
" "$1"
}

ensure_device() {
    local name="$1" type="$2" runtime="$3"
    local udid
    udid="$(udid_of "$name")"
    [ -n "$udid" ] || udid="$(xcrun simctl create "$name" "$type" "$runtime")"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
    echo "$udid"
}

build_ios() {
    echo "==> Building the iOS app"
    make generate >/dev/null
    xcodebuild build -quiet -project "$PROJECT" -scheme EmbalseSanJuan -configuration Debug \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" >/dev/null
}

prepare_ios() {
    local udid="$1"
    xcrun simctl install "$udid" "$DERIVED/Build/Products/Debug-iphonesimulator/EmbalseSanJuan.app"
    # Apple's convention for marketing shots: full bars, full battery, 9:41.
    xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
        --cellularMode active --wifiMode active --wifiBars 3 2>/dev/null || true
    xcrun simctl ui "$udid" appearance light
}

shoot() {
    local udid="$1" file="$2" display="$3"
    shift 3
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE" "$@" >/dev/null
    /bin/sleep 6
    if [ -n "$display" ]; then
        xcrun simctl io "$udid" screenshot --display="$display" "$file" 2>/dev/null
    else
        xcrun simctl io "$udid" screenshot "$file" 2>/dev/null
    fi
    printf '   %-34s %s\n' "$(basename "$file")" "$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/{printf "%s ", $2}')"
}

shoot_set() {
    local udid="$1" prefix="$2" display="${3:-}"
    shoot "$udid" "$OUT/$prefix-01-ahora.png" "$display"
    shoot "$udid" "$OUT/$prefix-02-boletin.png" "$display" -ScreenshotScroll weekly
    shoot "$udid" "$OUT/$prefix-03-alberche.png" "$display" -ScreenshotScroll alberche
    shoot "$udid" "$OUT/$prefix-04-historico.png" "$display" -ScreenshotScene history -HistoryRange all
}

if [ "${1:-}" = "--duo-inner" ]; then
    build_ios
    udid="$(udid_of "iPhone Duo")"
    prepare_ios "$udid"
    # The inner display is the larger of the two the device reports.
    port="$(xcrun simctl io "$udid" enumerate | /usr/bin/python3 -I -c "
import re, sys
text = sys.stdin.read()
blocks = re.split(r'(?=Port:)', text)
best = (0, '')
for block in blocks:
    port = re.search(r'UUID: ([0-9A-F-]{36})', block)
    size = re.search(r'Default width: (\d+)', block) or re.search(r'width[:=] ?(\d+)', block)
    if port and size and int(size.group(1)) > best[0]:
        best = (int(size.group(1)), port.group(1))
print(best[1])
")"
    echo "==> iPhone Duo inner (display $port)"
    shoot_set "$udid" "duo-inner" "$port"
    exit 0
fi

build_ios

echo "==> iPhone 6.9\""
udid="$(ensure_device "iPhone 18 Pro Max" com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0)"
prepare_ios "$udid"
shoot_set "$udid" "iphone-69"

echo "==> iPad 13\""
udid="$(ensure_device "iPad Pro 13-inch (M5)" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB com.apple.CoreSimulator.SimRuntime.iOS-27-0)"
prepare_ios "$udid"
shoot "$udid" "$OUT/ipad-13-01-ahora.png" ""
shoot "$udid" "$OUT/ipad-13-04-historico.png" "" -ScreenshotScene history -HistoryRange all
shoot "$udid" "$OUT/ipad-13-05-ficha.png" "" -ScreenshotScene about

echo "==> iPhone Duo outer"
udid="$(ensure_device "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1)"
prepare_ios "$udid"
shoot "$udid" "$OUT/duo-outer-01-ahora.png" ""
shoot "$udid" "$OUT/duo-outer-02-boletin.png" "" -ScreenshotScroll weekly
shoot "$udid" "$OUT/duo-outer-04-historico.png" "" -ScreenshotScene history -HistoryRange all

echo "==> Apple Watch"
xcodebuild build -quiet -project "$PROJECT" -scheme EmbalseWatch -configuration Debug \
    -destination 'generic/platform=watchOS Simulator' -derivedDataPath "$DERIVED" >/dev/null
udid="$(ensure_device "Apple Watch Ultra 4 (49mm)" com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-4-49mm com.apple.CoreSimulator.SimRuntime.watchOS-27-0)"
xcrun simctl install "$udid" "$DERIVED/Build/Products/Debug-watchsimulator/EmbalseWatch.app"
BUNDLE="$BUNDLE.watchkitapp" shoot "$udid" "$WATCH_OUT/watch-01-ahora.png" ""
