#!/bin/bash
# Takes App Store screenshots from a Debug build, which opens each screen from launch arguments.
#
#   scripts/export-screenshots.sh              # iPhone 6.9", iPad 13", Apple Watch
#   scripts/export-screenshots.sh --watch      # Apple Watch only
#   scripts/export-screenshots.sh --duo-outer  # iPhone Duo's outer display
#   scripts/export-screenshots.sh --duo-inner  # iPhone Duo's inner display (open it first, see below)
#
# Sizes App Store Connect accepts for these classes:
#   iPhone 6.9"       1320x2868
#   iPad 13"          2064x2752
#   iPhone Duo outer  1398x2034
#   iPhone Duo inner  2007x2853
#
# The iPhone Duo simulator boots closed. Only Device Hub can open it (Xcode > Open Developer Tool >
# Device Hub): neither simctl nor XCTest can change the pose. Open it there, then run --duo-inner.
# Raw shots go in fastlane/screenshots_raw/ios. swift scripts/make-creative-assets.swift frames them for the
# store: Duo shots into fastlane/screenshots_duo, not the deliver folder, because App Store Connect only requires them
# from April 2027, and deliver doesn't recognise their sizes.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="ios/EmbalseSanJuan.xcodeproj"
DERIVED="build/DerivedData"
OUT="fastlane/screenshots_raw/ios"
BUNDLE="com.lucferbux.embalsesanjuan"
mkdir -p "$OUT"

# shellcheck source=lib/ios-sim.sh
source scripts/lib/ios-sim.sh

# The 2.0 story: today's water, the same water as a year, how this year compares, and the river.
shoot_set() {
    local udid="$1" prefix="$2" display="${3:-}"
    shoot "$udid" "$OUT/$prefix-01-ahora.png" "$display"
    shoot "$udid" "$OUT/$prefix-02-ano.png" "$display" -CardMode year
    shoot "$udid" "$OUT/$prefix-03-historico.png" "$display" -ScreenshotTab year
    shoot "$udid" "$OUT/$prefix-04-el-rio.png" "$display" -ScreenshotTab river
}

shoot_watch() {
    build_watch
    local udid
    udid="$(ensure_device "Apple Watch Ultra 4 (49mm)" com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-4-49mm com.apple.CoreSimulator.SimRuntime.watchOS-27-0)"
    xcrun simctl install "$udid" "$DERIVED/Build/Products/Debug-watchsimulator/EmbalseWatch.app"
    BUNDLE="$BUNDLE.watchkitapp" shoot "$udid" "$OUT/watch-01-ahora.png" ""
    BUNDLE="$BUNDLE.watchkitapp" shoot "$udid" "$OUT/watch-02-curva.png" "" -ScreenshotPage 1
    BUNDLE="$BUNDLE.watchkitapp" shoot "$udid" "$OUT/watch-03-datos.png" "" -ScreenshotPage 2
}

if [ "${1:-}" = "--watch" ]; then
    make generate >/dev/null
    echo "==> Apple Watch"
    shoot_watch
    exit 0
fi

if [ "${1:-}" = "--duo-outer" ]; then
    # The simulator boots closed, which is the outer display.
    build_ios
    udid="$(udid_of "iPhone Duo")"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
    prepare_ios "$udid"
    OUT="fastlane/screenshots_raw/ios"
    mkdir -p "$OUT"
    echo "==> iPhone Duo outer"
    # simctl numbers the displays: 1 is the outer one (1398x2034), 3 the inner one (2007x2853).
    shoot_set "$udid" "duo-outer" 1
    exit 0
fi

if [ "${1:-}" = "--duo-inner" ]; then
    # With the device open, the simulator's default display is the inner one.
    build_ios
    udid="$(udid_of "iPhone Duo")"
    prepare_ios "$udid"
    OUT="fastlane/screenshots_raw/ios"
    mkdir -p "$OUT"
    echo "==> iPhone Duo inner"
    shoot "$udid" "$OUT/duo-inner-01-ahora.png" ""
    shoot "$udid" "$OUT/duo-inner-02-ano.png" "" -CardMode year
    shoot "$udid" "$OUT/duo-inner-03-historico.png" "" -ScreenshotTab year
    shoot "$udid" "$OUT/duo-inner-04-el-rio.png" "" -ScreenshotTab river
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
shoot "$udid" "$OUT/ipad-13-02-ano.png" "" -CardMode year
shoot "$udid" "$OUT/ipad-13-03-historico.png" "" -ScreenshotTab year
shoot "$udid" "$OUT/ipad-13-04-el-rio.png" "" -ScreenshotTab river

echo "==> Apple Watch"
shoot_watch
