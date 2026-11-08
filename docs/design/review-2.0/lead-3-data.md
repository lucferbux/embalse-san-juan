# Review 2.0 · Lead 3 "Datos": let the waterline be the chart

Reviewer: design lead "Datos" (data visualisation and information design). Date: 2026-11-08.
Thesis under test: the visual identity should come from the data itself, with the level drawn as a scale against
this year, last year and the normal range, like a tide or snow-depth chart, rather than as decorative water.

## 1. Verdict

**The current design half-proves my thesis already.** The waterline in Ahora is not decoration. Its height *is* the
SAIH percentage, so the hero is a chart, but a one-dimensional one: a single bar with a wave on top. It answers
"how full?" beautifully and leaves the other half of the 3-second question, "is that normal, is it going up?", to one
line of small text.

What works:
- `iphone-69/light-01-ahora.png`: the figure, volume, trend word and "SAIH Tajo · 7 nov, 13:00" sit together in the
  water. The type hierarchy and the number style are right. Keep all of it.
- `iphone-69/light-04-burguillo.png`: the "Últimos 90 días" card draws history *as water*, with labelled ends
  ("hace 91 días 106,7 hm³" to "hoy 70,9 hm³"). The 2.0 large widget (`widget-snapshots/large-light.png`) does the same
  on the full surface. **The best data idea in the app is hidden on a secondary page and in a widget.**
- `iphone-69/light-02-este-ano.png`: the year chart is solid. It uses distinct colours, a real hm³ axis, "hoy", and a
  MITECO-only caption.
- `iphone-69/light-03-el-rio.png`: the three tanks read in under a second, upstream to downstream.

What doesn't:
- **Empty sky.** In `light-01-ahora.png` about 45 % of the screen is pale gradient with nothing in it. It is honest at
  46,8 %, but it carries no information. On iPad (`ipad-portrait/light-01-ahora.png`) the sky takes about 52 % and the
  water's lower 35 % is empty too. The figure sits small in the bottom-left. This is the owner's "whole screen" unease,
  and it's correct: the canvas is huge and the data in it is one number.
- **No context in the first viewport.** "Estable · +0,19 hm³ en 24 h" is the only temporal signal. The question locals
  actually ask in November is "how does this compare with last year?", and it is two taps away.
- **The year chart is stranded under MITECO's numbers.** In `light-02-este-ano.png` the chart is the second card, its
  "hoy" label collides with the dot, and there is no historical range. The 1988-onward record, the app's richest asset,
  is reduced to a segmented history card further down. (`iphone-69/light-05-historico-1988.png` shows the same
  first viewport as `-02`: the capture never reached the history card, which is itself a sign it is buried.)
- **Android** (`android-phone/light-01-ahora.png`) is a 1.0 water card, then a 24 h line chart with no scale context
  (64,20–64,60 hm³, so a 0,4 hm³ wobble fills the plot). That auto-scaled y axis exaggerates noise. It is the exact
  opposite of the honesty the water gives.

## 2. References (what I take from each)

