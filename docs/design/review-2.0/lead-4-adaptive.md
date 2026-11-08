# 2.0 review · Lead 4 "Adaptativa": information architecture across sizes

Scope: how many sections, where each piece of content lives, and how one design scales from Watch to Mac and to Android tablets. I don't cover colour or type; other leads do.

## 1. Verdict

**Keep three sections. Fix how they are presented above compact width.** The three tabs are the right *count* and two of the three are the right *shape*. What's wrong is that iPad gets the iPhone design scaled up, and that some secondary content has no home on large screens.

What works:
- **iPhone Ahora** (`iphone-69/light-01-ahora.png`) answers the 3-second question in one look: 46,8 %, volume, "Estable · +0,19 hm³ en 24 h", source and time. It's the best first screen this app has had.
- **Este año** on iPad (`ipad-portrait/light-02-este-ano.png`) already has a sensible two-column layout: MITECO and the year chart on the left, SAIH history and the AEMET forecast on the right. The sources are never mixed.
- **El río** (`ipad-portrait/light-03-el-rio.png`): the three tanks ordered upstream to downstream are a good mental model, and each tank carries its own SAIH time.

What doesn't:
1. **iPad Ahora is broken as a layout** (`ipad-portrait/light-01-ahora.png`). About 52 % of the first viewport is pale sky. The figure sits bottom-left and the right two-thirds of the water is empty. The spec asks for "a band of at least 40 % with columns below" (DESIGN-2.0 › Formats). The code instead makes the header the full viewport height in every size class (`NowView.header … .frame(height: viewport − top)`), so the dashboard columns start below the fold. This is the owner's "not sure about the whole screen", and on iPad he's right.
2. **iPhone Ahora gives no hint that you can scroll.** Below the figure the water is empty down to the tab bar, so nothing says there are outflow, elevation, the 24 h curve and the weather underneath. A 3-second user never learns those exist.
3. **"Este año" is named for a third of its content.** It also holds the history since 1988 and the 7-day forecast. A user looking for "histórico" won't look under "this year".
4. **The water has three dialects.** There's the full-bleed water in Ahora, a card with dark text in the sky on the Burguillo page (`ipad-portrait/light-04-burguillo.png`), and B-style tanks in El río. San Juan exists twice, as the Ahora tab and as the middle tank, and tapping that tank opens a third presentation.
5. **Secondary content is hidden behind "⋯" on every size.** On iPad and Mac, Ficha (a reference sheet) and Avisos (a setting) belong in native places: an inspector and Settings. A pushed page on top of the tab stack isn't one.
6. **Android tablet is still on 1.0** (`android-tablet/light-01-ahora.png`). It's a card hero and two columns with no navigation suite. It doesn't block 2.0, but it's the size where parity matters most.

## 2. References and the pattern I take from each

The patterns below come from current shipping behaviour as I know it and from Apple's and Google's docs. The web search confirmed the platform APIs. It confirmed little about each app's layout, so these are patterns, not pixel claims.

| App | Pattern taken |
|---|---|
| **Apple Weather (iPad, Mac)** | **The condition background stays full-bleed, but the first viewport is a short header plus a grid of modules.** The sky is atmosphere, not empty space. Places live in a sidebar that you can hide. Tapping a module opens a detail sheet rather than a new tab. This is the model for regular Ahora. |
| **Apple Stocks (Mac, iPad)** | **A sidebar list whose items aren't equal.** The watchlist row is a small summary and the detail is rich. Burguillo and Picadas have much thinner data than San Juan, so they are rows, not peers of the whole app. |
| **Apple Home (iOS 18+)** | **A few tabs on iPhone and a sidebar with sections on iPad and Mac:** one `TabView`, with extra sidebar-only destinations. This is exactly what `.sidebarAdaptable` with `TabSection` provides. |
| **Flighty (iPad)** | **List and live detail side by side.** The live hero (map/water) stays visible while you browse lower-priority data. For El río on wide screens, the list is the chain and the detail is that reservoir. |
| **Google / Pixel Weather** | **One scroll of cards with a large hero, reflowing into columns when unfolded.** There's no tab bar at all for a single place. This is the reason to *question* tabs (see Risks). |
| **Apple Health / Fitness (iPad)** | **Summary first, then categories in a sidebar on iPad.** Rare settings sit in a profile sheet, not in the navigation. That is where Avisos and Propinas go. |
| **Material 3 canonical layouts** | **List-detail** for El río, **supporting pane** for Ahora at Expanded and above, and **`NavigationSuiteScaffold`** to switch between bar, rail and drawer by window class. |

