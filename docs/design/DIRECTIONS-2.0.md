# Embalse San Juan 2.0: three design directions, adversarial comparison

Reviewer: `ux-adversary`. Date: 2026-11-07.
Input: `build/design/{A-superficie,B-vaso,C-horizonte}/*.png`, rendered by
`ios/EmbalseKit/Tests/EmbalseKitTests/DesignPrototypeTests.swift` from `contract/fixtures/snapshot.json`
(SAIH 67,03 hm³, 48,66 %, +0,12 hm³ in 24 h, 30 oct 16:00; MITECO week of 27 oct 70 hm³, last year 75, 10-year 57,5;
one neighbour, Burguillo 37,87 % observed 30 oct **17:00**). The 90-day and yearly curves are synthetic.
The bar is the "Implications for 2.0" sections of `AUDIT-1.0-apple.md` (cited as *Apple iPhone 1*, *Apple iPad 3* …)
and `AUDIT-1.0-android.md` (cited as *Android phone 1* …), plus the rules in `CLAUDE.md`.

Glass is judged by intent, since `ImageRenderer` draws it as a translucent fill. Large text is reasoned from the code,
since every render is at the default size.

## Verdict

None of the three is shippable as drawn. Each has at least one Blocker in its own central idea. **A (Superficie) is the
right base.** It is the 1.0 watch hero (the reference the Apple audit asked every format to follow) scaled up. It obeys
the one-surface widget rule as it stands and keeps SAIH and MITECO apart. **A's worst problem is structural: the
number, the volume, the trend, the MITECO panel and the section switcher all have to fit inside the water.** At low
levels (the drought months, when people check most) and at accessibility sizes, they cannot. At 8 % the water on a
402 × 874 pt iPhone is about 70 pt tall, and the stack needs about 330 pt at the default size. A needs a defined
fallback before it is built.

B (Vaso) breaks the app's own rules at its core. It draws MITECO markers on SAIH water, and its widgets go back to a
light panel with black text. C (Horizonte) is the most striking on iPhone. But its water overstates today's level,
it shows two contradicting trends, its labels straddle the waterline, and it leaves no room for the number when the
90-day maximum is high.

## Coverage gaps (findings in themselves)

| # | Severity | Missing | Why it matters |
|---|---|---|---|
| G1 | Major | No `large` (AX5) mode in any direction | Text size is the main thing that separates the three (see "Accessibility" below). It is reasoned here, not seen. |
| G2 | Major | No levels other than 48,7 % (8, 30, 62, 97 %) | A and C fail at the extremes by construction (*Apple iPhone 7*, *Android phone 1*). |
| G3 | Major | No Android, foldable postures, Wear, tablet portrait, compact iPhone, Duo outer, `duo-inner-dark` | Android will mirror the choice. Material 3 fit is reasoned, not seen. |
| G4 | Major | Widgets only in light. No dark, tinted, clear, StandBy, lock screen or complications | *Apple widgets 9*: tinted and accented modes are where B's and C's water would degrade first. |
| G5 | Minor | No scrolled state (below the fold) and no "Este año" or "El río" pages for A and C | The section switcher shows tabs whose content is not designed. |
| G6 | Minor | Stale, offline and loading states absent | *Apple widgets 2*, *Apple Watch 10*. |

---

## A · Superficie

