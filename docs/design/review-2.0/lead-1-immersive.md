# Lead 1 · Inmersiva: keep the water, change how it's used

Reviewer: design lead "Inmersiva". Date: 2026-11-08.
Thesis under test: the full-screen water stays as the signature, but it changes from *a poster you have to scroll
past* to *a world the content floats in*. That's the model of Apple Weather, Mercury and Carrot.

**Verdict: keep the water, but not the way 2.0 uses it.** The owner's unease is right, and it has three concrete
causes. None of them is "full-bleed is wrong":

1. **The first viewport is a poster with nothing to read.** `NowView` makes the header exactly one viewport tall
   (`.frame(height: viewport - safeAreaInsets.top)`), so nothing peeks. On `iphone-69/light-01-ahora.png` about 45 %
   of the screen is empty pale sky and 25 % is empty water under the source line. The screen gives no cue that there
   is more below.
2. **The water is only on one of three tabs.** `light-02-este-ano.png` and `light-03-el-rio.png` are plain
   grouped-background lists. The signature disappears as soon as you leave "Ahora", so the water reads as a splash
   screen, not as the app's identity.
3. **It doesn't scale.** `ipad-portrait/light-01-ahora.png` is a pale void with a figure in the bottom-left corner.
   The prototype `A-superficie/ipad-landscape-light.png` already showed the fix (content on the water to the right)
   and the build dropped it.

What works and must stay: the figure block itself (one white block, volume, trend word, dated SAIH source, all in
the water). The level-true waterline. The dark mode (`dark-01-ahora.png` is the best screen in the build). The
widgets (`widget-snapshots/medium-light.png`), which show the idea working when the whole surface is "water-world"
and the sky is dark, not a white void. Also the MITECO panel and the year chart colours.

There are also two bugs in the current hero:

- At AX sizes (`large-01-ahora.png`) the volume and source truncate ("64,4 hm³ de 1…", "SAIH Tajo · 7 no…") and the
  source line runs under the tab bar.
- On light water the tab bar's labels are dark on mid-blue glass, which is low contrast.

## References