## 3. Proposal

### Information architecture

Three sections, renamed, with the river as a *switcher* on large screens:

| Section | Compact (tab) | Content |
|---|---|---|
| **Ahora** | `drop.fill` | San Juan live: the water and figure, trend, source. Then the 24 h curve, elevation and level, outflow and Valmayor, and today's weather. |
| **Evolución** (was "Este año") | `chart.xyaxis.line` | A MITECO panel, the year-vs-last-year-vs-10-year chart, history (1 y and 5 y SAIH, since 1988 MITECO), and the AEMET forecast in its own panel. If the owner wants to keep "Este año", then "Histórico" must at least be a visible segment heading, not a buried card. |
| **El río** | `point.topleft.down.to.point.bottomright.curvepath` | The chain of three reservoirs and the basin rain. On regular widths it becomes a **sidebar section** with one row per reservoir. |

Secondary content stays out of the section count:
- **Ficha y fuentes** is an `.inspector` on regular widths. It's a sheet on compact (automatic), and the inspector's toggle sits in the toolbar as `info.circle`.
- **Avisos**
  - iPhone: in the "⋯" menu, opening a sheet.
  - iPad: a toolbar `bell` button opening a popover.
  - Mac: the `Settings` scene (⌘,).
  - Android: an icon in the top app bar.
- **Propinas and Sugerencias**
  - iPhone and iPad: in the "⋯" menu.
  - Mac: the app menu ("Apoyar la app…") and Help.
  - In every case they're never in the navigation.
- **Share** stays as the first toolbar button everywhere.

**Is "El río" a section or a switcher?** It's a section on compact and a switcher on regular. The tab-bar version stays as it is: a chain view plus pushed pages. In the sidebar the section expands to *Burguillo · San Juan · Picadas · Lluvia en la cuenca*. Choosing San Juan there selects Ahora, so there's one San Juan, not two. The implementation uses one `TabView`:
- `TabSection("El río")` holds the reservoir tabs, each with `.tabPlacement(.sidebarOnly)`.
- The plain "El río" tab gets `.defaultVisibility(.hidden, for: .sidebar)`.

The reservoir page reuses **Ahora's own water component** at reduced data, in place of the dark-text card, so the water has one dialect.

### Breakpoints

Navigation follows the platform size class. Column count and band height follow the **window's** width, measured with `onGeometryChange`, not the device. This is allowed under "size classes, never idiom" and matches the Android rule. The bands match Material 3 so both platforms break in the same places.

| Window width | Apple | Android (`WindowSizeClass`) | Navigation | Ahora layout |
|---|---|---|---|---|
| < 600 | compact (iPhone, Duo closed, iPad ⅓ split, narrow Stage Manager windows) | Compact | bottom tab bar / `NavigationBar` | Full-screen water, 1 column, first panel peeks |
| 600–839 | regular (iPad mini portrait 744, ½ splits, Duo open) | Medium | iPad: top tab bar, sidebar available. Android: `NavigationRail` | Band 45 %, **2 columns** |
| 840–1199 | regular (iPad 11″/13″ portrait, 11″ landscape 1180) | Expanded | top tab bar, sidebar toggle. Android: rail + list-detail | Band 40 %, **2 columns plus a supporting pane** or 3 columns from 1000 (the existing `DashboardColumns` threshold) |
| ≥ 1200 | regular (13″ landscape 1376, Stage Manager large, Mac) | Large / XL | **sidebar shown by default** (`defaultAdaptableTabBarPlacement(.sidebar)`). Android: wide rail or permanent drawer | Band 40 %, 3 columns capped at 1200, inspector beside |
| height < 500 | compact height (iPhone landscape, tabletop) | Compact height | unchanged | Water on the left, scrolling panels on the right |

