# Embalse San Juan 1.0: adversarial UX audit, Apple formats

Reviewer: `ux-adversary`. Input: `build/ux-review/` from the run of 2026-11-07T10:33Z (commit `0056929`, uncommitted changes).
Formats: `iphone-69`, `iphone-compact`, `ipad-portrait`, `duo-outer`, `watch-large`, `watch-small`, `widgets-ios`. All 128 images opened (light, dark and large per screen; default and large per watch page; every widget file). Android folders were not reviewed here.
Rules judged against: `CLAUDE.md`, `docs/SPEC-v1.md`, Apple HIG (iOS 27, watchOS 27, WidgetKit). `docs/design/DESIGN-2.0.md` does not exist yet.

## Verdict

1.0 can stay in the store at default text size, but it is not good enough to build 2.0 on. The default-size screens mostly answer the one question. At accessibility sizes the app falls apart, and that is the single worst problem: the hero splits one sentence into black text on the sky and white text in the water (`*/large-01-ahora.png`). Numbers break away from their units ("70,9 / hm³", "(47,1 / %)"). Reservoir names get hyphenated ("Bur-guillo", "Pica-das"). On iPad the source line is cut to "SAIH Tajo, 7 nov, 11:00…." and the temperature value is clipped. A screen that exists to say "how much water" cannot be read by people with large text. Close behind are four trust problems. The same figure is shown with four different precisions (64,47 / 64,5 / 65 / 49). The stale widget truncates the date, which is the one thing it has to show. Several MITECO and SAIH figures appear without a source or a date. And one capture's history says the year's minimum was 66,9 hm³ while the hero says 64,51 hm³. The iPad layout is an iPhone layout stretched across 13 inches, so the number is small and the secondary screens are mostly empty. Three formats were never captured (iPad landscape, Duo inner, watch complications), so the Duo fold rule in `CLAUDE.md` is still unverified.

## Findings count

| Table | Blocker | Major | Minor | Idea | Total |
|---|---|---|---|---|---|
| A. Shared by every app format (iPhone 6.9, compact, iPad, Duo outer) | 3 | 9 | 8 | 3 | 23 |
| B. iphone-69 | 1 | 2 | 1 | 0 | 4 |
| C. iphone-compact | 0 | 1 | 2 | 0 | 3 |
| D. ipad-portrait | 1 | 4 | 3 | 1 | 9 |
| E. duo-outer | 1 | 2 | 1 | 0 | 4 |
| F. watch-large and watch-small | 0 | 5 | 2 | 1 | 8 |
| G. widgets-ios | 1 | 5 | 5 | 2 | 13 |
| **Total** | **7** | **28** | **22** | **7** | **64** |

The duo-outer Blocker (E1) is a coverage risk: duo-inner was not captured, so the fold rule could not be checked. It is not a visible defect.

---

## A. Shared by every app format

