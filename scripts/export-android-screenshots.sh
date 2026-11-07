#!/bin/bash
# Takes Google Play screenshots from a debug build on the running emulator, which opens screens from an intent extra.
# The sizes keep the 9:16 Play asks for on phones and the two-column layout on tablets. Output is in
# fastlane/screenshots_raw/android. swift scripts/make-creative-assets.swift frames them into
# fastlane/metadata/android/es-ES/images, the layout supply uses.
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$PATH:$HOME/Library/Android/sdk/platform-tools"
: "${JAVA_HOME:=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export JAVA_HOME
OUT="fastlane/screenshots_raw/android"
APP="com.lucferbux.embalsesanjuan"

(cd android && ./gradlew --quiet assembleDebug)
adb uninstall "$APP" >/dev/null 2>&1 || true
adb install -r android/app/build/outputs/apk/debug/app-debug.apk >/dev/null
adb shell cmd uimode night no

# shellcheck source=lib/android-emu.sh
source scripts/lib/android-emu.sh
demo_start
trap reset EXIT

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
