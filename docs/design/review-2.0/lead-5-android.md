# 2.0 review, lead 5: Android (Material 3 Expressive)

Scope: the native Android 2.0 design (phone, foldable, tablet, desktop windowing, Glance, Wear OS) and whether Android should copy the iOS full-screen water. Inputs: `DESIGN-2.0.md`, `DIRECTIONS-2.0.md`, both 1.0 audits, `android/app/src/main/java/.../ui/*.kt`, `widget/ReservoirWidget.kt`, and the captures in `build/ux-review/` and `build/design/`.

## 1. Verdict

**Keep the water, but on Android it should not take over the whole screen. Put it in a large expressive container that collapses as you scroll.** The water is the right identity, and Android 1.0 already found the right form for it by accident: a shaped water card (`android-phone/light-01-ahora.png`). What 1.0 got wrong is everything around that card.

**On iOS 2.0, what works:**
- The waterline as data reads instantly (`iphone-69/light-01-ahora.png`).
- "Este año" is the best screen in the build: the MITECO panel stands apart, it has a three-series chart and a "hoy" marker (`iphone-69/light-02-este-ano.png`).
- The Burguillo page puts its water in a rounded card with the figure in the sky, and it is the most balanced screen of all (`iphone-69/light-04-burguillo.png`). It is also the model I take for Android.

**On iOS 2.0, what doesn't:**
- **iPhone first viewport.** About 45 % of `iphone-69/light-01-ahora.png` is pale sky with only a title in it, and nothing below the figure hints at more. At 3 seconds per visit that is acceptable. As the only entry point to an app that wants to stay "very visual", it is thin.
- **Large text.** `iphone-69/large-01-ahora.png` truncates "64,4 hm³ de 1…" and "SAIH Tajo · 7 no…", so the source and date are cut. That breaks rules 1, 4 and 9 of the spec at once.
- **iPad.** `ipad-portrait/light-01-ahora.png` puts the figure in the lower-left quadrant, and roughly 85 % of the viewport carries no information. The build doesn't follow the spec's own regular-width layout: a band of at least 40 % with three columns under it. `ipad-portrait/light-03-el-rio.png` leaves the lower half empty too.
- **The core problem.** Full-screen water scales with the window, but the information doesn't. The bigger the screen, the emptier it gets.

**On Android 1.0** (still the 1.0 design), the problems are known from H2, H8, H9 and H10 in the Android audit:
- The text is drawn twice and split by the wave.
- The water is lavender, because it takes the dynamic `primary`.
- The layout switches on `screenWidthDp >= 720`.
- A staggered grid shuffles SAIH and MITECO side by side (`android-tablet/dark-01-ahora.png`).
- There is no navigation at all, only links at the bottom.

## 2. References

