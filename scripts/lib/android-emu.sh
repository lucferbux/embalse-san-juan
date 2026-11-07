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

# Waits until the app's window is in front and a capture of it is not a splash or a black frame, instead of a fixed
# pause: a busy emulator can take far longer than usual. uiautomator can't help: it never sees an idle tree while
# the hero's wave animates. Splash, blank and black frames compress to under 45 KB; the emptiest real screen, the suggestion form on a tablet, is about 65 KB.
wait_for_app() {
    local tries=0 probe
    probe="$(mktemp -t window).png"
    while [ "$tries" -lt 30 ]; do
        if adb shell dumpsys window | grep "mCurrentFocus" | grep -q "$APP/"; then
            adb exec-out screencap -p >"$probe"
            if [ "$(wc -c <"$probe")" -gt 55000 ]; then
                rm -f "$probe"
                /bin/sleep 2 # let the hero's first frame and the charts settle
                return 0
            fi
        fi
        tries=$((tries + 1))
        /bin/sleep 2
    done
    rm -f "$probe"
    echo "The app never showed its content: is the emulator responsive?" >&2
    return 1
}

open() {
    adb shell am force-stop "$APP"
    adb shell am start -n "$APP/.MainActivity" ${1:+--es screen "$1"} >/dev/null
    wait_for_app
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

