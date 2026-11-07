#!/bin/bash
# Captures every screen in every format and mode for the ux-adversary reviewer (.claude/agents/ux-adversary.md).
# Not store screenshots: those come from export-screenshots.sh and export-android-screenshots.sh.
#
#   scripts/capture-matrix.sh               # iOS, watchOS, widgets, and Android if an emulator is running
#   scripts/capture-matrix.sh --ios         # Apple formats only
#   scripts/capture-matrix.sh --android     # Android only (needs a running emulator)
#   scripts/capture-matrix.sh --duo-inner   # also iPhone Duo's inner display: open it in Device Hub first
#   scripts/capture-matrix.sh --ipad-landscape  # also iPad in landscape: rotate it in Device Hub first
#   ONLY="ipad-landscape duo-inner" scripts/capture-matrix.sh --ios --ipad-landscape --duo-inner
#                                           # just those formats, keeping the rest of the matrix
#
# Device Hub replaces Simulator.app, and neither simctl nor the app can rotate a simulator or open the Duo,
# so those two poses are opt-in once you have set them by hand.
#
# Output: build/ux-review/<format>/<mode>-<NN>-<screen>.png, where mode is light, dark or large (the largest
# accessibility text size), plus build/ux-review/MANIFEST.txt with what was and was not captured.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT="ios/EmbalseSanJuan.xcodeproj"
DERIVED="build/DerivedData"
BUNDLE="com.lucferbux.embalsesanjuan"
OUT="build/ux-review"
MANIFEST="$OUT/MANIFEST.txt"

want_ios=1 want_android=1 duo_inner=0 ipad_landscape=0
for arg in "$@"; do
    case "$arg" in
        --ios) want_android=0 ;;
        --android) want_ios=0 ;;
        --duo-inner) duo_inner=1 ;;
        --ipad-landscape) ipad_landscape=1 ;;
        *) echo "Unknown option $arg" >&2; exit 2 ;;
    esac
done