### iphone (`A-superficie/iphone-light.png`, `iphone-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| A1 | Blocker | iphone-light, iphone-dark (by construction) | Every figure lives in the water (`SurfacePhone`, `.padding(.top, waterline + 26)`). At 8 % the water is about 70 pt, and the stack (92 pt figure, volume, trend, MITECO glass at 76 pt, tabs at 48 pt) needs about 330 pt. At 20 % it still clips. | *Apple iPhone 1, 2*; *Android phone 1, 2* | Add a placement rule in `SurfacePhone`. If `waterHeight < neededHeight`, the whole "Ahora" block moves into the sky as one block in `.primary`, clear of the crest by 12 pt. Below 25 % it always sits in the sky. Snapshot it at 8/30/62/97 %. |
| A2 | Major | iphone-light | The MITECO glass ("Hace un año 75 hm³ / Media 10 años 57,5 hm³") has no week date. It says "MITECO semanal" but not *which* week, and this week's MITECO figure (70 hm³) is missing. Compared with SAIH's 67,0 just above it, a reader concludes "8 hm³ below last year". The real MITECO-to-MITECO gap is 5 hm³. | `CLAUDE.md` "never mix SAIH and MITECO"; *Apple iPhone 5* | Make the panel a three-figure MITECO row: "Esta semana 70 hm³ · Hace un año 75 hm³ · Media 10 años 57,5 hm³", with a "MITECO · semana del 27 oct" header inside the glass. Never show the year comparisons without MITECO's own current figure. |
| A3 | Major | iphone-light, iphone-dark | The SAIH source line sits in the sky, about 22 pt above the crest. The figure it describes sits 26 pt below it, in the water. The source is not in the same element as the figure. | *Apple iPhone 5* | Move "SAIH Tajo · 30 oct, 16:00" directly under the trend line, in the water, in white at 0.8 opacity, 15 pt. The sky keeps only the name and "Río Alberche · Madrid". |
| A4 | Major | iphone-light | About 380 pt of sky is empty except the title. This is honest at 48,7 %, but the first screen spends 45 % of its height on nothing. | Craft, hierarchy | Keep the sky empty (it is the data), but put the section switcher at the top, under the title, as the system bar (see A5). The bottom of the water is then free for the "Este año" summary to peek above the fold. |
| A5 | Major | iphone-light, iphone-dark | `SectionTabs` is a hand-drawn capsule. On iOS 27 the three sections should be a system `TabView` (a Liquid Glass tab bar with SF Symbols) or a top segmented `Picker` in the toolbar. A custom pill won't get glass morphing, accessibility traits or the system tab bar's AX behaviour. | HIG, Liquid Glass (navigation layer); `CLAUDE.md` "native first" | Use `TabView` with three `Tab`s ("Ahora" `drop.fill`, "Este año" `calendar`, "El río" `water.waves`) and `.tabBarMinimizeBehavior(.onScrollDown)`. Delete `SectionTabs`. |
| A6 | Major | iphone-light | The MITECO comparison is drawn as a Liquid Glass *content* card. Apple's guidance puts Liquid Glass on the navigation and control layer, not on content. Glass content cards over an animated full-bleed background also go darker or lighter with what is behind them. | HIG Liquid Glass; *Apple iPad 7* | Draw content panels as a solid, translucent "water" material (white at 0.14 to 0.18 opacity, no refraction), and keep real `.glassEffect` for the tab bar, toolbar and refresh button. In the prototype only the name changes, but in code it is the difference between `glassEffect` and a fill. |
| A7 | Minor | iphone-light, iphone-dark | The back wave layer (`Water`, `.offset(x: -30)`) stops 30 pt short of the right edge. A visible step in the crest at x ≈ 372 pt. | Craft | Draw the back layer 60 pt wider than the frame (`.frame(width: w + 60)`) before offsetting, in `Water` and in `WaveShape` in the app. |
| A8 | Minor | iphone-light | The trend "→ Estable · +0,12 hm³ en 24 h" does not explain why +0,12 is "stable". | *Apple iPhone 4* | Add the threshold to the accessibility label and to a one-time info popover: "Estable: menos de 0,2 hm³ en 24 h". |
| A9 | Idea | iphone-light | The fill-level palette is barely visible: at 48,7 % the hue shift is less than 6 %. | *ROADMAP seasonal palette* | Either commit to it (test 8 % against 97 % side by side) or drop it. A colour change nobody notices costs contrast testing for nothing. |