### Wireframes

**Compact (iPhone 6.9″, 440 × 956 pt).** The design is today's, plus one change: the header is `viewport − 140 pt`, so the first glass panel peeks above the tab bar.
```
┌──────────────────────────┐
│ San Juan          ⇪  ⋯   │  large title + toolbar (glass)
│ Río Alberche · Madrid    │
│                          │  sky ≈ (100 − %) of the header
│ ~~~~~~~~~~~~~~~~~~~~~~~~ │  waterline at the real level
│ 46,8 %                   │  ≥ 88 pt, on water
│ 64,4 hm³ de 138 hm³      │
│ → Estable · +0,19 en 24h │
│ ◷ SAIH Tajo · 7 nov 13:00│
│┌────────────────────────┐│  ← peek (~110 pt): "Últimas 24 h" panel
││ Últimas 24 h  ╱╲__     ││     the eye learns there is more
│└────────────────────────┘│
│  [ Ahora | Evolución | El río ]  │  Liquid Glass tab bar
└──────────────────────────┘
```

**Regular (iPad 13″ landscape, 1376 × 1032 pt).**
```
┌────────────┬───────────────────────────────────────────────┬──────────┐
│ ◉ Ahora    │ San Juan                     ⇪ 🔔 ⓘ ⋯        │ Ficha    │
│ ◦ Evolución│ ┌───────────────────────────────────────────┐ │ (inspec- │
│ El río     │ │ sky                                       │ │  tor,    │
│  ▸ Burguil.│ │~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~│ │  closed  │
│  ▸ San Juan│ │ 46,8 %          64,4 / 138 hm³            │ │  by      │
│  ▸ Picadas │ │ 120 pt          → Estable · SAIH 13:00    │ │  default)│
│  ▸ Lluvia  │ └───────── band = 40 % of height ───────────┘ │          │
│            │ ┌──────────┐ ┌──────────┐ ┌──────────┐        │          │
│ 260 pt     │ │Últimas   │ │MITECO    │ │El río    │  deep  │ 320 pt   │
│ (hideable) │ │24 h,cota,│ │semana ·  │ │▮ ▮ ▮     │  water │          │
│            │ │caudal    │ │mini año  │ │3 tanks   │  bg    │          │
│            │ └──────────┘ └──────────┘ └──────────┘        │          │
└────────────┴───────────────────────────────────────────────┴──────────┘
```

**How the water survives on large screens.** The window is still all water, read top to bottom as *sky → surface → depth*:
- The **band** is the surface. Its waterline is at the real level *within the band*, and the figure follows rule 1.
- Below the band, the background **continues as the deep-water gradient**. The glass panels sit "underwater" with white text, so no text ever crosses the waterline.
- The sky is no longer two-thirds of the screen.

This is Apple Weather's full-bleed condition background with modules over it, with water in place of weather.

**iPad portrait (1032 pt) or Duo open.** The top tab bar replaces the sidebar. The band is 45 %, and there are two columns with the fold in the gap (existing `FoldGeometry`). In **book posture**, the left pane is Ahora's band plus details and the right pane is Evolución or El río. In **tabletop**, the water is in the top half and the panels and tab bar are in the bottom half.