# Each format replaces only its own folder, so an opt-in run (--duo-inner) keeps the rest of the matrix.
mkdir -p "$OUT"
echo "== Run $(date -u +%Y-%m-%dT%H:%MZ) from $(git rev-parse --short HEAD)$(git diff --quiet || echo ' (uncommitted changes)')" >>"$MANIFEST"
note() { echo "$*" | tee -a "$MANIFEST"; }
# Runs one format in a subshell, so a simulator that misbehaves is recorded instead of ending the whole run.
try() {
    if [ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $2 "* ]]; then return; fi
    ( "$@" ) || note "FAILED $2: see the log above"
}

# ---------- Apple ----------

# Every screen the app can open from launch arguments (see ContentView's DEBUG hooks).
ios_screens() {
    local udid="$1" dir="$2" mode="$3" display="${4:-}"
    shift 4 || true
    local extra=("$@")
    shoot "$udid" "$dir/$mode-01-ahora.png" "$display" ${extra[@]+"${extra[@]}"}
    shoot "$udid" "$dir/$mode-02-boletin.png" "$display" -ScreenshotScroll weekly ${extra[@]+"${extra[@]}"}
    shoot "$udid" "$dir/$mode-03-alberche.png" "$display" -ScreenshotScroll alberche ${extra[@]+"${extra[@]}"}
    shoot "$udid" "$dir/$mode-04-historico.png" "$display" -ScreenshotScene history ${extra[@]+"${extra[@]}"}
    shoot "$udid" "$dir/$mode-05-historico-1988.png" "$display" -ScreenshotScene history -HistoryRange all ${extra[@]+"${extra[@]}"}
    shoot "$udid" "$dir/$mode-06-ficha.png" "$display" -ScreenshotScene about ${extra[@]+"${extra[@]}"}
    shoot "$udid" "$dir/$mode-07-sugerencias.png" "$display" -ScreenshotScene suggestions ${extra[@]+"${extra[@]}"}
    shoot "$udid" "$dir/$mode-08-propinas.png" "$display" -ScreenshotScene tips ${extra[@]+"${extra[@]}"}
}

ios_format() {
    local format="$1" device="$2" display="${3:-}"
    shift 3 || true
    local udid
    udid="$(udid_of "$device")"
    if [ -z "$udid" ]; then
        note "SKIPPED $format: no simulator named \"$device\""
        return
    fi
    echo "==> $format ($device)"
    rm -rf "${OUT:?}/$format" && mkdir -p "$OUT/$format"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
    prepare_ios "$udid"
    for mode in light dark large; do
        set_mode "$udid" "$mode"
        ios_screens "$udid" "$OUT/$format" "$mode" "$display" "$@"
    done
    set_mode "$udid" light
    note "OK $format: $device, light dark large"
}

watch_format() {
    local format="$1" device="$2" udid
    udid="$(udid_of "$device")"
    if [ -z "$udid" ]; then
        note "SKIPPED $format: no simulator named \"$device\""
        return
    fi
    echo "==> $format ($device)"
    rm -rf "${OUT:?}/$format" && mkdir -p "$OUT/$format"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
    xcrun simctl install "$udid" "$DERIVED/Build/Products/Debug-watchsimulator/EmbalseWatch.app"
    # watchOS has no light appearance, so only the default and the largest text size.
    for mode in light large; do
        set_mode "$udid" "$mode"
        BUNDLE="$BUNDLE.watchkitapp" shoot "$udid" "$OUT/$format/$mode-01-ahora.png" ""
        BUNDLE="$BUNDLE.watchkitapp" shoot "$udid" "$OUT/$format/$mode-02-curva.png" "" -ScreenshotPage 1
        BUNDLE="$BUNDLE.watchkitapp" shoot "$udid" "$OUT/$format/$mode-03-datos.png" "" -ScreenshotPage 2
    done
    set_mode "$udid" light
    note "OK $format: $device, default and large text"
}

capture_apple() {
    # shellcheck source=lib/ios-sim.sh
    source scripts/lib/ios-sim.sh
    build_ios
    build_watch

    try ios_format iphone-69 "iPhone 18 Pro Max" ""
    try ios_format iphone-compact "iPhone 17e" ""
    if [ "$ipad_landscape" = 1 ]; then
        try ios_format ipad-landscape "iPad Pro 13-inch (M5)" ""
    else
        try ios_format ipad-portrait "iPad Pro 13-inch (M5)" ""
        note "SKIPPED ipad-landscape: rotate the iPad in Device Hub, then run with --ios --ipad-landscape"
    fi
    # The Duo boots closed; display 1 is the outer one (see export-screenshots.sh).
    try ios_format duo-outer "iPhone Duo" 1
    if [ "$duo_inner" = 1 ]; then
        ios_format duo-inner "iPhone Duo" ""
    else
        note "SKIPPED duo-inner: open iPhone Duo in Device Hub, then run with --duo-inner"
    fi
    note "SKIPPED ipad-split: simctl cannot start Split View; the narrow split uses the compact layout, covered by iphone-compact"

    try watch_format watch-large "Apple Watch Ultra 4 (49mm)"
    try watch_format watch-small "Apple Watch SE 3 (40mm)"

    if [ -n "${ONLY:-}" ] && [[ " $ONLY " != *" widgets-ios "* ]]; then return; fi
    echo "==> widgets-ios"
    make widgets >/dev/null
    rm -rf "${OUT:?}/widgets-ios" && mkdir -p "$OUT/widgets-ios"
    # WidgetSnapshotTests names files <family>-<variant>.png; the reviewer reads <mode>-<name>.png.
    for file in build/widget-snapshots/*.png; do
        name="$(basename "$file" .png)"
        case "$name" in
            *-dark) cp "$file" "$OUT/widgets-ios/dark-${name%-dark}.png" ;;
            *-tinted) cp "$file" "$OUT/widgets-ios/tinted-${name%-tinted}.png" ;;
            *-light) cp "$file" "$OUT/widgets-ios/light-${name%-light}.png" ;;
            *) cp "$file" "$OUT/widgets-ios/light-$name.png" ;;
        esac
    done
    note "OK widgets-ios: every family from WidgetSnapshotTests"
}

# ---------- Android ----------

android_format() {
    local format="$1" width="$2" height="$3" density="$4" swipes="$5" dir="$OUT/$1"
    echo "==> $format (${width}x${height} @ $density dpi)"
    rm -rf "$dir" && mkdir -p "$dir"
    adb shell wm size "${width}x${height}"
    adb shell wm density "$density"
    /bin/sleep 4
    for mode in light dark large; do
        adb shell cmd uimode night "$([ "$mode" = dark ] && echo yes || echo no)" >/dev/null
        adb shell settings put system font_scale "$([ "$mode" = large ] && echo 2.0 || echo 1.0)"
        /bin/sleep 2
        open; shoot "$dir/$mode-01-ahora.png"
        scroll "$height" "$swipes"; shoot "$dir/$mode-02-boletin.png"
        scroll "$height" "$swipes"; shoot "$dir/$mode-03-alberche.png"
        open history; shoot "$dir/$mode-04-historico.png"
        open about; shoot "$dir/$mode-06-ficha.png"
        open suggestions; shoot "$dir/$mode-07-sugerencias.png"
    done
    note "OK $format: ${width}x${height} @ $density dpi, light dark large"
}

capture_android() {
    export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
    : "${JAVA_HOME:=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
    export JAVA_HOME
    APP="com.lucferbux.embalsesanjuan"
    if [ "$(adb get-state 2>/dev/null)" != device ]; then
        note "SKIPPED android-*: no emulator running (see the run-android skill)"
        return
    fi
    (cd android && ./gradlew --quiet assembleDebug)
    adb install -r android/app/build/outputs/apk/debug/app-debug.apk >/dev/null
    # shellcheck source=lib/android-emu.sh
    source scripts/lib/android-emu.sh
    demo_start
    trap reset EXIT

    try android_format android-phone 1080 2400 420 2
    # A book-style foldable, open: the inner display of a Pixel Fold-class device.
    try android_format android-foldable 2208 1840 420 1
    try android_format android-tablet 2560 1600 320 1
    note "SKIPPED android-foldable posture: wm size only changes the size; a real hinge needs the foldable AVD"
    note "SKIPPED widgets-android: Glance widgets have no snapshot test yet; capture them by hand on the home screen"
    note "SKIPPED wear: there is no Wear OS app yet"
}

[ "$want_ios" = 1 ] && capture_apple
[ "$want_android" = 1 ] && capture_android

echo
echo "Done. Review with the ux-adversary agent over $OUT."
cat "$MANIFEST"