| App | Pattern taken |
|---|---|
| **UK Environment Agency, Check for flooding** ([station page](https://check-for-flooding.service.gov.uk/station/7085)) | A latest reading, a trend word and a state word ("Normal"), then the **normal range** and the **highest ever recorded, with its date**, as reference levels. A reservoir needs exactly that vocabulary: normal for this week, record low, record high. |
| **NRCS SNOTEL / Montana Snowpack Explorer** ([explorer](https://snow.climate.umt.edu/), [NRCS chart help](https://www.wcc.nrcs.usda.gov/ftpref/support/states/NV/assets/InteractiveChartHelp.pdf)) | This year's line over a shaded percentile band by day of year, with the median as the "normal" line. The canonical way to say "below normal for the date". OpenSnow's "Base Depth vs Average" ([post](https://opensnow.com/news/post/march-2024-snowpack-update)) is the consumer version. |
| **Tides Near Me** ([App Store](https://apps.apple.com/us/app/id585223877)) and tide apps generally | A curve that fills the screen width, with a "now" marker on the curve and the current height written at the marker. The curve *is* the hero. The number is attached to a point on it, not floating in space. |
| **Gentler Streak** ([review](https://www.tapsmart.com/features/deep-dive-gentler-streak/)) | A soft "zone" band you are inside or outside of, readable without axes. It shows that a range band can be friendly, not technical. |
| **Apple Weather** (iOS) and **Pixel Weather** (Android) | The 10-day row puts today's temperature dot inside the week's range bar. It is a one-line, axis-free "where am I in the range". This is the template for widgets and the Watch. |
| **MITECO Embalses viewer** (via [Maldita](https://maldita.es/clima/20230425/estado-embalses-espana/)) | The official comparison set: this year against last year and the 5- and 10-year average. The 10-year average excludes the current year. Our labels must match it word for word. |
| **Flighty** | One live object, a bar along a timeline with "now" on it, scales from Live Activity to iPad. History and the present share one drawing. |

## 3. Proposal: the surface is the year

**One change of idea:** the waterline stops being a flat line at today's level. It becomes **the last 12 months of
SAIH daily volume, drawn on a fixed 0-to-capacity scale, with today at the right edge.** The water is still water,
full-bleed, the same blue and the same white text. Its crest now traces the year's rise and fall, and the empty sky
becomes the place where context lives:

- a faint **range band** in the sky and the water: the min to max of the same day over the last 5 SAIH years. It is
  SAIH-only, so there is no mixing.
- a thin **last-year line** (warm sand, as in the year chart);
- the **all-time SAIH maximum in the series** as a hairline labelled with its date, like the UK "highest recorded" level.

The figure block anchors to **today's point at the right edge**: "hoy" sits on the crest, and the figure sits below it
in the water. The water left of today is drawn 15 % lighter, so the eye reads the right edge as "now". This fixes C's
fault of the water overstating today's level. San Juan swings about 60 hm³ in a year (`light-02-este-ano.png`), so on
a 0–138 scale the crest has real shape. Unlike C's 90 days, it is never a flat line.

With Reduce Motion, the crest is static anyway. The wave is a 2 pt shimmer on the crest, not a sine that hides data.

### Information architecture: three sections, kept, re-cut

| Section | Question | Content |
|---|---|---|
| **Ahora** | How full, and is that normal? | Surface-year hero (SAIH). Below: 48 h / 7 d (SAIH, y axis from 0 or with a visible break), elevation, outflow, weather at the dam. |
| **Historia** (renamed from "Este año") | How does this compare? | The MITECO panel. Then the **MITECO year chart promoted to hero**: this year, last year, the 10-year average, and the **1988-onward min–max band in percent** (capacity changed, so percent is the only fair unit). The record low and high are labelled with their year. Then 1 y / 5 y / since 1988. |
| **El río** | What's upstream and downstream? | The three tanks, rain gauges (measured), and the AEMET forecast (moved here: rain belongs with the basin, not with history). |

The ficha, alerts, suggestions, tips and share stay in the toolbar menu. Three is the right number. Two would force
history and the river into one long scroll. Four would split hairs (rain on its own tab gets a few visits a year).

### Compact (iPhone, Android phone): about 402 × 874

```
┌──────────────────────────────┐
│ San Juan            [⇪][…]   │  title, toolbar (glass)
│ Río Alberche                 │
│ ┄┄┄┄┄┄ máx 2014 · 136 hm³ ┄┄ │  hairline, record
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  range band (5 y SAIH), 12 % opacity
│      ╭──╮ ‥‥ año pasado      │  last year, sand, 1.5 pt
│╭────╯    ╲          hoy ●    │  crest = 12 months; today at right
│▓▓▓▓▓▓▓▓▓▓▓╲▁▁▁▁▁▁▁▁▁▁╱███████│  past water lighter │ today column full
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  46,8 %  │  figure right-aligned under "hoy"
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  64,4 de 138 │
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ → Estable    │
│▓▓▓ nov ─── may ─── nov ▓▓▓▓▓▓│  month ticks inside the water, white 60 %
│▓▓ Normal para la fecha ▓▓▓▓▓▓│  state word: below / normal / above (SAIH 5 y)
│▓▓ SAIH Tajo · 7 nov, 13:00 ▓▓│
│   [ Ahora | Historia | Río ] │  tab bar (Liquid Glass) / NavigationBar
└──────────────────────────────┘
 sky ≈ 30 %  ·  surface chart ≈ 70 %
```

At low levels (8 %), the crest sits near the bottom. The figure block moves to the sky, in the same calm fallback
`DESIGN-2.0.md` rule 1 defines, which now has a whole sky of room. The band then shows at a glance how bad it is.

### Regular (iPad, iPhone Duo open, unfolded foldable, tablet): about 1032 × 1376 or landscape

```
┌───────────────────────────────────────────────────────────────┐
│ San Juan · Río Alberche        [Ahora|Historia|Río]   [⇪][…]  │
│┄┄┄┄┄┄ máx 2014 ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│
│░░░░░░░░░░░░░░░░░░░░░ band ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│ hero ≈ 45 % height
│╭──────╮       ‥‥ año pasado ‥‥                      hoy ●     │ full width,
│▓▓▓▓▓▓▓╲▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁╱▔▔▔▔╲▁▁▁▁▁▁▁▁▁▁▁╱████████  │ 12 months
│▓ nov    feb     may     ago     nov ▓▓▓▓▓▓▓▓  46,8 %  ████████ │ figure at today
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  64,4 hm³ · → Estable ████ │
├───────────────────┬────────────────────┬──────────────────────┤ content max 1200
│ Últimas 48 h      │ Historia (MITECO)  │ El río               │ three columns,
│ SAIH · 13:00      │ sem. 3 nov         │ ▮ ▮ ▮  35 · 47 · 67 %│ glass-free panels
│ ╭─╮ chart, 0-based│ 65 · 72 · 56,9 hm³ │ SAIH · 13:00 each    │ ≈ 55 % height
│ Cota · Caudal     │ mini year chart+band│ Lluvia 24 h          │
│ Tiempo en presa   │ → Ver Historia     │ → Ver río            │
└───────────────────┴────────────────────┴──────────────────────┘
```

On a fold, the hero stays one continuous surface across the hinge. That is fine: a chart line tolerates a crease
better than text does. The columns put the fold in a gap.

### Future Mac window (and wide iPad): about 1280 × 800

```
┌────────────┬──────────────────────────────────────────────────┐
│ Embalses   │ San Juan                            [1a|5a|1988] │
│ ● San Juan │ ┌──────────────────────────────────────────────┐ │
│   Burguillo│ │ surface hero, zoomable range; hover = value  │ │ ≈ 55 %
│   Picadas  │ │ & date tooltip; same band/last-year/record   │ │
│ ────────── │ └──────────────────────────────────────────────┘ │
│ Ahora      │ ┌ Últimas 48 h ┐ ┌ MITECO semanal ┐ ┌ Río ──────┐ │ ≈ 40 %
│ Historia   │ │ SAIH         │ │ + year chart   │ │ tanks,rain│ │
│ Río        │ └──────────────┘ └────────────────┘ └───────────┘ │
└────────────┴──────────────────────────────────────────────────┘
```

The sidebar puts the **reservoir** first and the section second (`NavigationSplitView`). This also becomes the iPad
sidebar via `.sidebarAdaptable`. Burguillo and Picadas get the same hero.

### Where "water" survives

Everywhere. It is still a full-bleed blue body whose top is the real volume, with white text inside it. It has simply
gained a time axis. Widgets: the large one already does this with 90 days. Change it to 12 months plus the band, and
it matches the app. Small and medium widgets and the Watch use the Apple Weather pattern: a one-line range bar with a
dot ("Normal para la fecha"), white on the water. The Lock Screen gauge maps directly onto `Gauge` and Wear OS's
ranged-value complication.

## 4. Changes ranked by impact

1. **The hero crest becomes 12 months of SAIH on a fixed 0–capacity scale, with today anchored at the right edge.**
   This fills the empty sky with meaning and answers "going up or down?" visually. On iPad it fixes the empty
   first viewport. `SurfaceHistory` and the large widget already contain most of the code.
2. **A "normal for the date" band and state word** (SAIH 5-year band on Ahora, MITECO since-1988 band in Historia).
   It is the one comparison people ask for, and it can be computed client-side from data the app already loads
   (`History.daily`, `History.weekly`). No backend change.
3. **Promote the year chart to the top of Historia, add the 1988 band, and move AEMET to El río.** Rename "Este año"
   to "Historia".
4. **Honest scales:** never auto-fit a y axis to a 0,4 hm³ range without a visible break or a "zoomed" label. This
   matters most on Android 1.0 and in the 48 h panel.
5. **Android adopts the same hero** with a NavigationBar or Rail, and Material 3 Expressive panels below. The water
   remains the one hardcoded colour. The band and the last-year line use `onPrimaryContainer`-derived tones on the
   chrome only.

**Keep:** three tabs, the number style, the figure block, source-and-date in every block, the MITECO panel styling,
the El río tanks, white-on-water widgets, and the fallback placement rule.

## 5. Risks (what an adversary would attack)

- **"It's a chart now; the poetry is gone."** It's partly true. A flat calm surface is more serene. Mitigation: the
  crest is smoothed (7-day mean), the band is very faint, and the labels sit only at the record line and "hoy".
  Prototype both at 8, 48 and 97 % before deciding.
- **Past water misread as present water.** C was rejected for exactly this. The lighter past fill and the right-edge
  anchor must be tested with real people in a 3-second test: "how full is it now?"
- **A 5-year SAIH band is a thin climatology,** and calling it "normal" may mislead after a drought run. Label it
  "rango 5 años (SAIH)", and keep "normal" language for the MITECO 10-year comparison in Historia.
- **Two bands, two sources, two tabs.** Users may compare the Ahora band with the Historia band and find they
  disagree. Each must carry its source line, and the copy must say why they differ.
- **Text over a sloped crest.** The placement rule becomes a function of the crest's height at the figure's x
  range, not one waterline. That's more complex, and AX5 will push the block to the sky more often.
- **Performance:** drawing 365 points plus a band, animated, in a widget. Widgets stay static. The app needs a Canvas
  path cached per snapshot.
