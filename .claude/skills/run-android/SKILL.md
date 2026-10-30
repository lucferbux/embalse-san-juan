---
name: run-android
description: Build, run and inspect the Android app and its widget on the emulator. Use when asked to run, test or take screenshots of the Android version.
---

# Run the Android app

Commands need `JAVA_HOME` set to JDK 21 (`/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`) and `android/local.properties` pointing to the SDK (`sdk.dir=$HOME/Library/Android/sdk`, written out in full).

## Emulator

The AVD is called `Pixel`. On this Mac `XDG_CONFIG_HOME` moves it to `~/.config/.android/avd`, so the emulator needs that path:

```bash
ANDROID_AVD_HOME=~/.config/.android/avd ~/Library/Android/sdk/emulator/emulator -avd Pixel -no-window -no-audio -no-boot-anim
```

Leave out `-no-window` to see it. Then run `make run-android`.

## Look at it

- **Screenshot:** `adb exec-out screencap -p > shot.png`
- **Open a screen directly (debug builds):** `adb shell am start -n com.lucferbux.embalsesanjuan/.MainActivity --es screen history`. Also `about` and `suggestions`.
- **Dark mode:** `adb shell cmd uimode night yes`
- **Wide layout:** `adb shell wm size 1800x2200 && adb shell wm density 320`, and `wm size reset` and `wm density reset` afterwards.
- **Offline:** `adb shell svc wifi disable && adb shell svc data disable`
- **Widget:** long-press the home screen, Widgets, Browse, San Juan, then drag it. Resize it with its handles to see the three layouts.

## Before saying it works

- Check small, medium and large widgets, and light and dark.
- Test the release build too, because R8 can break JSON decoding: sign `app-release-unsigned.apk` with the debug keystore using `apksigner` and install it.
- A suggestion sent from the app reaches the real Firestore collection, so don't send them just to test.