These show up in `iphone-69`, `iphone-compact`, `ipad-portrait` and `duo-outer`. They are listed once, with every image that shows them.

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| A1 | Blocker | `iphone-69/large-01-ahora.png`, `iphone-compact/large-01-ahora.png`, `ipad-portrait/large-01-ahora.png`, `duo-outer/large-01-ahora.png` | At accessibility sizes the hero text block is taller than the water. `WaterlineText` paints the part above the waterline primary (black) and the rest white. "46,8 % / 64,47 hm³ de" ends up black on the sky and "138 hm³ / Estable · → +0,19 hm³ en 24 h" white in the water, so one sentence changes colour halfway through. The trend line wraps with the arrow hanging on its own line and a ragged indent. | One surface, nothing cut at the waterline (the widget rule, and the 2.0 direction for the app). Dynamic Type. Craft. | In `HeroSection` (`App/ContentView.swift`), when `dynamicTypeSize.isAccessibilitySize`, keep only the percentage inside the water card and move "64,47 hm³ de 138 hm³" and the trend into plain list rows under it. Otherwise place the whole text block in the bottom `percent` fraction of the card and grow the card (`@ScaledMetric height`) until the block fits under the waterline. Never let `WaterlineText` mask a block of more than one line. |
| A2 | Blocker | `iphone-compact/large-02-boletin.png` ("65 hm³ (47,1 / %)"), `iphone-compact/large-03-alberche.png` ("70,9 / hm³"), `ipad-portrait/large-01-ahora.png` ("de 138 / hm³"), `duo-outer/large-02-boletin.png`, `duo-outer/large-03-alberche.png` | Numbers wrap away from their units and percent signs. | Number formatting (`48,5 %`, `hm³` stay with the number). | In `Format.percent`, `Format.hm3` and `Format.optional` (`EmbalseKit/Support/Format.swift`), join number and unit with U+00A0 (or U+202F NARROW NO-BREAK SPACE, as in Spanish typesetting). Join "de 138 hm³" with no-break spaces too. Add a unit test that the strings contain no plain space before a unit. |
| A3 | Blocker | `iphone-69/large-03-alberche.png`, `iphone-compact/large-03-alberche.png`, `duo-outer/large-03-alberche.png` | `ChainRow` keeps name and value side by side at AX sizes. Names are hyphenated ("Bur-guillo", "Pica-das", "San / Juan") and values wrap across three lines with a dangling "·". | Dynamic Type, truncation and clipping. | In `ChainRow`, switch to a `VStack` (name above, then "35,8 %" and "70,9 hm³" on one line) when `dynamicTypeSize.isAccessibilitySize`, the way `LabeledContent` already does in the other sections. Drop the "·" separator in that layout. |
| A4 | Major | `iphone-69/light-01-ahora.png` ("↗ Subiendo · +0,21 hm³") vs `iphone-69/dark-01-ahora.png` ("→ Estable · +0,19 hm³"), and every `*-01-ahora.png` | The label and the number disagree to the eye. A rise of +0,19 hm³ is called "Estable" and +0,21 is called "Subiendo". The 0,2 hm³ threshold in `Trend` is invisible, so the trend reads as arbitrary. | The one question (rising or falling). Trustworthy. | In `HeroSection`, when `Trend` is `.steady`, show "Estable · sin cambio relevante en 24 h" and move the signed delta to "Últimas lecturas". Or round the shown delta to one decimal and state the threshold in the footer ("variaciones menores de 0,2 hm³ se deben al viento"). Use the same rule in widgets and on the watch. |
| A5 | Major | `iphone-69/light-01-ahora.png` (64,51 hm³), `iphone-69/light-03-alberche.png` (64,5 hm³), `iphone-69/light-02-boletin.png` (65 hm³; "Media de 10 años 56,9" in the same block as whole numbers), `watch-large/light-03-datos.png` (Cota 565,4 m vs 565,45 m on iPhone), `widgets-ios/light-lock-circular.png` (49) | One quantity, four precisions. In the MITECO block, `tenYearAvgHm3` uses the default 1 decimal while the other rows use 0. | Consistency between formats. The agreed 2.0 rule of one number style. | Define one table in `Format`: SAIH volume 1 decimal everywhere (hero, river, watch, widgets); MITECO volume 0 decimals for every row, including the 10-year average in `WeeklySection` and the watch; percent 1 decimal everywhere, the circular complication included; elevation 2 decimals everywhere. Remove the `decimals:` overrides at call sites. |
| A6 | Major | `iphone-69/light-03-alberche.png`, `iphone-compact/light-03-alberche.png`, `ipad-portrait/light-01-ahora.png` (right column), `duo-outer/light-03-alberche.png`, and the dark variants | "Río Alberche" (Burguillo and Picadas) and "Lluvia en la cuenca" have no date. The footers are "De aguas arriba a aguas abajo." and "Pluviómetros del SAIH Tajo…". | Every figure shows its source and date. | In `AlbercheSection`, change the footers to "SAIH Tajo, 7 nov, 11:00. De aguas arriba a aguas abajo." and "Pluviómetros del SAIH Tajo, 24 h hasta las 11:00." using `Format.dayMonthHour` of the neighbour and gauge timestamps. |
| A7 | Major | `*/light-05-historico-1988.png`, `*/dark-05-historico-1988.png`, `*/large-05-historico-1988.png` | "Máximo 141,0 hm³, jul 1988" is above the "Capacidad" line (138 hm³) drawn on the same chart, and the 1988 curve pokes above it. Nothing explains why. | Trustworthy; the spec's validation says volume never exceeds capacity. | In `HistoryView`, add a footer line when any point is above `capacityHm3`: "MITECO publicaba entonces otra capacidad útil; por eso hay semanas por encima de 138 hm³." Or draw the capacity line as a step that follows MITECO's historical capacity. |
| A8 | Major | `iphone-69/light-08-propinas.png`, `iphone-compact/light-08-propinas.png`, `ipad-portrait/light-08-propinas.png`, `duo-outer/light-08-propinas.png` (all modes) | Prices show as "$0.99", "$2.99", "$3.99": US dollars in US format inside a Spanish-only interface. The spec says "from 0.99 €". | Spanish number style. Store-screenshot risk (this screen goes in listings and in review). | Set the storefront of `ios/App/Tips.storekit` to Spain (ESP, EUR) and run captures with locale `es_ES`, so StoreKit returns "0,99 €". Keep `displayPrice` from StoreKit. Never format the price yourself. |
| A9 | Major | `iphone-69/light-08-propinas.png`, `ipad-portrait/light-08-propinas.png`, `duo-outer/light-08-propinas.png` | The whole tip row is tinted. The subtitle ("Un café para el mantenimiento") is light blue on white, about 2.6:1, which fails WCAG AA. The row looks like a link, not a purchase. | Contrast (AA). Native first. | In `TipRow` (`App/SupportViews.swift`), make the title `.primary` and the subtitle `.secondary`, and show the price as a `.borderedProminent` capsule button on the trailing side. |
| A10 | Major | `*/large-04-historico.png`, `*/large-05-historico-1988.png`, `ipad-portrait/large-01-ahora.png` (Tiempo real chart) | `RecentChart`, the outflow chart and the history charts cap Dynamic Type at `.xLarge`. At AX sizes the axis labels stay about 11 pt while the text around them is 40 pt or more. There is no alternative way to read the series. | Dynamic Type, accessibility. | Keep the cap, but add `accessibilityChartDescriptor` (Audio Graph) to every `Chart`. At AX sizes, also show the first, last, minimum and maximum points as `LabeledContent` rows under each chart. |
| A11 | Major | `ipad-portrait/light-01-ahora.png` (outflow chart, left column) and the dark variant | The "Caudal desembalsado" chart has no series name. It shows a step of about 20 m³/s between 18:00 and 21:00, while the rows above it say 1,20 m³/s (river) and 5,76 m³/s (Valmayor). The reader cannot tell which flow is drawn. | The figure carries its meaning. Craft. | In `OutflowSection`, title the chart "Salida al río, últimas 24 h" and add a `RuleMark` with annotation at the current value. If both flows matter, draw two series with a legend. |
| A12 | Major | `iphone-69/light-01-ahora.png`, `iphone-compact/light-01-ahora.png`, `duo-outer/light-01-ahora.png` | The hero is 280 pt tall, and at 46,8 % the top 55 % of it is an empty pale gradient. The number sits in the lower half, under 150 pt of nothing. At dark mode the empty sky is a flat navy slab. | Hierarchy, beauty. | Until 2.0 replaces the hero, put the reservoir context in the sky ("Embalse de San Juan · río Alberche") or cut the card height to `max(180, …)` at 40–60 %. 2.0 makes this moot (see Implications). |
| A13 | Minor | `*/light-02-boletin.png`, `*/dark-02-boletin.png`, `*/large-02-boletin.png` | The capture is scrolled so the "Boletín semanal" header sits ghosted under the navigation bar. The section starts headerless, so the MITECO/SAIH boundary is not visible in the screenshot. | Source and date always visible; capture framing. | In `scripts/capture-matrix.sh`, scroll so each section header sits 16 pt below the bar (scroll to the header, not to the first row). |
| A14 | Minor | `*/light-01-ahora.png` (Tiempo real chart) | The 24 h chart has no marker for "now". The last hour has no label, and the tick hours change between captures (11:00/17:00/23:00/05:00 vs 12:00/18:00/00:00/06:00). | Glanceability. | In `RecentChart`, add a `PointMark` on the last reading with an annotation ("64,47 · 11:00"). Align `AxisMarks` to fixed hours (00, 06, 12, 18). |
| A15 | Minor | `iphone-69/light-04-historico.png` (ene abr jul oct), `iphone-compact/light-04-historico.png` (feb may ago), `ipad-portrait/light-04-historico.png` (feb may ago nov) | Month ticks change by device, there is no year anywhere on the "1 año" chart, and the 1988 chart has no label for 1988 or for today. | Consistency across formats. | In `HistoryView`, use explicit `AxisMarks(values:)`: the start date with its year, quarter ticks, and "hoy" at the end. |
| A16 | Minor | `*/light-04-historico.png`, `*/light-05-historico-1988.png` | About 60 pt of dead space between the segmented control and the chart, and the lower 35–55 % of the screen is empty on every phone. | Spacing rhythm. | In `HistoryView`, remove the extra top padding on the chart card and let the chart take `containerRelativeFrame(.vertical) * 0.45`. |
| A17 | Minor | `iphone-69/light-07-sugerencias.png`, `iphone-compact/light-07-sugerencias.png`, `ipad-portrait/light-07-sugerencias.png`, `duo-outer/light-07-sugerencias.png` | The `TextEditor` is empty, with no placeholder and no minimum stated ("0 de 1000 caracteres." but 3 are required). | Craft; empty states. | In `SuggestionView`, add a placeholder overlay ("Cuéntanos qué mejorarías…") and change the counter to "0 de 1000 (mínimo 3)". |
| A18 | Minor | `iphone-69/light-06-ficha.png`, `ipad-portrait/light-06-ficha.png` (Fuentes rows) | The source rows put a tinted caption subtitle (about 3:1) under tinted titles. Ficha omits capacity (138 hm³) and maximum elevation, the two facts that give the percentage meaning. | Contrast. Completeness. | In `AboutView`, make the subtitles `.secondary` and add "Capacidad 138 hm³" and "Cota máxima" rows to Ficha. |
| A19 | Minor | `iphone-compact/large-08-propinas.png` ("mantenimien-to."), `duo-outer/large-08-propinas.png` | Hyphenation inside the explanatory paragraph at AX sizes. | Craft. | Not worth a workaround in 1.0. In 2.0, shorten the copy ("Gratis siempre. Una propina ayuda a mantenerla."). |
| A20 | Minor | `*/light-01-ahora.png`, `*/dark-01-ahora.png` | The source line "SAIH Tajo, 7 nov, 11:00. Dato provisional." sits outside the card in footnote grey, visually detached from the number it qualifies. | Every figure shows its source; hierarchy. | Put the source inside the card's bottom edge in white at 0.8 opacity, or directly under the trend line. |
| A21 | Idea | `*/light-02-boletin.png` | The MITECO block lists last year (72 hm³) and the 10-year average (56,9 hm³) without comparing them to this week. That comparison is what people want. | — | Add "7 hm³ menos que hace un año" and "8 hm³ por encima de la media" as the first line of the block. |
| A22 | Idea | `*/light-01-ahora.png` | The title "San Juan" is also a town, a saint and a dozen other reservoirs. | — | Title "Embalse de San Juan" (inline) or a large title "San Juan" with a subtitle "Embalse · río Alberche". |
| A23 | Idea | `*/light-06-ficha.png` | "Usos" is seven plain list rows that look tappable and say little. | — | Render the uses as a flow of SF Symbol chips in one row. |

