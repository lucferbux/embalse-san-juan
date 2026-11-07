import {
  AEMET_BASE,
  AEMET_MUNICIPALITY,
  FORECAST_DAYS,
  FORECAST_MAX_AGE_MS,
  FORECAST_REFRESH_MS,
  FORECAST_SOURCE,
  USER_AGENT,
} from "../config.js";
import type { Forecast, ForecastDay } from "../domain/types.js";
import { madridDay, parseMadridIsoTime, toInstant } from "../lib/time.js";

/** Gets a URL and returns its parsed JSON. The real one sends the API key as a header, never in the URL. */
export type AemetFetcher = (url: string) => Promise<unknown>;

/** Produces a fresh forecast, or throws. */
export type ForecastSource = (now: Date) => Promise<Forecast>;

export class AemetError extends Error {}

export function aemetFetcher(apiKey: string): AemetFetcher {
  return async (url) => {
    const response = await fetch(url, {
      headers: { api_key: apiKey, Accept: "application/json", "User-Agent": USER_AGENT },
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) throw new AemetError(`AEMET returned HTTP ${response.status}`);
    // The data files are served as ISO-8859-15, the first reply as UTF-8.
    const charset = /charset=([^;]+)/i.exec(response.headers.get("content-type") ?? "")?.[1]?.trim() ?? "utf-8";
    const text = new TextDecoder(charset).decode(await response.arrayBuffer());
    try {
      return JSON.parse(text);
    } catch {
      throw new AemetError(`AEMET did not return JSON: ${text.slice(0, 120)}`);
    }
  };
}

/** The forecast source for the hourly job, or null when there is no key. */
export function aemetFromEnv(env: NodeJS.ProcessEnv = process.env): ForecastSource | null {
  const key = env.AEMET_API_KEY?.trim();
  if (!key) return null;
  const fetcher = aemetFetcher(key);
  return (now) => fetchForecast(fetcher, now);
}

/** AEMET OpenData answers in two steps: the first reply holds a short-lived URL to the data. */
export async function fetchForecast(fetcher: AemetFetcher, now: Date): Promise<Forecast> {
  const first = (await fetcher(`${AEMET_BASE}prediccion/especifica/municipio/diaria/${AEMET_MUNICIPALITY}`)) as {
    estado?: unknown;
    descripcion?: unknown;
    datos?: unknown;
  } | null;
  if (first?.estado !== 200 || typeof first.datos !== "string") {
    throw new AemetError(`AEMET refused the request: ${String(first?.estado)} ${String(first?.descripcion)}`);
  }
  return parseForecast(await fetcher(first.datos), now);
}

interface RawPeriod {
  value?: unknown;
  periodo?: unknown;
}

interface RawDay {
  fecha?: unknown;
  probPrecipitacion?: RawPeriod[];
  temperatura?: { maxima?: unknown; minima?: unknown };
}

function numberOrNull(value: unknown): number | null {
  if (value === "" || value === null || value === undefined) return null;
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * AEMET blanks the periods of today that have already passed, including the whole-day one.
 * The whole-day value is used when there is one, otherwise the highest period left.
 */
function rainProbability(periods: readonly RawPeriod[] | undefined): number | null {
  const values = (periods ?? []).map((period) => ({ periodo: period.periodo, value: numberOrNull(period.value) }));
  const whole = values.find((period) => period.periodo === "00-24" || period.periodo === undefined)?.value;
  const chosen =
    whole ?? values.reduce<number | null>((max, { value }) => (value === null ? max : Math.max(max ?? value, value)), null);
  return chosen !== null && chosen >= 0 && chosen <= 100 ? chosen : null;
}

/** Reads the daily municipal forecast, keeping today and the days after it, up to FORECAST_DAYS. */
export function parseForecast(body: unknown, now: Date): Forecast {
  const item = (Array.isArray(body) ? body[0] : undefined) as
    | { elaborado?: unknown; prediccion?: { dia?: RawDay[] } }
    | undefined;
  if (!item || typeof item.elaborado !== "string" || !Array.isArray(item.prediccion?.dia)) {
    throw new AemetError("AEMET forecast has an unexpected shape");
  }
  const today = madridDay(now);
  const days: ForecastDay[] = item.prediccion.dia
    .flatMap((day) => {
      const date = typeof day.fecha === "string" ? day.fecha.slice(0, 10) : "";
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return [];
      return [
        {
          date,
          rainProbabilityPct: rainProbability(day.probPrecipitacion),
          maxTemperatureC: numberOrNull(day.temperatura?.maxima),
          minTemperatureC: numberOrNull(day.temperatura?.minima),
        },
      ];
    })
    .filter((day) => day.date >= today)
    .sort((a, b) => a.date.localeCompare(b.date))
    .slice(0, FORECAST_DAYS);
  if (days.length === 0) throw new AemetError("AEMET forecast has no days from today on");

  return {
    issuedAt: toInstant(parseMadridIsoTime(item.elaborado)),
    fetchedAt: toInstant(now),
    source: { ...FORECAST_SOURCE },
    days,
  };
}

/** Drops the days that have passed. Returns undefined when none are left. */
function current(forecast: Forecast | undefined, now: Date): Forecast | undefined {
  if (!forecast) return undefined;
  const today = madridDay(now);
  const days = forecast.days.filter((day) => day.date >= today);
  return days.length > 0 ? { ...forecast, days } : undefined;
}

/**
 * The forecast for this run. AEMET is asked at most every FORECAST_REFRESH_MS. If it fails, or
 * there is no key, the previous forecast is kept for up to FORECAST_MAX_AGE_MS and then dropped.
 * Never throws: the forecast must not stop the reservoir data from being published.
 */
export async function refreshForecast(
  previous: Forecast | undefined,
  source: ForecastSource | null,
  now: Date,
): Promise<Forecast | undefined> {
  const age = previous ? now.getTime() - new Date(previous.fetchedAt).getTime() : Infinity;
  if (age < FORECAST_REFRESH_MS) return current(previous, now);
  if (source) {
    try {
      return await source(now);
    } catch (error) {
      console.warn(`Forecast not refreshed: ${String(error)}`);
    }
  }
  return age < FORECAST_MAX_AGE_MS ? current(previous, now) : undefined;
}