**Future Mac window (default 1100 × 760, minimum 720 × 560).**
```
┌ ● ● ●  ┌────────────┐  San Juan          ⇪  🔔  ⓘ ┐
│ Ahora  │                                          │
│ Evoluc.│  band 40 % — water, 46,8 % at 96 pt      │
│ El río │~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~│
│  Burg. │  ┌────────┐ ┌────────┐ ┌────────┐        │
│  S.Juan│  │24 h    │ │MITECO  │ │El río  │        │
│  Picad.│  └────────┘ └────────┘ └────────┘        │
└────────┴──────────────────────────────────────────┘
```
The Mac has its own conventions:
- `.sidebarAdaptable` resolves to a sidebar with no toggle.
- Menu commands: ⌘1/2/3 switch sections, ⌘R refreshes and ⌥⌘I opens Ficha.
- Avisos lives in `Settings`.
- **No device tilt.** The wave becomes a slow idle animation that stops when the window is inactive.

**Watch.** Keep the spec's three vertical pages. Add a reservoir picker in the complication and widget configuration only, not a navigation level. The Watch has no IA beyond "now".

**Android.** Use `NavigationSuiteScaffold`:
- Bar below 600 dp, rail from 600 dp, and a wide rail or drawer at 1200 dp and above.
- **El río** is a `ListDetailPaneScaffold`: on Expanded the chain list is on the left and the reservoir is on the right.
- **Ahora** at Expanded and above is a `SupportingPaneScaffold`: the main pane is water plus details, and the supporting pane shows the Evolución summary.
- **Ficha** is a modal side sheet.

It should feel like Pixel Weather, not like a ported iPad layout.

## 4. Changes, ranked by impact

1. **Regular-width Ahora:** a 40–45 % band, deep water below, and panels in the first viewport. This fixes the iPad screenshot and the owner's doubt in one change, and it's what the spec already asks for.
2. **`.sidebarAdaptable` TabView with an "El río" `TabSection`** (reservoirs as sidebar-only tabs). The sidebar is shown by default from 1200 pt and on the Mac. This gives one San Juan and a native switcher on large screens.
3. **Ficha as an inspector, Avisos in a popover or Settings.** Rare content moves out of "⋯" on large screens.
4. **Peek on compact.** Shorten the header so the first panel shows.
5. **Rename "Este año" to "Evolución"**, or at least surface "Histórico".
6. **One water component**, reused by the reservoir pages.
7. **Android: `NavigationSuiteScaffold` plus list-detail** when it moves to 2.0.

**Keep:**
- Three sections.
- Full-screen water on compact.
- The toolbar for share.
- The SAIH/MITECO separation per panel.
- `DashboardColumns` and its fold logic.
- Widgets as they are.
- The Watch's three pages.

## 5. Risks: what an adversarial reviewer would attack

- **"Why tabs at all?"** Pixel Weather manages one place with one scroll. A single scroll (Ahora, then Evolución, then El río) would be simpler on iPhone. My answer: Evolución is long (three charts) and El río has its own detail pages, so a single scroll would be 6–8 screens long and would bury the river. But it's a fair challenge, and testing a two-tab variant (Ahora + El río, with Evolución folded into Ahora below the fold) would be cheap.
- **Sidebar for three items is overkill.** On 600–1199 the sidebar stays hidden by default. It only earns its place once the reservoir rows are in it. If the owner rejects the river-as-switcher idea, use a top tab bar everywhere and no sidebar.
- **Two ways to reach San Juan** (Ahora and the river row) could confuse people. The mitigation is that the row selects Ahora rather than pushing a page, but that's a non-standard selection rule and needs testing.
- **The band breaks "the screen is the reservoir".** On iPad the waterline is no longer to scale with the window height. A purist would say the metaphor is diluted. My counter is that a 13″ screen of sky is the real dilution: nobody reads it.
- **Width breakpoints inside a size class** could be read as going against the "size classes only" rule. They are window measurements, not device checks, and `DashboardColumns` already does this at 640 and 1000 pt.
- **`.sidebarAdaptable` quirks:** a nested `NavigationSplitView` causes a double sidebar button, and the sidebar can't start hidden on some iPadOS versions. Use stacks inside tabs, never split views, and verify each OS release with `capture-matrix.sh`.
- **Inspector width on 11″ landscape** (1180 − 260 − 320 ≈ 600 for content) forces the dashboard down to one column. The inspector must close the sidebar when it opens, or open only as an overlay below 1200.