## B. iphone-69 (iPhone 18 Pro Max)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| B1 | Blocker | `iphone-69/light-04-historico.png`, `iphone-69/dark-04-historico.png`, `iphone-69/large-04-historico.png` | "Mínimo 66,9 hm³, oct 2026" and a curve that ends around 67 hm³, while the hero in the same run says 64,51 / 64,47 hm³. So the period minimum is higher than today's value, and the history stops days before the snapshot. (The compact run shows 64,3 hm³ in nov, so this is cached or stale history, not a fixture.) | Wrong data. Trustworthy. | In `HistoryView`, append `snapshot.live` as the last point of the 1-year and 5-year series before computing the minimum, maximum and mean. Add "Hasta el 7 nov, 11:00" to the footer. Invalidate the cached history when it is older than the snapshot by more than one day. |
| B2 | Major | `iphone-69/dark-07-sugerencias.png` (also `ipad-portrait/dark-07-sugerencias.png`) | With 0 characters typed, the send button in dark mode shows a bright white glyph, so it looks enabled. Light mode and the compact and Duo captures show it greyed. | Platform conventions: a disabled state must look disabled. | In `SuggestionView`'s toolbar, keep `.disabled(!isValid)` and also set `.foregroundStyle(isValid ? .primary : .tertiary)` on the glyph, so the glass button can't render white over dark. |
| B3 | Major | `iphone-69/light-01-ahora.png` (09:00, 64,51, "Subiendo") vs `iphone-69/dark-01-ahora.png` (11:00, 64,47, "Estable"); `light-02` (radiation 77 W/m²) vs `dark-02` (393 W/m²); every capture: status bar 09:41 with data at 11:00 | One format's captures mix data from different moments, and the data is "from the future" relative to the clock. These become store screenshots. | Consistency. Store-screenshot accuracy. | In `scripts/capture-matrix.sh` and `scripts/export-screenshots.sh`, launch with the shared fixture (`contract/fixtures/snapshot.json`) and a status-bar override one hour after its `observedAt`, for every mode. |
| B4 | Minor | `iphone-69/large-04-historico.png` | The segmented control barely grows at AX sizes ("1 año / 5 años / Desde 1988" stays near 17 pt) while the headings are 40 pt. | Dynamic Type. | At AX sizes, replace the segmented `Picker` with `.pickerStyle(.menu)` in the toolbar, or with three full-width rows. |