| App | Pattern I take |
|---|---|
| **Fitbit (M3 Expressive redesign, 2025–26)** | The key stats sit on a coloured background layer, and a sheet of cards rises over it and takes the whole screen as you scroll ([9to5Google](https://9to5google.com/2025/11/09/fitbit-material-3-expressive/)). Here, the water is that background layer and the panels are the sheet. Fitbit also keeps fixed per-section colours rather than dynamic colour, which supports keeping the water's hue fixed. |
| **Pixel Weather (Expressive)** | Taller, pill-shaped cards and fewer of them, trading density for scannability. The search button became a rounded-square FAB, and the widgets are native ([9to5Google](https://9to5google.com/2025/08/25/pixel-weather-expressive-redesign/)). I take one big shaped hero over a short list of large tiles. |
| **Google Clock (Expressive, 2025)** | The decorative ring is gone, the buttons are large text buttons, and lap times are cards ([9to5Google](https://9to5google.com/2025/08/27/google-clock-material-3-expressive-redesign/)). I take this as permission to drop ornament and let shape and size carry the hierarchy. |
| **Google Finance (Android app, 2026)** | A floating toolbar over content for actions, instead of a crowded top bar ([9to5Google](https://9to5google.com/2026/06/25/google-finance-android-app/)). I use it for the time range on "Este año" and history (1 year, 5 years, since 1988), as Fitbit does for D/W/M/Y. |
| **Material 3 Adaptive 1.2** | `NavigationSuiteScaffold` switches between a bar and a rail at runtime. `SupportingPaneScaffold` and `ListDetailPaneScaffold` now *reflow* (the second pane goes beside the first, or under it) and *levitate* ([Android Developers](https://developer.android.com/blog/posts/material-3-adaptive-1-2-0-is-stable?hl=en)). This gives the regular-width layouts without hand-written breakpoints. |
| **Wear OS M3 Expressive** | The 3-slot tile `PrimaryLayout`, the edge-hugging bottom button, and dynamic colour in tiles ([Android Developers Blog](https://android-developers.googleblog.com/2025/08/introducing-material-3-expressive-for-wear-os.html)). |
| **Breezy Weather / Overmorrow (indie, Compose)** | Proof that a data-dense weather app can be fully Material You and still carry a strong, non-wallpaper data colour. Breezy also shows that a dozen widget sizes is what Android users expect. |

## 3. Proposal

### Information architecture: the same three sections as iOS, Android chrome

| Destination (Material Symbol, filled when selected) | Content |
|---|---|
| **Ahora** (`water_drop`) | Water pane: figure, volume, trend, SAIH source. Sheet: last 48 h / 7 d chart, elevation and level, outflow to the river and the transfer (source and time), weather at the dam. |
| **Este año** (`calendar_month`) | MITECO panel ("semanal" badge, week date). Year chart (this year, last year, 10-year average, "hoy"). History, with the range in a floating toolbar: 1 year and 5 years from SAIH, since 1988 from MITECO, never on one chart. AEMET forecast in its own card. |
| **El río** (`water`) | Three mini-water tiles (Burguillo → San Juan → Picadas), each with its own percentage, volume and SAIH time. Tapping one opens its detail page (list-detail). Below them, the rain gauges. |

The overflow menu in the top app bar holds: the ficha and sources, alerts, suggestions, tips and privacy. Share is an icon action. There are no rows at the bottom of a list and no fourth tab: settings and support aren't a destination people choose at a glance.

### The water on Android: a collapsing water pane

- **Shape.** A `Surface` with the extra-large shape (28 dp) that holds sky and water, with the level drawn as a true fraction of the pane's height.
- **Sky.** The sky is `surfaceContainerLow`, taken from the dynamic scheme, so the pane belongs to the user's Material You theme.
- **Water.** The water is the fixed hue: harmonised water blue at HCT tone 30–40, with white text (audit H8).
- **Figure.** The number uses `displayLarge` emphasized, set in Roboto Flex with tabular figures. It is placed **wholly in the water, or wholly in the sky** by one placement function (rule 1). That replaces the double-clipped `WaterHero`.
- **Scroll.** As the sheet scrolls, the pane collapses smoothly, like a flexible top app bar, into a 72 dp *water strip* pinned under the status bar. The strip reads "46,8 % · Estable", and the level is still drawn as a proportion. The water never leaves the screen; it just gets out of the way.
- **Motion.**
  - The water rises to its level on launch, using the *effects* spring of `MotionScheme.expressive()`. That spring doesn't overshoot, so the water never shows more than the real level.
  - The wave pauses after 10 s, and with Remove animations.
  - Pull to refresh uses the Expressive `ContainedLoadingIndicator`, inside the water.

### Compact (phone, 411 × 914 dp; also a closed foldable)

```
┌──────────────────────────────┐
│ San Juan            ⤴  ⋮     │  TopAppBar on sky (title + subtitle "Río Alberche")
│╭────────────────────────────╮│
││          (sky)             ││
││                            ││  water pane, about 55 % of height,
││~~~~~~~~~~~~~~~~~~~~~~~~~~~~││  inset 8 dp, 28 dp corners
││ 46,8 %                     ││  displayLarge emphasized, about 96 sp
││ 64,4 hm³ de 138 hm³        ││
││ → Estable · +0,19 hm³ 24 h ││
││ ◷ SAIH Tajo · 7 nov, 13:00 ││
│╰────────────────────────────╯│
│╭─────────────╮╭─────────────╮│  sheet peeks: two tiles, about 14 %
││Salida 1,08  ││48 h ▁▂▃▅▆▅  ││  (the outflow carries its own source)
│╰─────────────╯╰─────────────╯│
│ ◉Ahora   ○Este año   ○El río │  short NavigationBar
└──────────────────────────────┘
```

At or below 25 %, or at font scale 1.5 and above, the block sits in the sky and the pane keeps its height, so the low water is visible as low.

### Medium and expanded (unfolded foldable 841 × 701, tablet 1280 × 800)

`NavigationSuiteScaffold` gives a rail. Ahora uses a `SupportingPaneScaffold`:

```
┌──┬────────────────────────┬─────────────────────────────────┐
│≡ │╭──────────────────────╮│ Últimas 48 h          SAIH 13:00│
│◉ ││ (sky)                ││ ▁▂▃▄▅▆▅▅▄  (chart, about 40 %)  │
│○ ││~~~~~~~~~~~~~~~~~~~~~~││─────────────────────────────────│
│○ ││ 46,8 %   (120 sp)    ││ Cota 565,44 m │ Salida 1,08 m³/s│
│  ││ 64,4 hm³ · Estable   ││ Nivel 40,18 m │ Trasvase 5,73   │
│  ││ SAIH Tajo · 13:00    ││─────────────────────────────────│
│  │╰──────────────────────╯│ Tiempo en la presa · SAIH 13:00 │
└──┴────────────────────────┴─────────────────────────────────┘
 rail   water pane, about 40 %   supporting pane, about 60 %, scrolls
```

- **Water pane.** It is full height and pinned. It never scrolls away on wide screens, which is the whole point of having width.
- **Content width.** Capped at 1200 dp.
- **Este año.** The chart pane is at least 50 % of the height, with the statistics and MITECO in the supporting pane. The floating range toolbar sits over the chart.
- **El río.** `ListDetailPaneScaffold`: the three tiles on the left, and the selected reservoir's water and 90-day surface on the right.
- **Book posture.** The fold falls exactly between the panes, measured from `FoldingFeature`, with the water on the left.
- **Tabletop posture.** The water pane takes the top half, and the sheet and navigation the bottom half. The figure stays above the hinge.
- **Large width (1200 dp and up).** The supporting pane splits into two columns. There are never three columns that end at different heights.

### Desktop window (Android desktop windowing / ChromeOS; the Mac should match this shape)

```
┌ Embalse San Juan ─────────────────────────────────── ─ □ × ┐
│ ≡  Ahora  Este año  El río                      ⟳  ⤴  ⋮    │
├─────────────────────┬──────────────────────┬───────────────┤
│ (sky)               │ Este año (MITECO)    │ El río        │
│~~~~~~~~~~~~~~~~~~~~~│ semana del 3 nov     │ ▭35,8 ▭46,8   │
│ 46,8 %              │ 65 · 72 · 56,9 hm³   │ ▭66,9 %       │
│ 64,4 hm³ · Estable  │ ╱╲__╱‾‾╲_  (chart)   │ Lluvia 24 h   │
│ SAIH · 13:00        │                      │               │
│ 48 h ▁▂▃▅▆▅         │                      │               │
└─────────────────────┴──────────────────────┴───────────────┘
   about 36 %              about 38 %             about 26 %
```

Above about 1400 dp the three destinations are shown *at once* as summary panes. Each pane header opens its full destination. A resizable window falls back to the expanded layout, using the window size class, never the device. Ctrl+R refreshes.

### Glance widgets and Wear OS

- **Glance.** Every widget is one full-bleed water bitmap with white text, using `SizeMode.Responsive`.
  - 2×2: percentage, "64,4 hm³ · Estable", "SAIH 13:00".
  - 4×1 strip.
  - 4×2: adds the MITECO panel, with its own date.
  - 4×2 river: three mini waters.
  - 4×4: the 90-day surface.
  - A configuration activity picks the reservoir. Generated previews (Android 15+) come from the fixture.
- **Wear OS.**
  - **Tile first:** the round water bitmap with the figure, the trend word and "SAIH · 13:00", plus an edge-hugging "Actualizar" button.
  - **Complications:** `RANGED_VALUE` (the percentage), plus short text and long text.
  - **App:** the water page, then the 90-day surface, then the figures with sources.
  - **Ambient:** an outline only.

## 4. Changes vs today, ranked by impact

1. **Navigation.** Replace the single staggered dashboard with three destinations in `NavigationSuiteScaffold`. This fixes the SAIH/MITECO adjacency (H10), the hidden content and the unstable order in one move.
2. **A new water pane.** One text placement and a fixed water hue fix H2 and H8, the two things that make 1.0 look broken. The pane collapses into a water strip.
3. **Adaptive scaffolds.** `currentWindowAdaptiveInfo()`, the supporting-pane, list-detail and fold-aware layouts replace the `720` check (H9, J1–J3, K1–K3).
4. **Glance families and their configuration** (L1–L5).
5. **Expressive polish.**
   - Emphasized type and tabular figures.
   - A floating range toolbar.
   - `ContainedLoadingIndicator`.
   - Material Symbols in place of `Icons.Filled.Thunderstorm` for drizzle (H22).
   - A short navigation bar.
6. **Wear OS:** tile and complications first, then the app.

**What to keep:**
- The 1.0 instinct of a shaped water card.
- The source footers on every block.
- `Format.kt`.
- Pull to refresh, plus an explicit refresh action.
- Dynamic colour for all chrome.
- The fixed-hue exception, which is documented once in `CLAUDE.md`.

## 5. Risks: what an adversarial reviewer would attack

- **"A card is less bold than iOS. The platforms diverge."** That is intended: both platforms share the IA, the figures, the number style and the water metaphor, not the layout. If iOS adopts the Burguillo-style card on regular widths, the gap closes. If the owner wants full bleed on phones, the pane can grow to edge-to-edge at 0 dp inset with no other change.
- **The collapsing pane over-animates.** Height changes that move with scroll are cheap, but the wave, the springs and the scroll together could feel busy. Freeze the wave while scrolling.
- **The water hue fights some wallpapers.** A harmonised blue on a red theme can look foreign. Test with blue, green, red and grey wallpapers and at medium and high contrast. Accept that the water is data, not decoration.
- **Expressive springs and data.** Any overshoot on the fill, or on a chart, would misstate a level. Use only the effects spring for data, and keep spatial springs for chrome.
- **The 1400 dp summary layout is a fourth layout to maintain.** If it slips, expanded with two panes is acceptable.
- **Glance can't animate or draw paths.** The widget water is a bitmap re-rendered on every update, which costs memory on 4×4 widgets with many instances. Cache it per level and size.
- **Unverified.** Real fold postures and a Wear capture are still missing from `capture-matrix.sh`. Until they exist, this design is reasoned, not seen.
