# Review 2.0 · Lead 2 "Panel": the glanceable dashboard

Reviewer role: Apple-platform design lead testing one thesis. The app should be a **summary dashboard**: a compact but
still very visual hero, with the water as a contained tile, followed by a grid of modules. Date: 2026-11-08.
Input: `build/ux-review/**` (current 2.0 TestFlight build), `build/widget-snapshots/`, `build/design/*`,
`DESIGN-2.0.md`, `DIRECTIONS-2.0.md`.

## 1. Verdict on the current design

**Full-screen water is the right answer for one case only: iPhone, default text size, a mid-range level. It is the
wrong frame for the whole product.** The idea is good, so keep it as the brand. The way it is used, as the layout of
the first screen, does not scale.

What works:

- `iphone-69/light-01-ahora.png`. One number, one trend sentence and one source line, all in the first viewport.
  It is calm, recognisable and clearly *this* app. The 3-second glance is answered.
- `iphone-69/light-03-el-rio.png`. The three mini tanks are the best visual in the build. Three reservoirs read at a
  glance with honest per-reservoir SAIH times. It is already a dashboard module.
- `iphone-69/dark-02-este-ano.png`. The MITECO panel with its "SEMANAL" badge, and the three-line year chart in
  distinct colours, are clear and correctly kept apart from SAIH.
- `widget-snapshots/medium-light.png`. The water as a *contained* surface, with the figure and a separate MITECO
  block, is already the best summary of the app. It is a tile.

What doesn't work:

- **The first viewport is half empty.** On `iphone-69/light-01-ahora.png` the sky takes about 45 % of the screen and
  carries only the title. Nothing is below the figure until you scroll, so the 24 h curve, the outflow, the river and
  MITECO are all hidden. The glance answers "how full" but not "is it going up, how does it compare, what about the
  river". Most of that data exists and is one scroll away.
- **iPad is the clearest failure.** `ipad-portrait/light-01-ahora.png` shows a pale sky over about 55 % of a
  2064 × 2752 canvas. The figure sits bottom-left and the right two-thirds of the water is empty. The spec's
  "three balanced columns" below a band did not survive implementation, and they could not anyway: a band of 40 % plus
  three columns needs the water to stop *somewhere*, which means it is already a tile.
- **The layout is held hostage by the level.** `iphone-69/large-01-ahora.png` at AX sizes truncates every line
  ("64,4 hm³ de 1…", "SAIH Tajo · 7 no…") because the block must fit under a waterline set by the data. At 8 % it
  cannot fit at all (DIRECTIONS A1). A layout whose space budget depends on the drought is fragile by design.
- **The other two tabs are a different app.** `ipad-portrait/light-02-este-ano.png` and `light-03-el-rio.png` are
  plain grouped cards on `systemGroupedBackground`, half the canvas empty below them. The water identity lives on one
  screen and in the river tanks, and nowhere else.
- **Android 1.0 already proves the alternative.** `android-phone/dark-01-ahora.png` uses a contained water card with
  the figure inside, followed by the realtime chart and rows. It is less elegant than iOS 2.0, but it shows more in the
  same height and it never has an empty sky.

## 2. References

| App | Pattern I take |
|---|---|
| **Apple Weather** (iOS, iPadOS, macOS) | A full-bleed *ambient* background with **modules on top**: the header block (place, figure, condition) is small, and the screen is a grid of uniform rounded modules (hourly, 10-day, UV, wind, precipitation map). The layout reorders when something matters: rain coming moves the precipitation and radar modules up. On iPad and Mac it is a sidebar plus a module grid, never one huge figure. The atmosphere is the *background*; the figure is not the layout. |
| **Pixel Weather** (M3 Expressive) | Cards of different heights that the user can **reorder by long-press**, saved per location. Two columns on tablets and foldables. A gradient that follows conditions. That is the Android mirror for this app. |
| **Apple Health Summary** | **Pinned** cards first, then Highlights: each card is "metric · value · time" plus a sparkline, and taps through to a detail chart. iPad uses a sidebar. The model for the modules here: every tile has a value, a source and a time, and opens a detail. |
| **Flighty** (Apple Design Award) | The airport-board principle: **one card per subject, essential info only, status colour reserved for change**. The same card is the Live Activity and the widget. Take that 1:1 correspondence: the hero tile *is* the medium widget. |
| **Gentler Streak** (ADA 2024) | One expressive **hero visual** (the Activity Path) at the top, about 40 % of the screen, then a short stack of cards ("Today's recommendations", sleep). It is still a very visual app with a dashboard under it. The proof that "contained hero + modules" does not have to feel like a spreadsheet. |
| **Apple Fitness Summary** | Rings as a contained hero card, then Trends and Awards as a two-column grid. The same tile sizes scale cleanly from iPhone to iPad. |
| **Surfline-style spot pages** | A "conditions now" summary card (wave, wind, tide), then a forecast strip, then detail. Activity users (swimmers, boaters, fishermen) expect *now → next days → detail*. |