## C. iphone-compact (iPhone 17e)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| C1 | Major | `iphone-compact/large-02-boletin.png`, `iphone-compact/large-03-alberche.png` | The narrowest phone shows A2 and A3 at their worst: values in three lines ("70,9 / hm³"), percent orphaned ("(47,1 / %)"), names hyphenated. Only one reservoir fits per screen. | Dynamic Type. | Covered by A2 and A3. Verify on this device first: if it works at 375 pt with AX5, it works everywhere. |
| C2 | Minor | `iphone-compact/light-01-ahora.png` | The first screen shows the hero, the Tiempo real chart and "Cota"/"Nivel". Outflow, the MITECO block and the river are all below the fold, so the hero plus a 24 h chart take the whole first impression. | Hierarchy (the one question, then context). | Acceptable for 1.0. In 2.0 the three-section structure fixes it (see Implications). |
| C3 | Minor | `iphone-compact/large-08-propinas.png` | "mantenimien-to." is hyphenated in the tip explanation. | Craft. | See A19. |

## D. ipad-portrait (iPad Pro 13-inch)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| D1 | Blocker | `ipad-portrait/large-01-ahora.png` | The source line is truncated to "SAIH Tajo, 7 nov, 11:00…." and loses "Dato provisional". In the right column, "Temperatu-" is hyphenated and "9,1 °C" is clipped at the card's trailing edge. | Clipped content. Source and date always visible. | In `HeroFooter` (cards style), remove any `lineLimit` and use `.fixedSize(horizontal: false, vertical: true)`. In `WeatherRow`, switch to a `VStack` at AX sizes (as in A3) and give the value `layoutPriority(1)`. |
| D2 | Major | `ipad-portrait/light-01-ahora.png` | The hero is about 230 pt tall on a 1376 pt screen and the percentage about 64 pt. The MITECO block in the right column starts at the same height with the same visual weight, so the one number competes with "65 hm³ (47,1 %)" beside it. | The one question. Layout by size class. | In `DashboardColumns` (`App/Dashboard.swift`), on regular width put the hero above both columns at full width and at least 40 % of the viewport height, with the percentage at 120 pt or more. Start the right column with the river, not with MITECO. |
| D3 | Major | `ipad-portrait/light-01-ahora.png`, `ipad-portrait/dark-01-ahora.png` | The columns are unbalanced. The left one ends near 910 pt and leaves a 220 pt hole above the screen edge, while the right one runs to the bottom and is cut off. | Alignment, optical balance. | Rebalance the sections in `ReservoirScreen` by estimated height (move Weather to the left column), or use a two-column `Grid` that aligns section tops in rows. |
| D4 | Major | `ipad-portrait/light-04-historico.png`, `light-05-historico-1988.png`, `light-06-ficha.png`, `light-07-sugerencias.png`, `light-08-propinas.png` (all modes) | Secondary screens are a full-width phone list on a 13-inch screen. Stat labels and values sit 780 pt apart. The segmented control is small and left-aligned. The history chart is about 4:1 and the lower 55 % of the screen is empty. The tip and suggestion forms float at the top of a blank page. | Layout by size class (HIG readable content width). | Constrain `HistoryView`, `AboutView`, `SuggestionView` and `TipJarView` to a readable width of about 680 pt, centred, on regular width. In `HistoryView`, put the chart (at least 50 % of the height) and the stats side by side. |
| D5 | Major | `ipad-portrait/light-02-boletin.png`, `ipad-portrait/light-03-alberche.png` (all modes) | Both captures are identical to `light-01-ahora.png`. The capture never scrolled, so the bottom of the dashboard ("Ayuda a mejorarla", the suggestion and tip links) and the end of the right column were never reviewed on iPad. | An unreviewed format is a risk. | In `capture-matrix.sh`, scroll the regular-width dashboard by viewport height for 02 and 03, and assert the two images differ. |
| D6 | Minor | `ipad-portrait/light-01-ahora.png` | "Últimas lecturas", "Histórico desde 1988" and "Ficha y fuentes" are tinted blue on iPad and primary on iPhone. | Consistency across formats. | In `DashboardSection` for the cards style, apply `.foregroundStyle(.primary)` to `DisclosureGroup` and `NavigationLink` labels, keeping the chevron tinted. |
| D7 | Minor | every `ipad-portrait/*.png` | The status bar reads "Sat 7 Nov" (English region) above a Spanish interface. | Store screenshots. | Capture with `-AppleLanguages (es) -AppleLocale es_ES` and the simulator region set to Spain. |
| D8 | Minor | `ipad-portrait/light-06-ficha.png` | "Fuentes" rows are three lines of tinted text at caption size; the "App personal, sin relación…" notice is 11 pt grey across 1000 pt. | Contrast, readable width. | See A18 and D4. |
| D9 | Idea | `ipad-portrait/light-01-ahora.png` | The iPad has room to show the river as what it is: three reservoirs in a row, upstream to downstream, with water drawn in each. | — | Make the "Río Alberche" section a horizontal triptych of three small water cards on regular width. |