| App | Pattern taken |
|---|---|
| **Apple Weather** (iOS/iPadOS/macOS) | The condition background is permanent behind *every* module. The hero is about the top 35–40 % and the hourly module is visible in the first viewport. On scroll the hero compresses into a one-line header ("Madrid · 18° Nublado"). Modules are dark translucent cards with white text whatever the system appearance. Tapping a module opens a detail with the full chart. In iOS 27 it adds mini charts on the main screen and puts the hero on the left in landscape, with cards on the right ([iDropNews](https://www.idropnews.com/?p=265491)). On iPad and Mac a location sidebar sits beside the same page. |
| **Mercury Weather** | One gradient that encodes a condition (temperature or cloud) and runs the same on iPhone, iPad and Mac. On iPad the tiles spread so everything is seen at once, with an expandable sidebar of places. On the Mac it's the iPad layout plus an optional menu bar item ([MacStories](https://www.macstories.net/reviews/mercury-weather-a-crystal-clear-design-for-every-apple-device/)). |
| **CARROT Weather 5.8** | On iPad, up to three columns of modules turn the screen into a "weather station", with a single column in narrow Split View ([MacStories](https://www.macstories.net/reviews/carrot-weather-5-8-a-beautiful-new-ipad-layout-lots-of-lock-screen-widgets-and-more/)). Module order is fixed by priority, from glance to browse. |
| **Flighty** | Dense data kept calm: one line per fact, the essentials first, detail on tap ([ADA 2023](https://www.traveldailynews.com/technology/flighty-wins-apple-design-award/)). Its live map-plus-card screen is the model for a fixed visual with content over it. |
| **Apple Maps / Find My** | A fixed full-bleed visual with a glass sheet at detents, so the visual is never fully covered and always peeks. |
| **iOS 26/27 Liquid Glass** | Scroll edge effects soften the content under the system bars, so content can scroll under the tab bar over a busy background without custom tinting. Glass stays for chrome; content cards use their own fill ([summary](https://acorn.firefox.com/latest/mobile/patterns/i-os-26-and-liquid-glass-w2oH48nk)). |

The key difference from Weather is that **our background is data**: the waterline *is* the level. So the water can't
be decoration that modules freely cover. It needs rules (below).

## Proposal

### Information architecture: two sections plus a menu

| Section | What it is | Content |
|---|---|---|
| **San Juan** (the reservoir page; Burguillo and Picadas use the same template) | One page over the water, with modules from glance to browse | 1 Hero (SAIH figure, volume, trend, source) · 2 *Últimas 48 h / 7 días* (SAIH chart) · 3 *En la presa* (elevation, outflow, transfer; SAIH) · 4 *MITECO semanal* (its own style and badge) · 5 *Este año, el pasado y la media* (MITECO mini chart; tap opens the full chart) · 6 *Histórico* (1 and 5 years from SAIH, since 1988 from MITECO; tap opens the detail with statistics) · 7 *Lluvia en la cuenca* (SAIH gauges) · 8 *Previsión* (AEMET, a separate module, never next to rain) |
| **El río** | The chain from upstream to downstream, and the way to switch reservoir | B's three tanks, each with its own SAIH time. Tapping one opens that reservoir's page. On regular widths this *is* the sidebar. |
| Menu (toolbar `…`) | Secondary | Ficha y fuentes, Avisos, Sugerencias, Propinas, Compartir |

"Este año" stops being a tab. Its content needs the water as much as "Ahora" does, and it is the natural *browse*
continuation of the glance. Three tabs where two have no identity is worse than two where both do. Technically this
is a `TabView` with `.tabViewStyle(.sidebarAdaptable)`: two tabs on compact width, a sidebar on regular width and on
Mac.

### Water rules (what makes it "fixed")

- **W1 · Water everywhere.** The water background (at the reservoir's real level) is behind every reservoir page
  and "El río". Modules are cards with a fixed dark-water translucent fill and white text, checked at 4.5:1 over
  both the sky and the water. The reservoir pages are always "water-world", like Weather and the widgets. The
  system's light or dark mode changes only the sky (pale day sky or night sky), never the cards.
- **W2 · Peek rule.** Content starts at `max(figureBlockBottom + 24, 0.55 × viewport)`, capped at
  `viewport − 140 pt`. A module title and the top of the 48 h chart are always visible in the first viewport.
- **W3 · Collapse, don't cover.** On scroll the hero shrinks into an inline header, "San Juan · 46,8 % · Estable",
  before any card crosses the waterline. The level is never hidden without its number taking its place.
- **W4 · Level-true.** The waterline stays at the real percentage of the full window height. The existing placement
  rule (water or sky, never across) is unchanged.

### Compact width (iPhone 402 × 874 pt, first viewport)

```
┌──────────────────────────────┐
│ San Juan            [⇪][…]   │  inline large title, glass toolbar
│ Río Alberche · Madrid        │
│                              │  sky ≈ 50 % (real level 46,8 %)
│                              │
│~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~│  waterline at real level
│ 46,8 %                       │  ≥ 88 pt, white
│ 64,4 hm³ de 138 hm³          │
│ → Estable · +0,19 hm³ en 24 h│
│ ◷ SAIH Tajo · 7 nov, 13:00   │
│ ┌──────────────────────────┐ │  ≈ 78 %: first card peeks (W2)
│ │ Últimas 48 h   SAIH 13:00│ │
│ │ ╱‾‾‾‾‾╲___╱‾‾            │ │
│ └──────────────────────────┘ │
│   ( San Juan ) (  El río  )  │  2-tab Liquid Glass bar
└──────────────────────────────┘
```

At 8 % or at AX3 and above, the block moves into the sky (the existing fallback) and the first card still peeks.
At AX5 the block wraps line by line and never truncates.

### Regular width (iPad, unfolded foldable, iPhone Duo open)

The water column is fixed and the modules scroll beside it. This is Weather's landscape layout, and the A prototype
already pointed this way.

```
┌──────────┬──────────────────────────────────────────────────────┐
│ EL RÍO   │ San Juan                                    [⇪][…]   │
│ ▯ Burg.  │ ┌─ water column 38 % ─┐  ┌ modules 62 %, scroll ──┐  │
│  35,8 %  │ │                     │  │ Últimas 48 h  │ En la  │  │
│ ▮ S.Juan │ │      (sky)          │  │ ╱‾‾╲_╱‾       │ presa  │  │
│  46,8 %  │ │                     │  ├───────────────┴────────┤  │
│ ▯ Picad. │ │~~~~~~~~~~~~~~~~~~~~~│~~│~~ one waterline ~~~~~~~│~~│
│  66,9 %  │ │ 46,8 %              │  │ MITECO semanal (badge) │  │
│──────────│ │ 64,4 de 138 hm³     │  ├────────────────────────┤  │
│ Cuenca   │ │ → Estable · +0,19   │  │ Este año · pasado ·    │  │
│ (lluvia) │ │ ◷ SAIH · 7 nov 13:00│  │ media (mini chart)     │  │
│          │ └─────────────────────┘  │ Histórico · Previsión… │  │
└──────────┴──────────────────────────────────────────────────────┘
 sidebar 22 %  (collapsible; hidden by default in portrait)
```

- The waterline runs across the whole window, through the gaps between cards. The modules pane is one column below
  about 600 pt and two above it.
- In iPad portrait the sidebar collapses and the water column is 40 %.
- On the Duo, the fold falls between the water column and the modules (book posture: water on the left).

### Mac (future, Catalyst or native SwiftUI, minimum about 900 × 600)

The same split view with a translucent source-list sidebar (the river), the water column and a 2–3 column module
grid. Toolbar items for Share, Alerts and Refresh. Module detail opens in an inspector, not a sheet. Add an optional
`MenuBarExtra` with "46,8 % · Estable" (Mercury's pattern) and Settings for alerts. The animated wave idles when
the window is unfocused.

### Watch, widgets, Android

- **Watch and widgets:** unchanged. They already are the identity.
- **Android:** mirror the IA: a 2-item `NavigationBar`, then a `NavigationRail` and list-detail from medium width.
  Water by Canvas, cards as M3 Expressive surfaces with a fixed dark-water container, dynamic colour on the chrome.

## Changes, ranked by impact

1. **Peek rule (W2).** Replace the one-viewport header in `NowView`. This is the single biggest fix for the
   "taking up the whole screen" feeling.
2. **Water behind every page (W1),** with "Este año" merged into the reservoir page as modules plus drill-down
   details. That gives two sections.
3. **Regular width: fixed water column plus a scrolling module pane,** with the river as the sidebar. This kills
   the empty iPad sky.
4. **Collapse-on-scroll header (W3),** which keeps the number visible when the water is covered.
5. **AX fixes:** wrap, never truncate, the hero lines. Keep the tab bar clear of the block. Let the system glass and
   scroll-edge effect handle the bar instead of tinting it.
6. **Night sky in dark mode and a softer day sky,** borrowed from the widgets.

**Keep:** the figure block, the placement rule, the level-true waterline, the MITECO panel style, the chart colours,
B's tanks, the widgets and the watch.

## Risks (what an adversary would attack)

- **Data under data.** Unlike Weather, the background encodes the level. Cards over the water hide it. W3 mitigates
  this, but a card stack over the waterline at 97 % (almost no sky) needs a render check.
- **"Always water-world" fights semantic colours.** White-on-dark cards in light mode ignore the system appearance.
  Weather gets away with it; the adversary will say it breaks the "native first" rule. It needs Increase Contrast
  and Reduce Transparency variants (opaque cards).
- **Two tabs looks thin,** and the history behind a module tap is less discoverable than a tab. Measure in
  TestFlight whether people find "Desde 1988".
- **The peek at 8 %** puts the first card over the sky, so the water strip is a 70 pt band under cards. The level
  reads from the number, not the picture. Is the picture still worth it there?
- **Cost and battery:** an animated wave behind a long scroll and a two-pane layout with one waterline add
  complexity, and both must stop under Reduce Motion and when idle.
- **The honest fallback:** if W1 and W2 rendered at 8 / 48 / 97 % and AX5 still feel like a poster, the water
  should shrink to a hero band (Lead 2's direction) and live fully only in widgets and the watch. My research says
  it won't come to that: Weather, Mercury and Carrot prove that full-bleed works *when content floats on it*. 2.0's
  failure is the empty first viewport, not the bleed.
