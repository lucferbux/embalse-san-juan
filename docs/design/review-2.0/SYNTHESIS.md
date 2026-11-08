# 2.0 design review: synthesis

Five design leads reviewed the 2.0 TestFlight build (2.0 build 4) in parallel, each arguing a different thesis.
Their full reports are in this folder:

| Lead | Thesis | Verdict |
|---|---|---|
| [1 Inmersiva](lead-1-immersive.md) | Keep the full-screen water, fix it | Keep the full bleed, but the first card must peek, the water goes behind every page, and regular widths get a pinned water column. Two sections plus a menu. |
| [2 Panel](lead-2-dashboard.md) | Contained hero plus modules | The water is the brand, not the layout. Hero tile ~42 % of the screen, then a module grid. Three sections. |
| [3 Datos](lead-3-data.md) | The visual comes from the data | Keep the water, but give the waterline a time axis: the crest is the last 12 months, today at the right edge. Three sections. |
| [4 Adaptativa](lead-4-adaptive.md) | Information architecture across sizes | Three sections are right. Sidebar-adaptable tabs, reservoirs as sidebar items on wide screens, Ficha as an inspector, Avisos in Settings on Mac. |
| [5 Android](lead-5-android.md) | Native Material 3 Expressive | Don't copy the full screen. A large shaped water container that collapses into a strip, navigation suite, standard window size classes. |

## Where they agree

- **5 of 5:** the water stays as the identity, and the 2.0 first screen fails as a layout:
  - about 45 % of the iPhone screen is empty sky (`iphone-69/light-01-ahora`),
  - most of the iPad screen is empty (`ipad-portrait/light-01-ahora`),
  - at accessibility sizes the volume and source lines truncate (`large-01-ahora`),
  - nothing hints that there is more below.
- **5 of 5:** the best 2.0 screen is the reservoir page (`light-04-burguillo`), where the water is a contained card with history.
- **5 of 5:** "Este año" and "El río" read as a different, plain app; the water only lives on the first tab.
- **4 of 5:** three sections. "Este año" is the wrong name: it also holds the history since 1988.
- **5 of 5:** on wide screens the reservoirs become sidebar destinations, and Ficha, Avisos, Propinas and Sugerencias are not sections.

## Where they disagree, and the call

| Question | Options | Call |
|---|---|---|
| Hero size | Full bleed with a peek (1), ~42–55 % tile (2, 5), full bleed with data (3) | A contained hero of about half the first screen on compact widths, with the first modules visible. It collapses to a strip on scroll. |
| What the crest shows | Today's level only (1, 2, 4, 5), last 12 months (3) | The last 12 months of SAIH daily volume on a fixed 0-to-capacity scale, today at the right edge in full colour. This fills the sky with meaning. Validate with the 3-second test at 8, 48 and 97 %. |
| Sections | Two (1), three (2–5) | Three: **Ahora**, **Histórico**, **El río**. |
| Forecast | Ahora (2), Histórico (4, 5), El río (3) | Ahora, as its own AEMET tile, separate from measured weather. Measured basin rain stays in El río. |
| Regular width | Band on top (3, 4), pinned water column (1, 5) | The band, everywhere. One component that only gets wider; it works on iPad, unfolded foldables, Android tablets and a Mac window. |

## The proposal in one paragraph

The water becomes a hero card instead of the whole screen. Its surface is the reservoir's last year, so the empty sky
becomes the story ("lower than a year ago, in the normal range"). Below it, one-source modules with source and time.
Three sections everywhere: Ahora, Histórico, El río. On wide windows the tab bar becomes a sidebar with the three
reservoirs; the same band and modules reflow into columns. Android shares the IA and the hero, but uses Material 3
Expressive shapes, dynamic colour for the chrome, a navigation suite and a collapsing hero.

The visual proposal with mockups is published as an artifact; see the owner's conversation.