## E. duo-outer (iPhone Duo, closed)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| E1 | Blocker (coverage) | `MANIFEST.txt` ("SKIPPED duo-inner") | The inner display, where the fold must fall in the gap between the columns and no control may sit on it, was not captured. The `CLAUDE.md` rule that is easiest to break is unverified. iPad landscape is missing too. | The app's own rule. An unreviewed format is a risk. | Open iPhone Duo in Device Hub and run `scripts/capture-matrix.sh --duo-inner` and `--ipad-landscape` before any 2.0 layout work. Add an assertion that `reservedRegions` puts the fold inside the column gap. |
| E2 | Major | `duo-outer/light-04-historico.png` | Captured mid-load: a spinner inside an empty capsule where the picker should be, and nothing else. The picker only appears after loading, so the layout jumps. | Empty and loading states. | In `HistoryView`, always show the `Picker`, and under it a chart-sized placeholder with `.redacted(reason: .placeholder)` while loading. Make the capture wait for the chart. |
| E3 | Major | `duo-outer/light-04-historico.png` to `light-08-propinas.png` (all modes) | The back button (and the send button on Sugerencias) sits in the right-hand status column under the clock and battery ring, 300 pt away from the left-aligned title. It reads as system status, not navigation. | Platform conventions: navigation where the user expects it. | Check against the iOS 27.1 Duo outer-display guidance. If the system places toolbar items in the side bar, keep it. If it comes from the app's toolbar placement, use `.topBarLeading` for back and `.confirmationAction` for send. |
| E4 | Minor | `duo-outer/light-01-ahora.png` | The content column is left-heavy: about 110 pt of the width goes to the status column, and the cards don't use the spare height for anything. | Optical balance. | Nothing to change in 1.0 beyond A12. In 2.0 the full-screen water fills this display edge to edge. |

