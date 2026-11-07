# Simulator helpers shared by export-screenshots.sh and capture-matrix.sh. Source it from the repo root.
# Expects PROJECT, DERIVED and BUNDLE to be set.

udid_of() {
    xcrun simctl list devices available -j | /usr/bin/python3 -I -c "
import json, sys
name = sys.argv[1]
# Several runtimes can have a device with the same name: prefer the booted one, whose pose
# (an iPad turned or an iPhone Duo opened in Device Hub) is the one to capture.
matches = [d for devices in json.load(sys.stdin)['devices'].values() for d in devices if d['name'] == name]
matches.sort(key=lambda d: d['state'] != 'Booted')
if matches:
    print(matches[0]['udid'])
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

build_watch() {
    xcodebuild build -quiet -project "$PROJECT" -scheme EmbalseWatch -configuration Debug \
        -destination 'generic/platform=watchOS Simulator' -derivedDataPath "$DERIVED" >/dev/null
}

# Sets the look for the next shots: light, dark, or large (light at the largest accessibility text size).
set_mode() {
    local udid="$1" mode="$2"
    case "$mode" in
        dark) xcrun simctl ui "$udid" appearance dark ;;
        *) xcrun simctl ui "$udid" appearance light ;;
    esac
    if [ "$mode" = large ]; then
        xcrun simctl ui "$udid" content_size accessibility-extra-extra-extra-large
    else
        xcrun simctl ui "$udid" content_size large
    fi
}

prepare_ios() {
    local udid="$1" app="${2:-$DERIVED/Build/Products/Debug-iphonesimulator/EmbalseSanJuan.app}"
    xcrun simctl install "$udid" "$app"
    # Apple's convention for marketing shots: full bars, full battery, 9:41.
    xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 \
        --cellularMode active --wifiMode active --wifiBars 3 2>/dev/null || true
    set_mode "$udid" light
    # The first launch after installing can take longer than shoot() waits, which gives a blank shot.
    xcrun simctl launch "$udid" "$BUNDLE" >/dev/null
    /bin/sleep 15
}

shoot() {
    local udid="$1" file="$2" display="$3"
    shift 3
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    # A busy simulator sometimes fails a launch with "No such process"; the second try works.
    # Spanish with Spain's region unless the caller asks for another language (CAPTURE_LANGUAGE=en).
    local language="${CAPTURE_LANGUAGE:-es}" region
    region="$([ "$language" = en ] && echo en_GB || echo es_ES)"
    set -- "$@" -AppleLanguages "($language)" -AppleLocale "$region"
    xcrun simctl launch "$udid" "$BUNDLE" "$@" >/dev/null 2>&1 || { /bin/sleep 5; xcrun simctl launch "$udid" "$BUNDLE" "$@" >/dev/null; }
    /bin/sleep 6
    if [ -n "$display" ]; then
        xcrun simctl io "$udid" screenshot --display="$display" "$file" 2>/dev/null
    else
        xcrun simctl io "$udid" screenshot "$file" 2>/dev/null
    fi
    printf '   %-34s %s\n' "$(basename "$file")" "$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/{printf "%s ", $2}')"
}
