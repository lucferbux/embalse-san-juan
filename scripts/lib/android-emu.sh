# Emulator helpers shared by export-android-screenshots.sh and capture-matrix.sh. Source it from the repo root
# after installing the debug build. Expects APP to be set.

# A slow emulator shows "not responding" dialogs that would end up in the shots.
adb shell settings put global hide_error_dialogs 1

# Android's demo mode: full battery, no notifications, the same 9:41 as the iOS shots.
adb shell settings put global sysui_demo_allowed 1
demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
demo_start() {
    demo enter
    demo clock -e hhmm 0941
    demo battery -e level 100 -e plugged false
    demo notifications -e visible false
    demo network -e wifi show -e level 4 -e satellite hide
}

reset() { adb shell wm size reset; adb shell wm density reset; adb shell cmd uimode night no; adb shell settings put system font_scale 1.0; demo exit; }

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