## F. watch-large (Ultra 4, 49 mm) and watch-small (SE 3, 40 mm)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| F1 | Major | `watch-large/large-01-ahora.png` to `large-03-datos.png`, `watch-small/large-01-ahora.png` to `large-03-datos.png` | Every "large" capture matches its default capture in layout and size. Either the watch app ignores the text size or the capture never applied it. | Dynamic Type. An unreviewed mode is a risk. | Check in `capture-matrix.sh` that the content size category is applied (`simctl ui … content_size`). If it is applied, the 42 pt fixed percentage in `WatchHeroPage` must become `@ScaledMetric`. |
| F2 | Major | `watch-large/light-01-ahora.png`, `watch-small/light-01-ahora.png` | The hero shows "→ 64,5 hm³" and "11:00". The trend is a bare arrow with no word or amount, which reads as "towards 64,5". The time has no source and no date. | The one question (rising or falling). Every figure shows its source and date. | In `WatchHeroPage`, show "Estable · 64,5 hm³" (with the arrow) and "SAIH · 11:00", or "SAIH · 7 nov" after midnight. |
| F3 | Major | `watch-large/light-02-curva.png`, `watch-small/light-02-curva.png` | "113" floats at the top right and "64" at the bottom right, with no unit. The curve is at 113 on the left, not where the label is. There is no time axis and no capacity reference, so the drop looks like a collapse to zero. | Glanceability, craft. | In `VolumeChart` (`EmbalseKit/Views/WidgetViews.swift`), replace the trailing y-axis labels with annotations on the first and last points ("113 hm³" at the start, "64 hm³ · hoy" at the end). Use a 0…capacity domain, or show the floor value. |
| F4 | Major | `watch-large/light-03-datos.png`, `watch-small/light-03-datos.png` | "Caudal" here is "Salida al río" on iPhone. "Cota 565,4 m" here is 565,45 m on iPhone. The "SAIH Tajo" header has no time. | Consistency across formats. Source and date. | In `WatchDetailsPage`, use the iPhone labels and the shared precision (A5), and make the header "SAIH Tajo · 11:00". |
| F5 | Major | `MANIFEST.txt`, `watch-*` | The watch complications (circular, corner, rectangular, inline) listed in the spec were not captured. The MITECO section of the data page is below the fold and was not captured either. | An unreviewed format is a risk. | Add the complications from `EmbalseWatchWidgets` to `WidgetSnapshotTests`, and add a scrolled capture of page 3. |
| F6 | Minor | `watch-small/light-01-ahora.png` | On 40 mm the page dots sit in the trailing margin right next to "San Juan", and the reading block hugs the leading edge (6 pt padding). | watchOS margins. | Use the system `scenePadding()` instead of `.padding(.horizontal, 6)` in `WatchHeroPage`. |
| F7 | Minor | `watch-large/light-02-curva.png` | The chart page switches to a flat blue gradient, so the water from page 1 disappears when you swipe. | Consistency. | Keep `WidgetWaterScene` as the background of page 2 at low opacity. |
| F8 | Idea | `watch-large/light-01-ahora.png` | This is the most beautiful screen in the app: water to the edge, one number. | — | Use it as the model for the 2.0 iPhone hero, not the other way round. |

## G. widgets-ios

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| G1 | Blocker | `widgets-ios/light-small-stale.png` | The stale header reads "⚠ 30…": the date is truncated. In the stale state the date is the one piece of information the widget must show. | Source and date always visible. Clipping. | In `WidgetHeader`, give the stale date `layoutPriority(2)` and `fixedSize()`, and let the name truncate first. Better: move the notice into the reading line under the percentage ("⚠ Dato del 30 oct"), replacing the trend. |
| G2 | Major | `widgets-ios/light-small.png`, `dark-small.png`, `light-medium.png`, `light-large.png`, `light-xl.png` | The trend is only an arrow glyph, with no word and no amount. "→ 67,0 hm³" reads as "towards 67". | The one question (rising or falling). | In `WidgetReading`, render "→ Estable · 67,0 hm³" on medium and larger, and keep only the arrow on small but follow it with the 24 h delta when it is not steady ("↘ −0,4"). |
| G3 | Major | `widgets-ios/light-medium.png`, `dark-medium.png`, `light-large.png`, `dark-large.png`, `light-xl.png` | "Boletín 70 hm³", "Hace un año 75 hm³" and "Media de 10 años 57,5 hm³" are MITECO figures shown next to the SAIH 67,0 hm³, with no source or week. Nothing tells the reader that 70 and 67 are different measurements of the same week. | Never mix SAIH and MITECO; always show the source and date. | In `MediumWidgetView`, `LargeWidgetView` and `ExtraLargeWidgetView`, group the `WidgetStat`s under one caption "MITECO · 3 nov", or title the stat "MITECO 3 nov" instead of "Boletín". |
| G4 | Major | `widgets-ios/light-large.png`, `dark-large.png`, `light-xl.png` | `VolumeChart` scales the curve to its own minimum and maximum, so the line plunges deep into the water and ends at "68" far below the 48,7 % waterline. Two encodings of the same quantity contradict each other in one picture. | Consistency; one full-bleed surface. | Either draw the curve on a 0…capacity y-domain, so its last point lands on the waterline and the curve reads as the shoreline's history, or keep it in a band above the water with its own baseline. The first fits the 2.0 direction. |
| G5 | Major | `widgets-ios/light-medium.png` ("72", "68"), `light-large.png` ("84", "68"), `light-xl.png` | Curve labels have no unit, and the top label sits at the right edge while the value it names is on the left. | Units, craft. | Same fix as F3: annotate the first and last points with "84 hm³" and "68 hm³". |
| G6 | Major | `widgets-ios/light-lock-circular.png` | The circular widget shows "49" with no "%". Every other surface shows 48,7 %. | One number style. Units. | In `CircularLockWidgetView`, show `Format.number(percent, decimals: 1)` with `.minimumScaleFactor(0.6)`, and a small "%" under it if it fits. If it doesn't, at least "49 %". |
| G7 | Minor | `widgets-ios/light-medium-smallest.png` ("68" on the crest), `light-large-smallest.png` ("84" on the crest), `light-xl.png` ("Boletín" on the waterline) | Labels sit exactly on the wave crest, where the lighter crest band lowers their contrast. | Nothing cut at the waterline. | In `WidgetWaterScene` layouts, keep text at least 8 pt from the crest band; move chart labels inside the plot. |
| G8 | Minor | `widgets-ios/light-small-8.png`, `light-small-30.png`, `light-small-62.png`, `light-small-97.png` | All four levels show "67,0 hm³", which is impossible at 8 % and 97 %. The snapshot tests can't catch a mismatch between number and level. | Test fidelity. | In `WidgetSnapshotTests`, derive the volume from the percentage (`capacity * p / 100`). |
| G9 | Minor | `widgets-ios/light-medium.png` | "16:00" floats between the title and the curve, aligned to nothing. | Alignment. | In `MediumWidgetView`, put the time under the name (caption2, secondary) or at the trailing edge of the header row. |
| G10 | Minor | `widgets-ios/tinted-small.png`, `tinted-medium.png` | In tinted mode the water becomes a flat grey-lavender slab under a navy sky. The wave and the curve's fill vanish, so it reads as a progress bar. | Widget rendering modes. | In `.accented` rendering mode, draw the water in the accent colour at about 0.35 opacity with the wave line at full accent, and mark the percentage `.widgetAccentable()` (already done). |
| G11 | Minor | `MANIFEST.txt`, `widgets-ios/` | Missing: dark lock screen, StandBy, clear mode, tinted large and XL, dark XL, and any widget at a large text size. | An unreviewed mode is a risk. | Add these families and modes to `WidgetSnapshotTests`. |
| G12 | Idea | `widgets-ios/light-xl.png` | The XL shows "Burguillo 37,9 %" with no Picadas, and "Lluvia en 24 h 0,0 mm" with no place. Its right half is mostly empty sky. | — | Use the XL for the river: three water columns (Burguillo, San Juan, Picadas) at their own levels, with San Juan large. |
| G13 | Idea | `widgets-ios/light-lock-rectangular.png` | The rectangular widget puts the trend arrow at the end of the line, after the volume, and leaves its bottom third empty. | — | Two lines: "San Juan → Estable", then "48,7 % · 67,0 hm³" with the bar as the baseline. |

