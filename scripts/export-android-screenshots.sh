#!/bin/bash
# Takes Google Play screenshots from a debug build on the running emulator, which opens screens from an intent extra.
# The sizes keep the 9:16 Play asks for on phones and the two-column layout on tablets. Output is in
# fastlane/metadata/android/es-ES/images, the layout supply uses.
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
: "${JAVA_HOME:=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export JAVA_HOME
OUT="fastlane/metadata/android/es-ES/images"
APP="com.lucferbux.embalsesanjuan"

(cd android && ./gradlew --quiet assembleDebug)
adb uninstall "$APP" >/dev/null 2>&1 || true
adb install -r android/app/build/outputs/apk/debug/app-debug.apk >/dev/null
adb shell cmd uimode night no

# A slow emulator shows "not responding" dialogs that would end up in the shots.
adb shell settings put global hide_error_dialogs 1

# Android's demo mode: full battery, no notifications, the same 9:41 as the iOS shots.
adb shell settings put global sysui_demo_allowed 1
demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
demo enter
demo clock -e hhmm 0941
demo battery -e level 100 -e plugged false
demo notifications -e visible false
demo network -e wifi show -e level 4 -e satellite hide

reset() { adb shell wm size reset; adb shell wm density reset; demo exit; }
trap reset EXIT

open() {
    adb shell am force-stop "$APP"
    adb shell am start -n "$APP/.MainActivity" ${1:+--es screen "$1"} >/dev/null
    /bin/sleep 7
}

scroll() {
    local height="$1" count="$2"
    for _ in $(seq "$count"); do
        adb shell input swipe 400 $((height * 8 / 10)) 400 $((height * 2 / 10)) 900
        /bin/sleep 1
    done
    /bin/sleep 2
}

shoot() {
    if adb shell dumpsys window | grep -q "Application Not Responding"; then
        echo "A not responding dialog is on screen: restart the emulator and try again." >&2
        exit 1
    fi
    adb exec-out screencap -p >"$1"
    printf '   %-40s %s\n' "$(basename "$1")" "$(sips -g pixelWidth -g pixelHeight "$1" | awk '/pixel/{printf "%s ", $2}')"
}

shoot_set() {
    local dir="$OUT/$1" width="$2" height="$3" density="$4" swipes="$5"
    echo "==> $1"
    mkdir -p "$dir"
    adb shell wm size "${width}x${height}"
    adb shell wm density "$density"
    /bin/sleep 4
    open; shoot "$dir/01-ahora.png"
    scroll "$height" "$swipes"; shoot "$dir/02-boletin.png"
    # On tablets, two columns fit the whole screen in one swipe, so a second one would repeat the shot.
    if [ "$1" = phoneScreenshots ]; then scroll "$height" "$swipes"; shoot "$dir/03-alberche.png"; fi
    open history; shoot "$dir/04-historico.png"
}

shoot_set phoneScreenshots 1080 1920 420 2
shoot_set sevenInchScreenshots 1200 1920 240 1
shoot_set tenInchScreenshots 1600 2560 320 1
