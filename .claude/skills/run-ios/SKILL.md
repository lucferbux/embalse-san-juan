---
name: run-ios
description: Build and run the iOS app in the simulator, and inspect its screens and widgets. Use when asked to run the app or check how it looks.
---

# Run the app

1. Generate the project and build:

   ```bash
   make generate
   xcodebuild build -quiet -project ios/EmbalseSanJuan.xcodeproj -scheme EmbalseSanJuan -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build/DerivedData
   ```

2. Open the simulator panel before launching, then launch `build/DerivedData/Build/Products/Debug-iphonesimulator/EmbalseSanJuan.app`.
3. Check all sections in light mode, dark mode and with large text.
4. For widgets, run `make widgets` and read the images in `build/widget-snapshots/`. To check a widget in place, add it from the simulator's home screen.
5. Check the offline state too: the last saved data and the stale warning should appear.

The app reads live data from Firestore. To test against recorded data, use the `snapshot.json` fixture in tests or previews.