---

## Keep

- The water drawn at the real level, full-bleed, with white text on widgets and watch (`widgets-ios/light-small-8.png` to `light-small-97.png` show the level is honest at every fill).
- The MITECO footnote "Es otra medición y no coincide con el dato en tiempo real." (`*/light-02-boletin.png`).
- `LabeledContent` stacking label over value at AX sizes in the Boletín, Tiempo en la presa and Ficha sections (`*/large-02-boletin.png`, `*/large-06-ficha.png`).
- The "Río Alberche" order, upstream to downstream, with capacity bars and San Juan in bold (`*/light-03-alberche.png`).
- Spanish formatting through `Format` with `es_ES`, including the real minus sign in `Format.signed`.
- The watch hero page as a composition (`watch-large/light-01-ahora.png`).
- Dark mode as a genuine dark palette, not an inversion (`*/dark-*.png`).

---

## Implications for 2.0

The agreed direction is full-screen water at the real level that moves with the device; three sections (Ahora, Este año, El río); Liquid Glass; a palette that follows how full the reservoir is; and one number style across app, widgets and web. Below are the ten requirements per format that this audit says the redesign must meet. Each one cites the findings it comes from.

### iPhone (6.9" and compact, and Duo outer)

1. **Text never straddles the waterline.** Every text block sits wholly in the water or wholly above it. Its colour comes from where it sits, not from a mask (A1). At AX sizes, the percentage stays on the water and everything else moves onto glass panels below.
2. **The first screen answers the question in under two seconds and nothing else competes.** "Ahora" shows the percentage, "64,5 hm³ de 138 hm³", the trend as a word plus amount, and the source and time, all within the first viewport on a 375 pt phone at the default size and readable at AX5 (A4, A12, C2).
3. **One number style, defined once in `Format` and in the web.** SAIH volume 1 decimal, MITECO 0 decimals, percent 1 decimal, elevation 2 decimals, a no-break space before every unit, and the real minus sign. It is enforced by a shared test fixture that the Swift, Kotlin and web tests all assert (A2, A5, G6).
4. **The trend is a word, a direction and an amount, with the noise threshold explained.** "Estable" is never printed next to "+0,19" without context (A4, F2, G2).
5. **Every figure carries its source and time in the same glass element as the figure.** No orphan footers. SAIH and MITECO never share a panel, and their panels look different (for example, MITECO panels always carry a "semanal" badge) (A6, A20, G3).
6. **The full-screen water has a static fallback.** With Reduce Motion on, the device-tilt motion is off and the waterline stays readable. With Increase Contrast on, the sky and water contrast is at least 3:1, and text on either is at least 4.5:1 in every palette state (A1, A9).
7. **The fill-level palette is legible at the extremes.** At 8 % (mostly sky) and 97 % (mostly water), and in light, dark and Increase Contrast, glass and text must pass AA. Verify with the same 8/30/62/97 % fixtures, with volumes that match the level (G8).
8. **"Este año" charts are honest and self-explaining.** "Today" is always the last point, the period statistics include it, values above capacity are explained, there are year labels and a "hoy" marker, and every chart has an Audio Graph descriptor and a text summary at AX sizes (B1, A7, A10, A14, A15).
9. **"El río" adapts to AX sizes without hyphenation.** Names on their own line, values in one non-breaking unit, and the three reservoirs readable at AX5 on 375 pt (A3, C1).
10. **Captures are deterministic.** One fixture, one clock, the Spanish region and storefront ("0,99 €"), section headers in frame, and every mode captured. This is a requirement because the 2.0 store screenshots come from it (A8, A13, B3, D7).

