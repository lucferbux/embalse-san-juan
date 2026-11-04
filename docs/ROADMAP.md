# Roadmap

What could come after [1.0](SPEC-v1.md). Nothing here is committed: it's a list to choose from.

**Guiding rule:** keep it simple and elegant. A feature earns its place only if it helps answer "how much water is there?" better, or makes that answer easier to reach. Every idea below should pass that test, and some won't.

Estimates are working days for one person, including tests and store assets:
**S** under 1 day, **M** 1 to 3 days, **L** 4 to 10 days. Wall-clock waits, such as reviews, are noted apart.

## 1.1: finish the launch

Small things that complete 1.0 rather than extend it.

| Item | Size | Notes |
|---|---|---|
| Google Play production | S, plus 14 days wait | Closed test with at least 12 testers for 14 days, then request production. Mostly finding testers. |
| Framed store screenshots | S | Done in the repo: `make-creative-assets.swift` frames the raw shots. Upload them with the next version. |
| English | M | App strings with String Catalogs and Android resources, store listings and the web. Opens the App Store outside Spain to more people at little cost. |
| Siri and Shortcuts | S | An App Intent, "¿Cuánta agua hay en San Juan?", that answers with the percent and volume. Free reach on iOS, Spotlight included. |
| Accessibility pass | S | VoiceOver labels on every chart, Audio Graphs for the history, and checks at the largest text sizes. |
| Wear OS | M | A tile and a complication, reusing the Android data layer. |

## 1.2: small and useful

| Item | Size | Notes |
|---|---|---|
| Year comparison in history | M | This year, last year and the 10-year average as three curves on one chart. The clearest answer to "is this a good year?". |
| Control Center and Action button | S | An iOS control that shows the percent and opens the app. |
| Android tips | M | Google Play Billing, three consumables like iOS. Needs Data safety and privacy policy updates. |
| Share card | S | Share the "now" card as an image, with source and date, for chats and social media. |
| Web: live widget | S | An embeddable version of the landing's live figure for local news and town websites, with attribution. |

## 2.0: design, then features

2.0 is mainly a design release: the same content, presented more beautifully and more simply. Explore before building.

### Design exploration

| Item | Size | Notes |
|---|---|---|
| Full-screen water | M | The first screen *is* the reservoir: water fills the whole screen to the real level, the number sits on it, and it moves gently with the device (Core Motion on iOS, sensors on Android). Details move below the fold. |
| Fewer, calmer sections | M | Group the 7 sections into 3: *Ahora*, *Este año* (weekly bulletin, comparison and history) and *El río* (Alberche, weather, outflow). Less scrolling, the same data. |
| Liquid Glass and typography | S | Glass cards over the water on iOS 27, rounded SF for figures, and a consistent number style across app, widgets and web. |
| Seasonal palette | S | The water's colour shifts slightly with how full the reservoir is, from deep blue to a drier teal. Only if it stays readable and honest. |
| Prototypes | M | Two or three directions as SwiftUI previews and a TestFlight build for friends and family before choosing. |

### Features that fit the new design

| Item | Size | Notes |
|---|---|---|
| Notifications | L | Opt-in alerts when the reservoir crosses a threshold (for example 50 %) or the outflow changes sharply. The hard part is free delivery: the apps don't use the Firebase SDK, so this needs APNs and FCM over HTTP from GitHub Actions, or background refresh with local notifications, which iOS runs unreliably. Decide with an ADR first. |
| Live Activity | M | During a big release from the dam, a Live Activity and Dynamic Island with the outflow. Depends on notifications for the push updates. |
| Burguillo and Picadas pages | L | Tap a reservoir in the river section to see its own "now" and curve. Data is already collected. Risk: it dilutes the one-reservoir focus, so only as secondary pages. |
| Rain forecast | M | Expected rain in the basin from AEMET OpenData, clearly separate from measured rain. Needs an API key in GitHub secrets and a new source in `docs/DATA_SOURCES.md`. |

## Ideas parked

Kept here so they aren't proposed again without a new reason.

- **Accounts or favourites:** nothing to personalise with one reservoir.
- **Any reservoir in Spain:** a different, much larger product, and embalses.net already covers it.
- **Inflow figures:** there's no direct official source, and estimating them would break the "only official figures" rule.
- **Ads or analytics:** against the privacy promise.
- **Webcams or user photos:** moderation and rights problems for little value.
