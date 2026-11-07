# Embalse San Juan 2.0: design

The specification for the 2.0 apps, widgets and web. It is direction **A · Superficie**, chosen on 7 November 2026, with three elements borrowed from B and C (see [DIRECTIONS-2.0.md](DIRECTIONS-2.0.md)). The requirements come from the 1.0 audits ([Apple](AUDIT-1.0-apple.md), [Android](AUDIT-1.0-android.md)); their finding IDs are cited in brackets.

Every format is checked with `scripts/capture-matrix.sh` and the `ux-adversary` reviewer before release. Nothing with a Blocker or Major finding ships.

## The idea

The screen is the reservoir. Water fills the window up to the real SAIH level, the number sits in it, and the rest of the app is glass over the water. One question, *how much water is there now?*, is answered in the first viewport of every format.

## Rules that hold everywhere

1. **Text never crosses the waterline.** Each text block sits wholly in the water (white) or wholly in the sky (`.primary` / `onSurface`), at least 12 pt/dp clear of the highest crest at any wave phase. No masking or double drawing (A1, H2). One placement function decides it from the water height, the crest amplitude and the measured block. When the water is too shallow for the block (low levels, or AX3 and above), the block moves to the sky in B's calm style: figure in `.primary`, no glass.
2. **One number style** (A2, A5, G6, H20):
   - percent with 1 decimal, SAIH volume with 1 decimal, MITECO volume with 0 (1 for the 10-year average when it isn't whole), elevation and level with 2;
   - a no-break space (U+00A0) before every unit, `%` included;
   - the real minus sign; Spanish separators in Spanish, English in English.
   - It is defined once per platform (`Format` in EmbalseKit, `Format.kt`, `landing.js`) and checked by the same table of cases in each platform's tests.
3. **The trend is a word, a direction and an amount:** "Estable · +0,12 hm³ en 24 h". The stability threshold is 0,2 hm³ in 24 h and is explained where "Estable" appears next to a non-zero amount (A4, G2). Small widgets and complications show the word, never an arrow alone.
4. **Every figure carries its source and time in its own block** (A3, A6, H12): "SAIH Tajo · 30 oct, 16:00". In "El río" each reservoir shows its own time.
5. **SAIH and MITECO never share a panel.** MITECO lives in its own panel, styled apart (a "semanal" badge) and headed "MITECO · semana del 27 oct", with its own current figure: "Esta semana 70 hm³ · Hace un año 75 hm³ · Media 10 años 57,5 hm³" (A2, A6, G3).
6. **Glass:**
   - **Chrome:** real Liquid Glass on iOS 27, only for the tab bar, toolbars and controls, on system components.
   - **Content panels:** a fixed translucent fill over the water, checked at 4.5:1 for white text against both the water's top colour and its gradient midpoint.
   - **Android:** Material 3 Expressive surfaces in the same role.
7. **Colour of the water** (A9, H8):
   - A fixed blue that follows how full the reservoir is: deeper when full, lighter teal when low.
   - It is the one hardcoded colour on Android, where Material You colours the chrome only.
   - The top stop is about 15 % darker than in the prototypes, so white text passes AA at every level from 8 to 97 %, in light, dark and Increase Contrast.
8. **Motion:**
   - The wave moves gently and the water tilts slightly with the device (Core Motion, Android sensors).
   - Everything stops with Reduce Motion or Remove animations, and after a few seconds idle on Android.
   - The static frame is just as readable.
9. **Accessibility:**
   - **Text size:** every screen is usable at the largest accessibility size (AX5, font scale 2.0). Rows stack label over value instead of breaking words (A3, H3), chips flow (H4), segmented labels never truncate (H6), and chart labels are measured (H5).
   - **Charts:** every chart has an Audio Graph descriptor (iOS) or a text alternative (TalkBack) and a one-line summary.
   - **Screen readers:** VoiceOver and TalkBack read one sentence per figure, with its source and time.
10. **Languages:** Spanish and English, with the system's language and region.

## Navigation and sections

Three sections, with system navigation (A5):

- **iOS:** a `TabView` with a Liquid Glass tab bar.
- **Android:** a `NavigationBar` on compact widths and a `NavigationRail` from medium up.

| Section | Content |
|---|---|
| **Ahora** | The water and the figure, the volume, the trend and the SAIH source. Below the fold, on glass: the last 24 hours, elevation and level, outflow to the river and the transfer to Valmayor (with source and time, H12), and the weather at the dam. |
| **Este año** | The MITECO panel (rule 5), then the year chart: this year, last year and the 10-year average by week, in distinct solid colours (blue, orange, grey dashed), with "hoy" marked and today as the last point (B1). Then the history (1 year and 5 years from SAIH daily, since 1988 from MITECO weekly, never mixed), with the minimum, maximum and mean including today and values above capacity explained (A7). Then the AEMET forecast, clearly separate from measured rain. |
| **El río** | Burguillo, San Juan and Picadas as B's mini tanks, each with its own level, percentage, volume and SAIH time. Tapping one opens its page: its own water, figure, 90-day surface and history. Then the basin rain gauges, with source and time. |

The ficha, sources, privacy, suggestions, tips, alerts settings and sharing are reached from a toolbar button in "Ahora", not from rows at the bottom of a list.

## Formats

### iPhone (compact) and iPhone Duo closed
- **Ahora:** the water fills the screen. The figure block is anchored to the waterline at `waterline + 24` (A10), not placed with spacers.
- **Phone width:** the percentage is at least 88 pt at the default size. Everything in rule 1's block is visible in the first viewport on a 375 pt phone.
- **Below the fold:** glass panels scroll over the water. The water stays put as the background.
- **Toolbar:** share, alerts and the ficha.

### iPad, iPhone Duo open, Android tablet and foldable (regular / medium and expanded)
- **Ahora:** a full-width band in the top part of the water, at least 40 % of the window, with the percentage at 120 pt/sp or more (D2, K2, A13). Below it, three balanced columns: *Ahora* details, *Este año* summary with its mini chart, *El río* tanks. No column ends more than 10 % above another.
- **Content margin:** the title, the water and the content share one, and content is capped at about 1200 pt/dp (N1, K1).
- **Other sections:** two-pane layouts. History has its chart at 50 % or more of the height, with the statistics beside it (D4, K3).
- **Folds:** the fold or hinge falls in a gap between columns, measured from `reservedRegions` (iOS 27.1) or `FoldingFeature` (Android), never from symmetry (E1, J2).
  - **Waterline:** one line at the same height across both halves.
  - **Book posture:** Ahora on the left; Este año or El río on the right, scrolling.
  - **Tabletop:** the water and the figure on top; sections and controls below.
- **Windows and input:**
  - Resizable windows and split screen follow size class at every width.
  - iPad has ⌘R and ⌘[.
  - Android tablets have keyboard, mouse and focus states.

### Apple Watch and Wear OS
- **Page 1:** the water and the figure, plus the volume, the trend word and "SAIH · 16:00" (A20, A21), with an `@ScaledMetric` figure (A23).
- **Page 2:** C's surface: the last 90 days drawn as the water's surface on a 0-to-capacity scale. It is labelled "hace 90 días · 83,3 hm³" and "hoy · 67,0 hm³", inside the water.
- **Page 3:** the main figures, with sources.
- **Complications** (circular, corner, rectangular, inline), with the same number style: "48,7 %", never "49".
- **Wear OS:**
  - **Tile first:** the water filling the round tile, with the figure, the trend word and the source.
  - **Complications:** ranged value, short text, long text and small image.
  - **Ambient mode:** a static outline.
  - **Fetching:** standalone REST, no Firebase SDK.

### Widgets (iOS Home Screen, StandBy and Lock Screen; Android Glance)
- **One full-bleed surface with white text,** as in 1.0 (`CLAUDE.md`). No light panels.
- **Every family shows the percentage, volume, trend word and a dated source** (A25, A26):
  - **Small:** the percentage, then "67,0 hm³ · Estable", then "SAIH 16:00".
  - **Medium:** adds the MITECO panel, styled apart.
  - **Large:** C's labelled 90-day surface instead of a floating sparkline (A24).
- **Stale data:** the full date always shows and has the highest layout priority (G1).
- **Rendering modes:**
  - Tinted, clear and StandBy have their own designs.
  - Lock Screen and complications use the same figures and style.
- **Configurable** (`AppIntentConfiguration`, a Glance configuration activity): San Juan, Burguillo or Picadas.
- **Android extras:** a 4×1 strip and a 4×2 river widget.

### Web
- The landing and the embeddable widget use the same water, number style and source line.

## New features and where they live

| Feature | iOS | Android |
|---|---|---|
| Year comparison | Este año | Este año |
| Burguillo and Picadas pages | El río | El río |
| AEMET forecast | Este año, apart from measured rain | same |
| Share card | toolbar: an image of the Ahora block with source and date (`ImageRenderer` + `ShareLink`) | `ACTION_SEND` of a bitmap |
| Siri and Shortcuts | App Intent "¿Cuánta agua hay en San Juan?", `AppShortcutsProvider`, Spotlight | static app shortcuts |
| Control Center and Action button | `ControlWidget` | — |
| Local alerts | `BGAppRefreshTask` + local notifications; opt-in threshold and big-outflow alerts (ADR 3) | WorkManager hourly + notification channel; same settings |
| Tips | StoreKit (existing) | Play Billing, the same three product ids |

## Verification

- `make design` re-renders the chosen direction at 8, 30, 48,7, 62 and 97 %, in light, dark and AX5, for every format, before code moves into `Views/`.
- `scripts/capture-matrix.sh`, including `--duo-inner`, real fold postures on a foldable AVD, Glance widget renders and Wear, then the `ux-adversary` review, before release.