### iPad (regular width)

1. **The water fills the whole window, and "Ahora" is at least 40 % of the viewport height,** with the percentage at 120 pt or more. Columns start below it, never beside it (D2).
2. **The three sections are columns or a sidebar on regular width,** not a stretched phone list. "Ahora", "Este año" and "El río" can sit side by side in landscape and two plus one in portrait (D3, D4).
3. **Secondary content has a readable width of about 680 pt,** centred over the water, and no screen is more than 40 % empty (D4).
4. **Columns are balanced by content, not by order.** No column ends more than 10 % of the viewport above the other (D3).
5. **"El río" uses the width:** three reservoirs side by side, each with water at its own level and the palette following each one's fill (D9).
6. **History charts are at least 50 % of the viewport height,** with the statistics beside them, not under them (D4).
7. **Liquid Glass panels keep their contrast over a full-bleed animated background** at iPad sizes, where a panel can be 600 pt wide over both sky and water (A1, D8).
8. **AX sizes never truncate a source line or clip a value at a card edge** (D1).
9. **Link and row styling matches iPhone.** Tint marks actions only, not navigation labels (D6).
10. **iPad landscape and Split View are captured and reviewed** before the layout is approved (MANIFEST, E1).

### iPhone Duo (inner display, plus outer)

1. **Capture and review the inner display first.** No 2.0 layout is approved without `duo-inner` captures in light, dark and large (E1).
2. **The fold falls in the gap between the two sections,** measured from `reservedRegions`, and no control, label, chart annotation or number crosses it (CLAUDE.md, E1).
3. **The water is continuous across the fold.** The waterline is one line across both halves at the same height, so the fold doesn't read as two reservoirs.
4. **The layout uses size class only.** Duo open uses the regular layout and Duo closed the compact one, with no idiom checks (CLAUDE.md).
5. **Navigation on the outer display is where the system puts it,** confirmed against the 27.1 guidance and never next to the battery ring by accident (E3).
6. **The left half is "Ahora" and the right is "Este año" or "El río",** so opening the device reveals context without moving the number.
7. **The segmented control or section switcher stays on one side of the fold** (CLAUDE.md).
8. **Loading states keep the layout:** pickers are always present and charts use placeholders, so nothing jumps across the fold (E2).
9. **Motion with the device tilt is computed for each half's orientation,** so the water doesn't slope one way on one panel and the other way on the other.
10. **The 27.1 APIs are behind `#available`,** and the 27.0 fallback is reviewed on a regular-width iPad as the stand-in.

### Apple Watch

1. **The hero stays a full-screen water page with one number.** 1.0's watch hero is the reference for the other formats (F8, Keep).
2. **The trend is a word plus arrow, and the time carries its source** ("SAIH · 11:00", or a date after midnight) (F2).
3. **Dynamic Type is honoured and verified.** The percentage uses `@ScaledMetric`, and large captures must differ from default ones (F1).
4. **The 90-day curve has a unit, start and end annotations at the right points, and a capacity reference,** or a 0…capacity domain (F3).
5. **The same labels and precision as iPhone** ("Salida al río", 565,45 m) (F4, A5).
6. **The fill-level palette works on true black,** since the watch's sky is OLED black and the low-level states must still read as water.
7. **System margins and page indicators are respected on 40 mm** (F6).
8. **Water continuity across pages:** the curve and data pages keep the water as their ground (F7).
9. **Complications (circular, corner, rectangular, inline) are captured and reviewed** in every rendering mode, with the same number style (F5, G6).
10. **Stale and offline states are designed:** an orange stale banner with the full date, never truncated, on every page (G1 applied to the watch).

### Widgets (Home Screen, StandBy, Lock Screen)

1. **Keep one full-bleed surface with white text.** 2.0's Liquid Glass must not reintroduce panels or two-tone text inside widgets (CLAUDE.md, Keep).
2. **The stale state shows its full date, always.** The date has the highest layout priority in every family (G1).
3. **The trend is legible as a word on medium and larger, and arrow plus delta on small** (G2).
4. **MITECO figures are labelled "MITECO" with their week,** and grouped apart from SAIH (G3).
5. **The curve and the water agree.** The curve's last point lands on the waterline (0…capacity domain), or the curve lives in its own band (G4).
6. **Every chart label has a unit and sits at the point it names** (G5).
7. **The same number style as the app.** The circular complication shows 48,7, not 49 (G6, A5).
8. **Text keeps 8 pt clear of the wave crest** at the smallest family sizes (G7).
9. **Tinted, clear and StandBy have their own designs.** In accented mode the water stays recognisable as water, and the fill-level palette degrades gracefully to the system tint (G10, G11).
10. **The snapshot tests use honest fixtures** (volume matching the level) for every family and mode, including dark lock screen, StandBy and large text. `make widgets` output is reviewed against this list before shipping (G8, G11).