The honest reading: the most admired data apps of the last few years (Weather, Health, Fitness, Flighty, Gentler
Streak, Pixel Weather) all keep their identity in **one hero element plus a coherent module system**. None of them
spends the first viewport on a single figure on iPad or Mac. Apple Weather on iPhone comes closest to "full screen",
and even there the figure takes about 30 % and modules start in the first viewport.

## 3. Proposal

### Information architecture: three sections, renamed for what they answer

| Section | Question | Content |
|---|---|---|
| **Ahora** (summary) | How full, is it moving, anything new? | Hero water tile (SAIH). Then modules, each a tap to a detail page: **Últimas 48 h** (SAIH curve), **Salida al río** (m³/s, source), **Cota y nivel**, **MITECO · semana** (own tile, "SEMANAL" badge), **Este año** (MITECO mini 3-line chart), **El río** (three mini tanks), **Lluvia medida** (SAIH gauges), **Previsión** (AEMET 3 days). |
| **Histórico** | How does this compare? | Year comparison chart (MITECO), then 1 y / 5 y (SAIH daily) and since 1988 (MITECO weekly) on separate cards, statistics beside the chart. The full AEMET 7 days lives in a detail from the Ahora tile, not here. |
| **El río** | And the neighbours? | Burguillo, San Juan, Picadas as tanks; each opens its own page with *its own* hero tile and modules (same template). Basin rain gauges. |

Ahora becomes the place where every source is summarised once. The two other tabs are the long browse. "Este año"
becomes "Histórico", because it already holds history since 1988, and its forecast moves out (it's not history).
The ficha, alerts, suggestions and tips stay behind the toolbar button.

**Module rules.** Each tile holds a single source, so MITECO and SAIH never share a tile. Each tile has a title, a
value, a "source · time" footer and a chevron. Modules are reorderable with an edit mode (Pixel Weather and Health
pinning), with a fixed default order. They can promote themselves: an outflow above the alert threshold, or rain over
X mm, moves its tile to just under the hero with a status tint (Apple Weather's rain promotion, Flighty's colour only on
change).

### Compact width (iPhone, Duo closed, narrow splits)

```
┌──────────────────────────────┐
│ San Juan            [⇪][…]   │  large title, scrolls away
│ Río Alberche · Madrid        │
│╭────────────────────────────╮│  HERO TILE ≈ 42 % of viewport
││ sky (tinted, not white)    ││  (≈ 340 pt on 6.9", 280 pt on 375 pt phone)
││~~~~~~~~~~~~~~~~~~~~~~~~~~~~││  waterline = real level INSIDE the tile
││ 46,8 %                     ││  figure: always in the water band, the
││ 64,4 hm³ de 138 hm³        ││  tile's water is drawn as min(level, ≥ stack)
││ → Estable · +0,19 hm³ 24 h ││  with the true level marked (see risks)
││ ◷ SAIH Tajo · 7 nov 13:00  ││
│╰────────────────────────────╯│
│╭────────────╮╭──────────────╮│  2-column module grid, first row visible
││Últimas 48 h││Salida al río ││  without scrolling
││ ╱‾‾╲__╱    ││ 4,2 m³/s     ││
││SAIH · 13:00││SAIH · 13:00  ││
│╰────────────╯╰──────────────╯│
│╭────────────────────────────╮│  full-width tiles for charts / tanks
││ MITECO · semana 3 nov  SEM ││
││ 65 hm³ · 72 · 56,9         ││
│╰────────────────────────────╯│
│ [ El río: ▮▮▮ tanks ]        │
│ [ Lluvia ] [ Previsión ]     │
│    ( Ahora  Histórico  Río ) │  Liquid Glass tab bar
└──────────────────────────────┘
```

At AX3 and above the grid collapses to one column and the hero's text stacks freely: the tile grows in height with the
text instead of the text being clipped to a waterline. The water stays *behind* it as the tile's fill.

### Regular width (iPad, Duo open, foldable unfolded, Android tablet)

```
┌──────────┬───────────────────────────────────────────────────────┐
│ Sidebar  │ San Juan                                   [⇪][…]     │
│ ◉ Ahora  │╭───────────────────────────────╮╭───────────────────╮│
│ ○ Histó- ││ HERO TILE (≈ 60 % width,       ││ El río            ││
│   rico   ││ ≈ 38 % height)                 ││ ▮▮ ▮▮▮ ▮▮▮▮       ││
│ ○ El río ││~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~││ Burg 35,8  SJ 46,8││
│ ──────── ││ 46,8 %   (120 pt)  Últimas 48 h││ Pic 66,9          ││
│ Burguillo││ 64,4 hm³ · Estable   ╱‾╲_╱     ││ SAIH · 13:00 each ││
│ Picadas  ││ SAIH Tajo · 7 nov 13:00        │╰───────────────────╯│
│          │╰───────────────────────────────╯                      │
│          │╭──────────╮╭──────────╮╭──────────╮╭──────────╮        │
│          ││Salida    ││Cota/nivel││MITECO SEM││Lluvia    │  4-col │
│          │╰──────────╯╰──────────╯╰──────────╯╰──────────╯        │
│          │╭──────────────────────────────╮╭──────────────╮        │
│          ││ Este año (MITECO) 3 lines     ││ Previsión 7 d│        │
│          │╰──────────────────────────────╯╰──────────────╯        │
└──────────┴───────────────────────────────────────────────────────┘
```

`TabView` with `.sidebarAdaptable`: tabs on compact, sidebar on regular, never chosen by idiom. The grid is an
adaptive `LazyVGrid` (minimum tile about 220 pt) inside a content width capped at about 1200 pt, so there is no empty
right half. On the Duo inner display, the hero spans the left half and the grid the right; the fold falls in the
column gap. The hero carries its own 48 h curve on regular width, because there is room.

### Mac (future, Catalyst-free SwiftUI)

A window of about 1100 × 760 pt: the same sidebar plus grid, with a **menu bar extra** (the water tile at 280 pt
wide), and the medium widget on the desktop. The hero is never taller than about 300 pt, because a Mac window has no
"first viewport" ritual.

### Watch and widgets

They are unchanged, because they are already tiles. The Watch's first page is the hero tile full-bleed (on a 46 mm
screen, a tile *is* the screen). Make the app's hero literally the same view as `MediumWidgetView`, so the brand
is one object everywhere.

