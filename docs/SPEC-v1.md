# Embalse San Juan 1.0: specification

What version 1.0 does, as shipped on the App Store on 4 November 2026 and on Google Play's internal test.
It describes behaviour, not code: [CLAUDE.md](../CLAUDE.md) covers how it's built, and
[DATA_SOURCES.md](DATA_SOURCES.md) covers the sources in detail.

## Product

One question, answered at a glance: **how much water is in the San Juan reservoir right now?**
For people who live near, visit or follow the reservoir on the Alberche river in Madrid.

Principles:

- **Simple:** one screen with everything, in a fixed order. No settings, no accounts, no onboarding.
- **Trustworthy:** only official sources. Every figure shows its source and date, and SAIH and MITECO figures are never mixed.
- **Native:** system components on each platform, dark mode, Dynamic Type and Material You.
- **Private:** no accounts, ads, analytics or tracking.
- **Free to run:** the whole backend fits in free tiers.

## Platforms

| Platform | Minimum | Distribution |
|---|---|---|
| iPhone, iPad, iPhone Duo | iOS 27.0 | App Store, Spain and all regions |
| Apple Watch | watchOS 27 | Bundled with the iPhone app, works on its own |
| Android phones and tablets | Android 8 (API 26) | Google Play, internal test. Production needs a closed test first |

The interface is in Spanish only.

## Data

| Source | Frequency | Provides |
|---|---|---|
| SAIH Tajo, station `E_19` | Hourly | Volume, percent, elevation, level, river outflow, transfer to Valmayor, weather at the dam |
| SAIH Tajo, `E_17` and `E_20` | Hourly | Burguillo and Picadas, up and downstream |
| SAIH Tajo rain gauges | Hourly | Rain in the Alberche basin |
| MITECO Boletín Hidrológico | Weekly | Weekly volume, last year, 10-year average and the series since 1988 |

- **Freshness:** a figure older than 6 hours is marked as stale in the app and widgets.
- **Validation:** before publishing, the backend checks ranges (percent 0 to 100, volume between 0 and capacity, no future dates). If a check fails, nothing is written and the last good data stays.
- **Provisional:** both sources publish provisional data, and the app says so.

## App: main screen

A single scrolling screen. On compact widths it's a list; on regular widths (iPad, iPhone Duo open, Android from 720 dp) it's two columns of cards.

1. **Now:** water drawn at the real level, with percent, volume over capacity, and the 24-hour trend (rising, steady or falling, in hm³). Source, time and "dato provisional" underneath.
2. **Real time:** the last 24 hours as a chart, elevation, level, and a list of the latest hourly readings.
3. **Outflow:** water released to the river and transferred to Valmayor, in m³/s.
4. **Weekly bulletin (MITECO):** weekly volume and percent, weekly change, capacity, the same week last year and the 10-year average, with a note that it's a different measurement from the real-time one.
5. **Weather at the dam:** temperature, wind and direction, humidity, pressure, solar radiation, rain in the last hour and 24 hours.
6. **Alberche river:** Burguillo, San Juan and Picadas in river order, each with percent and volume, and the basin's rain gauges.
7. **Links:** history, details and sources, suggestions and tips.

## App: other screens

- **History:** ranges of 1 year, 5 years and since 1988. The first two use SAIH's daily values, the last MITECO's weekly series. Each shows a chart with the capacity line and the minimum, maximum and mean for the period. Loaded only when opened.
- **Details and sources:** river, basin, municipality, dam type, year built, surface and uses. Sources with links, the "not affiliated" notice, privacy policy and support.
- **Suggestions:** an anonymous form, 3 to 1,000 characters. It asks not to include personal data. Messages go to Firestore, which clients can write but never read.
- **Tips (iOS and iPadOS only):** three consumable in-app purchases (small, medium, large, from 0.99 €) that unlock nothing.

## Widgets

All widgets draw the water at the real level on one full-bleed surface with white text, and update hourly.

| Platform | Families | Shows |
|---|---|---|
| iOS Home Screen and StandBy | Small, medium, large, extra large (iPad) | Percent, volume and trend; medium adds the 7-day curve, the bulletin and last year; large adds 90 days and outflow |
| iOS Lock Screen | Circular, rectangular, inline | Percent, volume and a level bar |
| watchOS | Circular, corner, rectangular, inline | The same, as complications |
| Android | One resizable Glance widget | Small, medium and large layouts by size |

They support tinted and clear modes on iOS. Tapping opens the app.

## Apple Watch app

Three pages: now (percent and water), the curve for the last 90 days, and the main figures. It fetches on its own, without the iPhone.

## Offline and errors

- The last good snapshot is cached (in the App Group on iOS, shared by the app and widgets). Without network, the app and widgets show it with its date and the stale notice when it applies.
- With no cache and no network, the app shows an error with a retry button.

## Backend

- GitHub Actions jobs: hourly ingest, weekly ingest (Tuesday and Wednesday, in case MITECO is late), backfill, live check and CI.
- A Google Apps Script trigger starts the jobs every hour and emails the owner if data is over 3 hours old ([ADR 2](decisions/0002-external-scheduler.md)).
- Firestore (Spark plan): `public/snapshot` and `public/history` readable by anyone; archives and suggestions not readable by clients.
- Firebase Hosting: the landing page, privacy policy and support page at https://embalse-san-juan.web.app.

## Privacy

The app sends nothing about the user. The only data that leaves the device is the optional suggestion text and, on iOS, Apple's handling of tips. Declared as such in App Privacy, Google Play's Data safety and `firebase/site/privacy.html`.

## Out of scope for 1.0

- Notifications and alerts.
- Other reservoirs as main screens.
- Languages other than Spanish.
- Tips on Android.
- Rain forecasts and inflow figures: there's no direct official source for inflows.