### ipad-landscape (`A-superficie/ipad-landscape-light.png`, `ipad-landscape-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| A10 | Blocker | ipad-landscape-light, -dark | The top of "48,7 %" (130 pt) touches the crest. The left column is placed with `Spacer`s and `padding(.top, 44)`, not from `waterline`, so it lands on the wave by chance (about 8 pt clear with a 7 pt wave amplitude). | *Apple iPhone 1*; *Android phone 1* | Anchor the number to the waterline as on iPhone: `.padding(.top, waterline + 24)`. |
| A11 | Major | ipad-landscape-light, -dark | "Este año": this year (white) and last year (white at 0.7) look the same. The legend dots are also identical. The dashed 10-year line is grey on blue at about 2:1. | WCAG 1.4.11; *Apple iPhone 8* | On water, use white solid 3 pt for this year, a warm sand (#F5C26B) 2 pt for last year, and white 0.6 dashed for the average. Add year labels and a "hoy" dot. Or take B's solid card (see "Borrow" below). |
| A12 | Major | ipad-landscape-light | The chart has no y-axis, units or months. The whole curve uses a 0 to 138 domain in 150 pt, so the 17 hm³ yearly swing is about 18 pt. | *Apple iPhone 8*; *Apple iPad 6* (charts 50 % of height) | Show "Este año" at 50 % of the viewport height on its own tab, with month ticks, an hm³ axis and statistics beside it. The card here becomes a summary: three MITECO figures and a mini chart. |
| A13 | Major | ipad-landscape-light | "Ahora" is a left half, not a full-width band. The lower-left quadrant (about 600 × 380 pt) is empty water. The two cards are packed into the right half. | *Apple iPad 1, 2, 3* (columns below "Ahora", no screen more than 40 % empty) | Put the number centred, or left-aligned on the 1200 pt content margin, in a full-width band of the top 40 % of the water. Below it, three columns (Ahora details, Este año, El río) on the water. |
| A14 | Major | ipad-landscape-light | The "El río" card shows Burguillo and San Juan with one source line, "SAIH Tajo · 30 oct, 16:00". Burguillo was observed at 17:00. There is no outflow or weather, though the roadmap puts both in "El río". | *Apple iPhone 5*; ROADMAP "El río" | Give each reservoir its own time, or "SAIH Tajo · 30 oct" when the times differ. Add "Salida al río 1,21 m³/s" and "Trasvase 5,71 m³/s" (both in the fixture). |
| A15 | Minor | ipad-landscape-dark | The dark sky (#0D1424) and the dark water top meet with little contrast along the crest. The back wave is almost invisible. | *Apple iPhone 6* (3:1 sky and water) | Brighten the dark-mode water top by 10 % or add a 1 pt white 0.25 surface line. |
| A16 | Minor | ipad-landscape-light | Glass cards are 400 pt wide but their content uses half of it. "37,9 %" floats 330 pt from its name. | Craft | Cap the cards at 480 pt (*Android tablet 3*) or use the width: B's three mini tanks. |

### duo-inner (`A-superficie/duo-inner-light.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| A17 | Blocker | duo-inner-light | The "El río" card is clipped by the bottom edge. Only its top 8 pt shows. | Clipped content | The right half must scroll (`ScrollView`) or show one card per section with the switcher. Never a fixed `VStack` overflowing 669 pt. |
| A18 | Major | duo-inner-light | The top of the "Este año" glass card sits on the crest (about y 383). Half its border is in the sky and half in the water. The same glass then has two backgrounds, and real glass would show two tints. | *Apple iPhone 1*; *Apple iPad 7* | Start the right column at `waterline + 24`, as on iPhone. |
| A19 | Major | duo-inner-light | `duo-inner-dark` and `duo-inner-large` are missing. | *Apple Duo 1* | Render both. |
| Keep | | duo-inner-light | The waterline is one line across the fold, the fold falls in the 60 pt gap, and "Ahora" is on the left. | *Apple Duo 2, 3, 6* | |

### watch (`A-superficie/watch-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| A20 | Major | watch-dark | No volume. On the watch the one question gets only half its answer. | One question | Add "67,0 hm³" (15 pt rounded, white 0.85) between the percentage and the trend. Leave out "de 138 hm³" on 40 mm. |
| A21 | Major | watch-dark | "SAIH · 16:00" is hardcoded, and after midnight it would not say the day. | *Apple Watch 2* | Use `Format.dayMonthHour` when the observation isn't today. |
| A22 | Minor | watch-dark | Back wave step at x ≈ 185 pt (as A7). | Craft | As A7. |
| A23 | Minor | watch-dark | The figure is a fixed 44 pt (`figure(44)`). | *Apple Watch 3* | `@ScaledMetric(relativeTo: .largeTitle)`. |

### widgets (`A-superficie/widget-small-light.png`, `widget-medium-light.png`, `widget-large-light.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| A24 | Major | widget-large-light | The 90-day sparkline floats in the sky on its own scale (min − 4 … max + 4). Its last point is about 65 pt above the waterline, so the curve and the water disagree. It has no units and no end values. | *Apple widgets 5, 6*; *Android Glance 5* | Use C's surface here (see "Borrow"): the water's surface *is* the 90 days on a 0 to capacity domain, labelled "hace 90 días · 83,3 hm³" and "hoy · 67,0 hm³" in the water. |
| A25 | Major | all three widgets | No volume in any family, and "16:00" carries neither source nor date. | One question; *Apple widgets 2* | Medium and large: "67,0 hm³" under the figure and "SAIH · 16:00" top right (date when not today). Small: "67,0 hm³" instead of the delta when there is room, or the delta stays and the volume goes in the accessibility label. |
| A26 | Minor | widget-small-light | "→ +0,12 hm³" with a flat arrow reads as a contradiction without the word "Estable". | *Apple widgets 3* | Small: "→ Estable" if the threshold says stable, otherwise arrow plus delta. |
| A27 | Minor | widget-medium-light | The top half of the medium widget is empty navy (about 70 pt). | Craft | Put "SAIH · 30 oct, 16:00" and the volume in the sky line, so the top half earns its space. |
| Keep | | all widgets | One full-bleed surface, white text, figure wholly in the water. | `CLAUDE.md` widgets | |

---

## B · Vaso

### iphone (`B-vaso/iphone-light.png`, `iphone-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| B1 | Blocker | iphone-light, iphone-dark | The tank's water is SAIH (67,0 hm³). Its markers are MITECO ("Hace un año · 75 hm³", "Media 10 años · 57,5 hm³"). The figures are mixed in one element, on one scale, by design. MITECO's own figure this week (70 hm³) is *above* the SAIH water, so the picture says "8 hm³ under last year" when the like-for-like gap is 5 hm³. | `CLAUDE.md` "never mix SAIH and MITECO"; *Apple iPhone 5* | Either fill the tank with MITECO's 70 hm³ and label the tank "MITECO · semana del 27 oct" (so the tank becomes the "Este año" element, not "Ahora"), or remove the markers from the tank. As drawn it cannot ship. |
| B2 | Major | iphone-light | The marker ticks are 18 × 2 pt in `.primary` at 0.55 opacity. The 10-year tick sits in the water: black on dark blue, effectively invisible. The marker labels carry no source. | WCAG 1.4.11; *Apple iPhone 5* | Ticks span the full tank width as 1 pt dashed lines, white in the water and `.secondary` in the sky. Labels end in "· MITECO". |
| B3 | Major | iphone-light | "Estable" is in `Palette.waterTop` (#298FF5) on #F2F5FA: about 3,0:1. That fails AA for 17 pt semibold. It is also tint on a non-action. | WCAG 1.4.3; *Apple iPad 9* (tint marks actions only) | Trend in `.primary` with the SF Symbol in `.secondary`. |
| B4 | Major | iphone-light | The trend's amount is split from its word. "Estable" sits top right. "+0,12 hm³ en 24 h" is tacked onto the volume line in 15 pt grey. | *Apple iPhone 4* | One line under the figure: "→ Estable · +0,12 hm³ en 24 h". The volume goes on its own line in `.title3` and `.primary`. |
| B5 | Major | iphone-light | The source line sits under the tank, 380 pt from the figure it qualifies. | *Apple iPhone 5* | Put it directly under the volume and trend. |
| B6 | Major | iphone-light | The tank is 330 pt tall and says only what the number already says, plus the mixed markers. Without B1's markers it is a decorative progress bar taking 38 % of the screen. | One question (competes with the number) | If B is chosen, the tank must earn its space: 180 pt at most, with El río's neighbours as a second and third tank beside it. |
| B7 | Major | iphone-light | No section switcher, and El río is not reachable on the first screen. | ROADMAP three sections | `TabView` as in A5. |
| B8 | Minor | iphone-light | "Este año" chart has no axis, months, year labels or "hoy". | *Apple iPhone 8* | As A12. |
| B9 | Minor | iphone-dark | The tank's navy sky on a pure black page reads as a dark box. The light/dark split of the tank is weak (the sky is #0D1424, the water top #1F6FB0). | *Apple iPhone 6* | 1 pt white 0.3 surface line. Sky inside the tank at #141C2C. |

### ipad-landscape (`B-vaso/ipad-landscape-light.png`, `ipad-landscape-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| B10 | Major | ipad-landscape-light, -dark | The right column ends at about 520 pt of 1032. About 45 % of the window under "El río" is empty. | *Apple iPad 3, 4* (no column more than 10 % shorter; no screen more than 40 % empty) | Balance by content: "Este año" chart at 50 % height on the right, "El río" under "Ahora" on the left. Or three columns. |
| B11 | Major | ipad-landscape-light | The water does not fill the window. "Ahora" is a left column with a 640 pt tall tank, not a full-width band. | *Apple iPad 1*; ROADMAP "Full-screen water" | Structural to B. It can't be fixed without becoming A. |
| B12 | Major | ipad-landscape-light | The marker labels (12 pt caption) are tiny on a 640 pt tank. The B1 mixing is magnified. | As B1 | As B1. |
| B13 | Minor | ipad-landscape-light | "El río" mini tanks have no source or time. The back wave step shows at the right of each tank. | *Apple iPhone 5*; A7 | Add "SAIH Tajo · 30 oct, 17:00" per tank. Fix as A7. |
| Keep | | ipad-landscape-light | "El río" as side-by-side tanks with water at each reservoir's own level. | *Apple iPad 5* | |

### duo-inner (`B-vaso/duo-inner-light.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| B14 | Major | duo-inner-light | There is no continuous water across the fold. That is fine for B, but the right pane ends at about 450 pt of 669, leaving a third of it empty. | *Apple Duo 3* (n/a), *Apple iPad 3* | As B10. |
| B15 | Minor | duo-inner-light | "→ Estable" sits 28 pt from the fold gap. With side bars, the real fold (from `reservedRegions`) may be closer. | *Apple Duo 2* | Keep the trend under the figure (B4), away from the column's trailing edge. |
| Keep | | duo-inner-light | Fold in the 60 pt gap. "Ahora" on the left. Nothing crosses. | *Apple Duo 2, 6* | |

### watch (`B-vaso/watch-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| B16 | Major | watch-dark | It drops the 1.0 full-screen water hero, which the Apple audit named the reference for every format. A 55 × 60 pt tank leaves the figure at 30 pt. | *Apple Watch 1* | Structural. If B is chosen, the watch should still be A's full-screen water. |
| B17 | Major | watch-dark | Two unlabelled marker ticks stick out of the tank's left edge, and nobody can tell what they mean. No volume, no source or time. | *Apple Watch 2*; one question | Remove the ticks on watch. Add "67,0 hm³" and "SAIH · 16:00". |
| B18 | Minor | watch-dark | "Estable" in `waterBack` tint. | *Apple iPad 9* | White 0.85. |

### widgets (`B-vaso/widget-small-light.png`, `widget-medium-light.png`, `widget-large-light.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| B19 | Blocker | widget-small-light | "48,7 %" wraps to two lines: "48,7" and then "%". | Clipped or broken figure; *Android Glance 6* | `.lineLimit(1)` with `.minimumScaleFactor(0.6)`, and the tank narrowed to 24 pt. |
| B20 | Blocker | all three widgets | A light panel with black text and a separate tank: exactly the split-panel, two-tone design `CLAUDE.md` forbids. The widget background is a hardcoded `Color(0.96, 0.97, 0.99)`, with no dark design, and tinted mode would turn the tank into a grey box. | `CLAUDE.md` widgets; *Apple widgets 1, 9* | Structural. If B is chosen, the widgets must be A's widgets. |
| B21 | Major | widget-small-light, widget-medium-light | Unlabelled MITECO ticks on a SAIH tank (B1), with no legend. | `CLAUDE.md` SAIH/MITECO | Remove them from small and medium. |
| B22 | Major | widget-large-light | The left half is about 300 pt of empty panel between "San Juan" and "48,7 %". | Craft | As B20. |
| B23 | Major | all three widgets | No volume, "SAIH · 16:00" without a date, and "Estable" in tint at about 3:1. | One question; *Apple widgets 2*; WCAG | As A25 and B3. |

---

## C · Horizonte

### iphone (`C-horizonte/iphone-light.png`, `iphone-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| C1 | Blocker | iphone-light | "hace 90 días · 83,3 hm³" straddles the crest and the light-blue back wave. In light mode "83,3 hm³" is white on pale sky, about 1,1:1, effectively invisible. | *Apple iPhone 1*; *Android phone 1*; WCAG | Place curve labels at `surface(x) + 26` *measured at the label's own x range* (the curve slopes, so use the max of the surface over the label's width). Or place them in a fixed band near the bottom of the water. |
| C2 | Blocker | iphone-light (by construction) | The "Ahora" block is limited to `maxHeight: highest − 16`, the sky above the *90-day maximum*. If the reservoir was at 85 % three months ago, the sky is 130 pt and the 86 pt figure plus three lines (about 170 pt at default size, about 330 pt at AX5) is clipped. | *Apple iPhone 2*; *Android phone 2* | The first screen's layout depends on a number nobody is looking at. Needs a fallback: when the sky above the maximum is too short, clamp the surface's vertical domain or move the figure into the water. Either way the design loses its premise. |
| C3 | Major | iphone-light, iphone-dark | The water's *mass* shows the past. The left edge is 61 % full (90 days ago), and the eye reads the area, not the right edge, so the screen looks fuller than 48,7 %. | One question; honesty | Only fixable by making the past visually distinct (a lighter water band for the past, solid water for "today's level" across the width). That becomes A with a line on it. |
| C4 | Major | iphone-light | Two trends compete. The shape says "falling hard" (−16,3 hm³ in 90 days). The text says "→ Estable · +0,12 hm³ en 24 h". Both are true, but at a glance "is it rising or falling?" gets two answers. The synthetic curve exaggerates it, but real autumn refills and summer drawdowns do the same. | One question; *Apple iPhone 4* | Name both: "Estable hoy · −16,3 hm³ en 90 días". Or drop the shape from "Ahora". |
| C5 | Major | iphone-light | "hoy" has no value. The only figure on the curve is the past one, at the left edge. | *Apple widgets 6* (labels at the point they name) | "hoy · 67,0 hm³" at the right end, or no end labels. |
| C6 | Major | iphone-light | "MITECO · semana del 27 oct" is a footer under two glass cards, not inside them, and the cards lack MITECO's own current figure (70 hm³), as in A2. | *Apple iPhone 5* | One glass panel with the header inside and three figures, as A2. |
| C7 | Major | iphone-light | The trend line is `.secondary` grey on the light sky. Device tilt (ROADMAP) on a time series would rotate the data: a tilted *graph* is a wrong graph. | *Apple iPhone 6*; honesty | `.primary` trend. Disable tilt for C's surface. That removes the roadmap's motion idea from C. |
| C8 | Major | iphone-light, iphone-dark | Custom `SectionTabs` and glass content cards. | As A5 and A6 | As A5 and A6. |

### ipad-landscape (`C-horizonte/ipad-landscape-light.png`, `ipad-landscape-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| C9 | Blocker | ipad-landscape-light, -dark | The surface has no labels at all here: no "hace 90 días", no "hoy", no values. The sloping water reads as a stylised landscape, not as data, and the reader can't know the left edge is the past. | Honesty; *Apple widgets 6* | End labels in every format, or C isn't C. |
| C10 | Major | ipad-landscape-light | The figure is top right and the title top left, 900 pt apart. The eye starts at the title and has to cross the window. | *Apple iPad 1* (centred band) | Number under the title on the content margin, or centred. |
| C11 | Major | ipad-landscape-light | About 250 pt of plain water between the surface and the cards, so a third of the window has no content. The two cards are bottom-aligned with different heights, so their tops don't line up. | *Apple iPad 3, 4* | Top-align the cards. Raise them to start at `surface max + 24`. |
| C12 | Major | ipad-landscape-light | "Este año" lines white on white (A11). "El río" uses San Juan's time for Burguillo (A14). | As A11, A14 | As A11, A14. |

### duo-inner (`C-horizonte/duo-inner-light.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| C13 | Major | duo-inner-light | The waterline is at two different heights either side of the fold (about 255 pt on the left, 300 pt on the right), so the device reads as two reservoirs. That is the effect the audit asked to avoid. | *Apple Duo 3* | Structural to C. |
| C14 | Major | duo-inner-light | "Ahora" is split. The name and source are on the left, the figure on the right. | *Apple Duo 6* | Put the figure on the left. |
| C15 | Minor | duo-inner-light | The "El río" card starts 73 pt lower than "Este año". | Craft | Top-align. |

### watch (`C-horizonte/watch-dark.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| C16 | Major | watch-dark | "Estable" sits about 5 pt above the curve's highest point. | *Android phone 1* (12 pt clearance); *Apple widgets 8* | Clearance from the curve's max over the text's x range, at least 8 pt. |
| C17 | Major | watch-dark | "90 días" sits bottom left, with no "hoy" and no values. No source or time, and no volume. | *Apple Watch 2, 4* | "hace 90 días · 83,3" bottom left, "hoy · 67,0 hm³" bottom right, "SAIH · 16:00" under the name. |
| Keep | | watch-dark | As a *second* watch page, this is exactly *Apple Watch 4 and 8*: the 90-day curve on a 0 to capacity domain with the water as its ground. | | |

### widgets (`C-horizonte/widget-small-light.png`, `widget-medium-light.png`, `widget-large-light.png`)

| # | Severity | Screen / mode | Problem | Rule broken | Fix |
|---|---|---|---|---|---|
| C18 | Blocker | widget-medium-light | "48,7 %" straddles the waterline. The curve's left crest crosses the figure's lower half. | `CLAUDE.md` widgets ("nothing cut at the waterline"); *Apple widgets 8* | Clearance against the curve's max over the text's x range. In a 170 pt widget the slope makes this nearly impossible without flattening the curve. |
| C19 | Blocker | widget-small-light | "→ Estable" straddles the waterline. | As C18 | As C18. |
| C20 | Major | widget-small-light | The small widget silently uses 30 days, not 90, with no label. | Honesty; *Apple widgets 6* | Label it "30 días", or use 90 everywhere. |
| C21 | Major | all three widgets | No volume, and "16:00" with no source or date. | As A25 | As A25. |
| C22 | Minor | widget-large-light | The figure is in the sky, with about 220 pt of water underneath and nothing in it. | Craft | Put the 90-day end values and the volume in the water. |

---

## Scores

1 is poor and 5 is excellent. "Cost" is scored so that 5 means cheapest.

| Criterion | A · Superficie | B · Vaso | C · Horizonte |
|---|---|---|---|
| One question (under 2 s, nothing competing) | **4**: figure, volume and trend in one white block. The source is detached (A3). | **4**: the clearest top block, but the tank competes and the trend is split (B4, B6). | **2**: the water's mass overstates the level, and two trends compete (C3, C4). |
| Platform fit (iOS 27 Liquid Glass, M3 Expressive mirror) | **3**: full-bleed fits Liquid Glass's "content under glass chrome" model, but glass is used for content and the tabs are custom (A5, A6). On Android a Canvas water with M3 Expressive wavy shapes and Material You chrome mirrors well. | **4**: a standard scrolling page with cards maps directly to `List`/`LazyColumn` and M3 cards. Glass is barely needed. Loses on the roadmap's own full-screen intent. | **3**: the same glass issues as A, plus the tilt conflict (C7). Android Canvas is fine, but Glance needs a per-size bitmap of a data curve. |
| Consistency across formats | **4**: the same metaphor on phone, iPad, Duo, watch and widgets, and it is 1.0's own watch hero and widgets. | **2**: the widgets and watch break the app's rules, so they would have to be A anyway (B16, B20). | **3**: coherent idea, but the labels vanish on iPad, the small widget switches to 30 days, and the Duo splits the level. |
| Beauty | **4**: calm, bold, unmistakably *this* app. | **3**: tidy and generic, a fitness-app tank. | **4**: the most striking iPhone screen, but it reads as an illustration when unlabelled. |
| Accessibility at the largest text sizes | **3**: fine above about 40 %. Breaks at low levels plus AX (A1), and needs the sky fallback. Fixed figure sizes. | **4**: a plain column that reflows. Only the marker capsules collide at AX5 (75 and 57,5 hm³ are about 42 pt apart in a 330 pt tank). Fixed figure sizes. | **2**: the figure must fit above the 90-day maximum, clipped by `maxHeight` (C2). Labels along a slope can't grow without crossing it. |
| Honesty of the data | **4**: SAIH in the water, MITECO in its own labelled panel. Needs MITECO's own current figure and week (A2). | **2**: SAIH water with MITECO markers, by design (B1). | **2**: the curve on a 0 to capacity domain is honest, but the area misleads (C3), the end labels are missing or straddle (C1, C9), and tilt would distort data (C7). |
| Cost to build (5 = cheapest) | **4**: `WaveShape` and the hero exist in 1.0 (`Views/Water.swift`). New work: the placement rule, `TabView` and the iPad band. | **3**: the page is cheap, but the tank markers, an iPad rebalance and a second widget/watch design (A's) add up. | **2**: real daily series into the surface, label placement against a curve, per-family clearance, a Duo fold story and Glance bitmaps. |
| **Total (of 35)** | **26** | **22** | **18** |

## Recommendation

**Build A · Superficie, with three borrowed elements.** A is the only direction whose core idea survives every
format without breaking a rule in `CLAUDE.md`. It is also the cheapest, because 1.0's watch hero and widgets already
are A. Borrow, concretely:

1. **From C, the curve-as-surface, but only where the curve *is* the subject:** the **large widget** (replacing A's
   floating sparkline, A24) and a **second watch page** ("90 días"), both on a 0 to capacity domain with
   "hace 90 días · 83,3 hm³" and "hoy · 67,0 hm³" inside the water. It also belongs on the **"Ahora" detail below the
   fold** on iPhone and Android, as a panel of its own. **Never on the first screen or the small and medium widgets,**
   where it competes with the number and straddles text (C3, C18, C19).
2. **From B, the mini tanks for "El río"** on iPad, Duo's right pane, Android tablet and the foldable: Burguillo, San
   Juan and Picadas side by side, each with water at its own level and its own SAIH time. On iPhone, a compact row of
   three tanks at about 64 pt tall at the top of the "El río" tab.
3. **From B, the calm top block as A's low-level and AX fallback.** When the water is too shallow for the stack (A1),
   or at AX3 and above, "Ahora" renders as B's block (name, figure, volume, trend, source in `.primary`) in the
   **sky**, wholly above the crest. Also from B: the **"Este año" chart on a solid card with distinct colours**
   (blue this year, orange last year, grey dashed average) on the "Este año" tab, instead of white-on-white on glass
   (A11).

**What would make the others win:**

- **B wins** if the TestFlight round shows full-screen water fails in practice. That would be glass over the animated
  water dropping text below 4.5:1 in some palette state, the low-level fallback feeling like a different app, or
  testers finding the full-bleed screen tiring. To be eligible, B must move its markers into a MITECO-only element
  with MITECO's own current figure (B1), and adopt A's widgets and watch (B16, B20).
- **C wins** if three things hold. Real SAIH series over typical 90-day windows must show a readable shape (they are
  often nearly flat on a 0 to capacity scale, and then C collapses into A). A comprehension test ("¿cuánta agua hay?"
  on the C screen) must not get answers that overshoot the real level. And a placement algorithm must keep every
  label 12 pt clear of a sloping surface at AX5 and at the 97 % case. Today none of the three is shown.

## Changes A needs before implementation

In priority order. Each one must be visible in a new `make design` render before code starts in `Views/`.

1. **Placement rule for low levels and AX sizes (A1).** One function, shared by iPhone, iPad, Duo, watch and widgets:
   given the water height, the crest amplitude and the measured "Ahora" stack, put the stack wholly in the water
   (white) or wholly in the sky (`.primary`), never across. Render at 8, 30, 48,7, 62 and 97 % and at AX5. Mirror it
   in Compose (`Modifier.layout` measuring the stack).
2. **Anchor every format to the waterline (A10, A18).** iPad and Duo place the number and the right column at
   `waterline + 24`, not with `Spacer`s.
3. **MITECO panel with its own current figure and week (A2, C6).** "Esta semana 70 hm³ · Hace un año 75 · Media
   10 años 57,5", with a "MITECO · semana del 27 oct" header inside the panel. A different panel style from SAIH
   (*Apple iPhone 5*).
4. **Source inside the figure's block (A3), and per reservoir in "El río" (A14).** "SAIH Tajo · 30 oct, 16:00"
   under the trend, in the water. Burguillo shows its own 17:00.
5. **System navigation and correct glass (A5, A6).** `TabView` (three tabs, Liquid Glass tab bar) on iOS and
   `NavigationBar` or a connected button group on Android. Real `.glassEffect` only on chrome. Content panels are a
   fixed translucent fill, checked at 4.5:1 for white text against both the water's top colour and its gradient
   midpoint. White on the surface colour is 3,2 to 4,1:1 at 8 to 97 % with the current `water()` stops, which fails
   AA. Darken the top stop by about 15 %.
6. **iPad and Android tablet as a full-width band (A13, A16).** The number on the content margin in the top 40 % of
   the water. Below it, three columns: "Ahora" details, "Este año" (summary plus mini chart), "El río" (B's tanks).
   No column more than 10 % shorter than another.
7. **Duo right pane scrolls (A17),** with dark and large renders added (A19).
8. **Widgets: volume and dated source in every family (A25),** the word "Estable" on small (A26), and C's labelled
   surface on large (A24). Add dark, tinted and StandBy renders.
9. **Watch: volume and dated source (A20, A21),** `@ScaledMetric` figure (A23), and C's 90-day page as page 2.
10. **Small craft fixes:** back-wave width (A7), the stability threshold explained (A8), distinct chart colours on the
    "Este año" tab (A11), and a decision on the fill-level palette (A9).

## Keep

- A's figure, volume and trend as one white block wholly in the water (`A-superficie/iphone-light.png`).
- One waterline across the Duo fold, with "Ahora" on the left (`A-superficie/duo-inner-light.png`).
- Full-bleed widgets with white text (`A-superficie/widget-*.png`).
- SF Rounded, tabular digits, no-break spaces and Spanish decimals in every render.
- B's side-by-side "El río" tanks (`B-vaso/ipad-landscape-light.png`).
- C's 90-day curve as the water, on a 0 to capacity domain, as a secondary page (`C-horizonte/watch-dark.png`).