### How the water survives

1. **The hero tile is real water at the real level**, animated and tilting, with the same palette that deepens when
   full and turns teal when low.
2. **The app's background takes the water's hue**: a very light tint of the current level colour behind the grid (as
   Apple Weather tints by condition), so even Histórico feels "underwater".
3. **Tanks are the module language** for every reservoir mention: El río tile, river page, neighbour pages.
4. **Scroll transition.** As you scroll, the hero shrinks into a compact water strip under the nav bar (46,8 % · a
   thin wave). The water never leaves the screen.

## 4. Changes vs today, ranked by impact

1. **Ahora becomes hero tile + module grid** (Major: fixes the empty first viewport, the iPad void, and makes the
   glance answer "moving / compared / river" without scrolling).
2. **Text no longer depends on the waterline** (Major: the tile grows with Dynamic Type, which ends the AX truncation
   in `large-01-ahora` and the 8 % problem, A1, by construction).
3. **Sidebar-adaptable navigation with neighbours as first-class destinations** on regular width (Major for iPad and
   Mac).
4. Rename "Este año" → "Histórico" and move the forecast into an Ahora tile (Minor).
5. Hero view shared with the medium widget and the Watch (Minor, lowers cost).
6. Android 2.0: keep its 1.0 instinct (contained hero card), with M3 Expressive shaped tiles and Pixel Weather's
   reorder.

**Keep:** the number style, the trend sentence, source-per-block, the MITECO "SEMANAL" panel, the year chart colours,
the river tanks, the widgets exactly as they are, Liquid Glass only on chrome, the motion and its Reduce Motion stop.

## 5. Risks: what an adversarial reviewer would attack

- **"You turned a signature into a template."** The full-screen iPhone *is* more memorable, and a tile grid is what
  every app does. That's the strongest case against me. Mitigation: the hero stays big (about 42 %), animated and
  edge-to-edge in colour, the background is tinted, and the shrinking strip keeps the water present. If the owner
  values the one-screen poster over density, a hybrid is legitimate: keep full-bleed on compact **only** at default
  text size, and use the tile everywhere else. I'd still argue against it, because two layouts mean double testing.
- **The tile still has a waterline problem.** At 8 % a 300 pt tile has about 24 pt of water. The figure can't sit in
  it. Answer: the text block is in the tile's *sky* in `.primary` when shallow (the B fallback the spec already
  defines), and the tile is tall enough that the switch is rare. It's a smaller version of A1, not zero.
- **Busy, not glanceable.** Eight tiles can turn into a Health-style wall. Hard cap: four tiles plus three full-width
  tiles in the default order, the rest behind "Editar". Status colour is used only on promotion.
- **SAIH/MITECO adjacency.** A grid places MITECO's 65 hm³ next to SAIH's 64,4 hm³, and readers *will* compare them.
  The badge, the different tile style and the source footers must make the difference obvious, and a small "¿Por qué
  no coinciden?" link should be in the MITECO tile.
- **Reordering is scope creep** for a one-person app. It can ship in 2.1. The default order alone fixes the problems.
- **Cost.** It reworks NowView and RootView. It reuses existing panels (`RealtimePanel`, `OutflowPanel`,
  `YearSummaryPanel`, `RiverSummaryPanel` already exist in `NowView.swift`) as tiles, so most of the work is layout,
  not new views.
