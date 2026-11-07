# 3. Local notifications, without push

**Status:** Accepted, 7 November 2026.

## Context

2.0 adds alerts: the reservoir crossing a level the user chose, a big change in a day, rain forecast. Push notifications would need device tokens, a server that holds them and sends to APNs and FCM, and the Blaze plan or another paid service. The privacy policy (`firebase/site/privacy.html`) and the store answers promise that the apps collect nothing that identifies a person or a device, apart from optional anonymous suggestions.

## Decision

Alerts are **local notifications**. Each app checks the public snapshot during its own background refresh, compares it with the thresholds stored on the device, and schedules the notification itself. The backend stays as it is: it publishes the same public documents for everyone and knows nothing about who reads them.

- **Android:** WorkManager runs hourly, the same worker that already refreshes the widget. It is reliable enough to promise "within about an hour".
- **iOS:** `BGAppRefreshTask` is best effort. The system decides when to run it, based on how often the app is used, battery and network, and may skip it for hours. The app must say alerts can be late, and never promise a time.
- **No Live Activity updated live.** Updating one remotely needs push (ActivityKit push tokens). A Live Activity started locally could only change when the app runs, which would make it look live when it is not.

## Consequences

- No device tokens, accounts or new data collected: the privacy promise and the App Privacy and Data safety answers stay true.
- No new backend, cost or secret.
- On iOS an alert can arrive hours late, or not until the app is opened. The app must say so next to the alert settings.
- Thresholds live on each device and don't sync between devices.
- If real-time alerts become a must, push would need its own ADR, a privacy policy update and new store answers.
