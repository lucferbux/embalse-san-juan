import { REQUEST_GAP_MS, SAIH_BASE, SAIH_DISCOVERY_PATH, USER_AGENT, type StationConfig } from "../config.js";
import { parseSaihTime, toInstant } from "../lib/time.js";

export interface RawValue {
  tag: string;
  tiempo: string;
  valor: number | null;
}

export interface RawSignal {
  tag: string;
  nombre: string;
  unidad: string;
  tiposenal: string;
  url: string;
  valores: RawValue[] | null;
  last: RawValue | null;
}

export interface RawStation {
  codigo: string;
  nombre: string;
  senales: RawSignal[];
}

export interface Reading {
  at: string;
  value: number;
}

export interface Signal {
  tag: string;
  type: string;
  unit: string;
  url: string;
  readings: Reading[];
  last: Reading | null;
}

export interface Station {
  code: string;
  name: string;
  signals: Signal[];
}

export type Fetcher = (path: string) => Promise<unknown>;

export class SaihError extends Error {}

export const httpFetcher: Fetcher = async (path) => {
  const response = await fetch(new URL(path, SAIH_BASE), {
    headers: { "User-Agent": USER_AGENT, Accept: "application/json" },
    signal: AbortSignal.timeout(60_000),
  });
  if (!response.ok) throw new SaihError(`SAIH ${path} returned HTTP ${response.status}`);
  const text = await response.text();
  try {
    return JSON.parse(text);
  } catch {
    throw new SaihError(`SAIH ${path} did not return JSON: ${text.slice(0, 120)}`);
  }
};

export const pause = () => new Promise((resolve) => setTimeout(resolve, REQUEST_GAP_MS));

function responseOf(body: unknown): Record<string, unknown> {
  const response = (body as { response?: Record<string, unknown> } | null)?.response;
  if (!response || typeof response !== "object") throw new SaihError("SAIH reply has no `response` object");
  return response;
}

function toReadings(values: RawValue[]): Reading[] {
  const readings: Reading[] = [];
  let previous: Date | undefined;
  for (const value of values) {
    const at = parseSaihTime(value.tiempo, previous);
    previous = at;
    if (typeof value.valor === "number" && Number.isFinite(value.valor)) {
      readings.push({ at: toInstant(at), value: value.valor });
    }
  }
  return readings;
}

export function parseStation(body: unknown, expectedCode: string): Station {
  const raw = responseOf(body) as unknown as RawStation;
  if (raw.codigo !== expectedCode) {
    throw new SaihError(`Expected station ${expectedCode}, got ${String(raw.codigo)}`);
  }
  if (!Array.isArray(raw.senales) || raw.senales.length === 0) {
    throw new SaihError(`Station ${expectedCode} has no signals`);
  }
  return {
    code: raw.codigo,
    name: raw.nombre,
    signals: raw.senales.map((signal) => {
      const readings = toReadings(signal.valores ?? []);
      return {
        tag: signal.tag,
        type: signal.tiposenal,
        unit: signal.unidad,
        url: signal.url,
        readings,
        last: readings.at(-1) ?? null,
      };
    }),
  };
}

/** Finds a station's current path in the full list, for when a stored token stops working. */
export function findStationPath(body: unknown, code: string): string | null {
  const stack: unknown[] = [responseOf(body)];
  while (stack.length > 0) {
    const node = stack.pop();
    if (Array.isArray(node)) {
      stack.push(...node);
    } else if (node && typeof node === "object") {
      const record = node as Record<string, unknown>;
      if (record.codigo === code && typeof record.url === "string") return record.url;
      stack.push(...Object.values(record));
    }
  }
  return null;
}

export async function fetchStation(config: StationConfig, fetcher: Fetcher = httpFetcher): Promise<Station> {
  try {
    return parseStation(await fetcher(config.path), config.code);
  } catch (error) {
    console.warn(`Stored path for ${config.code} failed (${String(error)}); looking it up again`);
    const path = findStationPath(await fetcher(SAIH_DISCOVERY_PATH), config.code);
    if (!path) throw new SaihError(`Station ${config.code} is not in the SAIH list`);
    console.warn(`Update config.ts: ${config.code} now lives at ${path}`);
    return parseStation(await fetcher(path), config.code);
  }
}

/** Long range of a signal: `url1ano` gives 365 daily values, `url10anos` about 1826 (labelled 5 years). */
export async function fetchLongSeries(
  signal: Signal,
  range: "url1ano" | "url10anos",
  fetcher: Fetcher = httpFetcher,
): Promise<Reading[]> {
  const chart = responseOf(await fetcher(signal.url));
  const path = chart[range];
  if (typeof path !== "string") throw new SaihError(`Signal ${signal.tag} has no ${range}`);
  await pause();
  return parseLongSeries(await fetcher(path));
}

export function parseLongSeries(body: unknown): Reading[] {
  const senal = responseOf(body).senal as { valores?: RawValue[] } | undefined;
  if (!Array.isArray(senal?.valores)) throw new SaihError("Long series has no `valores`");
  return toReadings(senal.valores);
}

export function signalOfType(station: Station, type: string): Signal | undefined {
  return station.signals.find((signal) => signal.type === type);
}

export function signalWithTag(station: Station, tag: string): Signal | undefined {
  return station.signals.find((signal) => signal.tag === tag);
}
