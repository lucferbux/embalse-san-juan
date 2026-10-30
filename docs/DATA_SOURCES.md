# Data sources

Findings from 30 October 2026. Neither source publishes an API contract, so `make live-check` is what tells us they still work.

## SAIH Tajo (hourly)

Undocumented JSON behind [saihtajo.chtajo.es](https://saihtajo.chtajo.es/). No login or cookies needed.

| Request | Returns |
|---|---|
| `page-datos-tiempo-real` | Every station with its code and current URL (1.7 MB) |
| `index.php?w=get-estacion&x=<token>` | One station: signals with 24 hourly values |
| A signal's `url` | Chart data for 10 days every 15 minutes, plus `url1ano`, `url10anos`, `urlexportarjson` |
| `url1ano` | 365 daily values |
| `url10anos` | 1,826 daily values. The site labels this "5 years", which is what it holds |

**Tokens:** `x` is opaque, and was the same across sessions when tested. If one stops working, `fetchStation` looks the station up by code and logs the new path for `backend/src/config.ts`.

**Times** are Madrid local (`30/10/2026 16:00`), and long series give only the date. They are converted to UTC, handling the repeated hour when clocks go back.

### Stations used

`E_19` San Juan, `E_17` Burguillo (upstream), `E_20` Picadas (downstream), and rain gauges `P_37`, `PN38`, `PN39`.

### San Juan signals

| Tag | Type | Meaning | Unit |
|---|---|---|---|
| `E_19VICT01` | `VE` | Volume | hm³ |
| `E_19VPCT01` | `PO` | Percent full | % |
| `E_19LICT01` | `NE` | Elevation above sea level | m |
| `E_19LI__01` | `NE` | Water level | m |
| `E_19FICT95` | `CSR` | Total outflow to the river | m³/s |
| `E_19FI__01` | `CT` | Transfer pipe to Valmayor | m³/s |
| `E_19UI__11`, `12` | `VV`, `DV` | Wind speed and direction | m/s, ° |
| `E_19UI__13`, `14` | `TE`, `HR` | Temperature, humidity | °C, % |
| `E_19UI__15`, `16` | `PA`, `RS` | Pressure, solar radiation | mb, W/m² |
| `E_19WIC101`, `601` | `P1`, `P24` | Rain in the last 1 h and 24 h | mm |

## MITECO (weekly)

[`BD-Embalses.zip`](https://www.miteco.gob.es/content/dam/miteco/es/agua/temas/evaluacion-de-los-recursos-hidricos/boletin-hidrologico/Historico-de-embalses/BD-Embalses.zip): 10 MB, containing a 222 MB Access database, updated on Tuesdays.

Table `T_Datos Embalses 1988-<year>`, whose name changes each year. Columns: `FECHA`, `AMBITO_NOMBRE`, `EMBALSE_NOMBRE`, `AGUA_TOTAL`, `AGUA_ACTUAL`, `ELECTRICO_FLAG`. Numbers are text with a decimal comma.

San Juan has 2,026 weekly rows from 5 January 1988 with no gaps. Capacity changes over time (146, 148 and 138 hm³), so each row keeps its own.

## Why the figures differ

On 30 October 2026, SAIH showed 67 hm³ and MITECO 70 hm³ (dated 27 October). They are separate systems with different timing and rounding, and MITECO publishes whole hm³. The app never mixes them.

Compared with embalses.net: the 75 hm³ for the same week of 2025 matches. Our 10-year mean is 57.5 hm³, and embalses.net shows 57 hm³ (41.96 %). The exact method there isn't published.

## Reuse

MITECO's [legal notice](https://www.miteco.gob.es/es/atencion-al-ciudadano/aviso-legal.aspx) allows reuse without express permission if the source is cited, the update date is kept, and no endorsement is implied. It doesn't address commercial use.

No terms of use were found for SAIH Tajo. This is a personal, low-frequency use with attribution. Check with the Confederación before any public or commercial release.

Facts in the reservoir profile (dam type, year, surface, uses) were taken from embalses.net and should be checked against MITECO's dam inventory.

## Known gaps

- embalses.net's rain gauges include AEMET and SIAR stations, which are not used here. The app shows SAIH gauges in the Alberche basin.
- There is no official series for water inflow, so the app has no inflow chart.
