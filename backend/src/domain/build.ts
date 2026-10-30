import {
  ELEVATION_TAG,
  LEVEL_TAG,
  MAX_DAILY_POINTS,
  RAIN_GAUGES,
  RESERVOIR,
  NEIGHBOURS,
  SIGNAL,
  SOURCES,
} from "../config.js";
import { madridDay, toInstant } from "../lib/time.js";
import { signalOfType, signalWithTag, type Reading, type Signal, type Station } from "../sources/saih.js";
import type { DailyPoint, RecentReading, Snapshot, WeeklySummary } from "./types.js";

export interface HourlyInput {
  main: Station;
  /** Stations that failed this run are simply absent; the previous value is kept. */
  neighbours: ReadonlyMap<string, Station>;
  gauges: ReadonlyMap<string, Station>;
  weekly: WeeklySummary;
  previous?: Snapshot;
  now: Date;
}

function lastValue(signal: Signal | undefined): number | null {
  return signal?.last?.value ?? null;
}

function requireReadings(station: Station, type: string): Reading[] {
  const readings = signalOfType(station, type)?.readings ?? [];
  if (readings.length === 0) throw new Error(`Station ${station.code} has no readings of type ${type}`);
  return readings;
}

function valueAt(signal: Signal | undefined, at: string): number | null {
  return signal?.readings.find((reading) => reading.at === at)?.value ?? null;
}

export function buildRecent(main: Station): RecentReading[] {
  const percents = signalOfType(main, SIGNAL.percent);
  const outflow = signalOfType(main, SIGNAL.outflow);
  return requireReadings(main, SIGNAL.volume).flatMap((reading) => {
    const percent = valueAt(percents, reading.at);
    if (percent === null) return [];
    return [{ at: reading.at, volumeHm3: reading.value, percent, outflowM3s: valueAt(outflow, reading.at) }];
  });
}

/** Merges readings into a per-day series, where the latest reading of a Madrid day wins. */
export function mergeDaily(existing: readonly DailyPoint[], readings: readonly Reading[], limit?: number): DailyPoint[] {
  const byDay = new Map(existing.map((point) => [point.date, point.volumeHm3]));
  for (const reading of [...readings].sort((a, b) => a.at.localeCompare(b.at))) {
    byDay.set(madridDay(reading.at), reading.value);
  }
  const merged = [...byDay.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, volumeHm3]) => ({ date, volumeHm3 }));
  return limit === undefined ? merged : merged.slice(-limit);
}

export function buildSnapshot({ main, neighbours, gauges, weekly, previous, now }: HourlyInput): Snapshot {
  const recent = buildRecent(main);
  const latest = recent.at(-1);
  const first = recent[0];
  if (!latest || !first) throw new Error("No usable readings for the main station");

  const temperature = signalOfType(main, SIGNAL.temperature);

  return {
    schemaVersion: 1,
    generatedAt: toInstant(now),
    reservoir: RESERVOIR,
    live: {
      observedAt: latest.at,
      volumeHm3: latest.volumeHm3,
      percent: latest.percent,
      elevationM: lastValue(signalWithTag(main, ELEVATION_TAG)),
      levelM: lastValue(signalWithTag(main, LEVEL_TAG)),
      trend24hHm3: Math.round((latest.volumeHm3 - first.volumeHm3) * 100) / 100,
      outflowM3s: lastValue(signalOfType(main, SIGNAL.outflow)),
      transferM3s: lastValue(signalOfType(main, SIGNAL.transfer)),
    },
    recent,
    daily: mergeDaily(previous?.daily ?? [], requireReadings(main, SIGNAL.volume), MAX_DAILY_POINTS),
    weather: {
      observedAt: temperature?.last?.at ?? latest.at,
      temperatureC: lastValue(temperature),
      windMs: lastValue(signalOfType(main, SIGNAL.windSpeed)),
      windDirectionDeg: lastValue(signalOfType(main, SIGNAL.windDirection)),
      humidityPct: lastValue(signalOfType(main, SIGNAL.humidity)),
      pressureHpa: lastValue(signalOfType(main, SIGNAL.pressure)),
      solarWm2: lastValue(signalOfType(main, SIGNAL.solar)),
      rain1hMm: lastValue(signalOfType(main, SIGNAL.rain1h)),
      rain24hMm: lastValue(signalOfType(main, SIGNAL.rain24h)),
    },
    weekly,
    neighbours: NEIGHBOURS.flatMap((config) => {
      const station = neighbours.get(config.code);
      const volume = station && signalOfType(station, SIGNAL.volume)?.last;
      const percent = station && signalOfType(station, SIGNAL.percent)?.last;
      if (volume && percent) {
        return [
          {
            code: config.code,
            name: config.name,
            position: config.position,
            observedAt: volume.at,
            volumeHm3: volume.value,
            percent: percent.value,
          },
        ];
      }
      const kept = previous?.neighbours.find((neighbour) => neighbour.code === config.code);
      return kept ? [kept] : [];
    }),
    rainGauges: RAIN_GAUGES.flatMap((config) => {
      const station = gauges.get(config.code);
      const hour = station && signalOfType(station, SIGNAL.rain1h);
      const day = station && signalOfType(station, SIGNAL.rain24h);
      const observedAt = hour?.last?.at ?? day?.last?.at;
      if (observedAt) {
        return [
          {
            code: config.code,
            name: config.name,
            observedAt,
            rain1hMm: lastValue(hour),
            rain24hMm: lastValue(day),
          },
        ];
      }
      const kept = previous?.rainGauges.find((gauge) => gauge.code === config.code);
      return kept ? [kept] : [];
    }),
    sources: SOURCES,
  };
}
