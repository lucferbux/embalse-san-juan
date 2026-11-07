# Data sources

Findings from 30 October 2026, extended on 7 November 2026 for 2.0. None of the sources publishes an API contract, so `make live-check` is what tells us they still work.

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

`E_17` and `E_20` have the same `url10anos` series as San Juan (1,826 daily volumes each, checked on 7 November 2026). The backfill reads all three, one after another with the usual pause: about 6 more requests, once.

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

The neighbours are in the same table, in the `Tajo` rows (2,027 weeks each on 7 November 2026):

| Reservoir | `EMBALSE_NOMBRE` | Capacity |
|---|---|---|
| San Juan | `San Juan` | 138 hm³ |
| Burguillo | `Burguillo - Puente Nuevo` | 201 hm³ |
| Picadas | `Picadas` | 15 hm³ |

MITECO reports Burguillo **together with Puente Nuevo**, the small dam just below it, so its weekly figure is not the same reservoir as SAIH's `E_17`. That is one more reason never to mix the two. If a name stops matching, the weekly job leaves that history as it was and logs a warning, and `make live-check` fails.

## Published history

| Document | Reservoir | `weekly` (MITECO) | `daily` (SAIH) |
|---|---|---|---|
| `public/history` | San Juan | `San Juan` | `E_19` |
| `public/history-burguillo` | Burguillo | `Burguillo - Puente Nuevo` | `E_17` |
| `public/history-picadas` | Picadas | `Picadas` | `E_20` |

All three have the same shape (`History` in `backend/src/domain/types.ts`). The backfill seeds `daily` with SAIH's 5 years. After that, each hourly run adds every closed Madrid day it sees, as that day's last reading. Days already stored are never rewritten, except the newest one, which a late reading may still refine. The weekly job replaces `weekly` and keeps `daily`.

## AEMET (forecast)

[AEMET OpenData](https://opendata.aemet.es/), municipal daily forecast for San Martín de Valdeiglesias, INE code **28133**. It needs a free API key, read from the `AEMET_API_KEY` environment variable (the GitHub secret of the same name). The key goes in the `api_key` header, never in a URL or a log.

| Request | Returns |
|---|---|
| `api/prediccion/especifica/municipio/diaria/28133` | `{ estado, descripcion, datos }`. `estado` is 200 on success, and `datos` is a short-lived URL |
| The `datos` URL | An array with one forecast: `elaborado` (Madrid local time, no offset) and `prediccion.dia[]` |

Each day has `fecha`, `probPrecipitacion` (by period: `00-24`, `00-12`, `12-24`, `00-06`… for the first days, a single value later) and `temperatura.maxima` / `minima`. For today, AEMET blanks the periods that have passed, including `00-24`, so the backend then uses the highest period still ahead. The data file is served as ISO-8859-15.

**No rain amounts:** the daily product gives only the probability. Amounts are in the hourly product, for about 48 hours; the app doesn't use it yet.

It becomes the optional `forecast` field of `public/snapshot`: up to 7 days from today, with `issuedAt`, `fetchedAt` and its own `source`. The hourly job asks AEMET only when its forecast is more than 3 hours old, about 8 pairs of requests a day. If AEMET fails or there is no key, the last forecast is kept for up to 24 hours, then dropped. The snapshot is always published: the forecast never blocks it.

**A forecast is not a measurement.** The SAIH rain in `weather` and `rainGauges` is what fell; `forecast` is what AEMET expects. The apps must keep them apart and label the forecast as AEMET's.

AEMET allows reuse citing it as the author ("© AEMET"); see its [legal notice](https://www.aemet.es/es/nota_legal).

The test fixture `backend/test/fixtures/aemet-28133-diaria.json` is AEMET's real reply of 7 November 2026. To record a new one: `cd backend && read -rs AEMET_API_KEY && export AEMET_API_KEY && npm run live-check -- --record-aemet` (the key is typed, not echoed or kept in the shell history), then `make fixture` and the tests.

## Why the figures differ

On 30 October 2026, SAIH showed 67 hm³ and MITECO 70 hm³ (dated 27 October). They are separate systems with different timing and rounding, and MITECO publishes whole hm³. The app never mixes them.

Compared with embalses.net: the 75 hm³ for the same week of 2025 matches. Our 10-year mean is 57.5 hm³, and embalses.net shows 57 hm³ (41.96 %). The exact method there isn't published.

## Reuse

MITECO's [legal notice](https://www.miteco.gob.es/es/atencion-al-ciudadano/aviso-legal.aspx) allows reuse without express permission if the source is cited, the update date is kept, and no endorsement is implied. It doesn't address commercial use.

No terms of use were found for SAIH Tajo. This is a personal, low-frequency use with attribution. Check with the Confederación before any public or commercial release.

Facts in the reservoir profile (dam type, year, surface, uses) were taken from embalses.net and should be checked against MITECO's dam inventory.

## Known gaps

- embalses.net's rain gauges include AEMET and SIAR stations, which are not used here. The app shows SAIH gauges in the Alberche basin. The AEMET forecast is a prediction, not a gauge.
- There is no official series for water inflow, so the app has no inflow chart.
