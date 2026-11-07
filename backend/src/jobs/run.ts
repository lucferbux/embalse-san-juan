import {
  HISTORY_RESERVOIRS,
  MAIN_STATION,
  NEIGHBOURS,
  RAIN_GAUGES,
  SIGNAL,
  type HistoryId,
  type HistoryReservoir,
  type StationConfig,
} from "../config.js";
import { assertPublishable } from "../domain/validate.js";
import { appendClosedDays, buildSnapshot, mergeDaily } from "../domain/build.js";
import { madridDay, toInstant } from "../lib/time.js";
import {
  fetchLongSeries,
  fetchStation,
  httpFetcher,
  pause,
  signalOfType,
  type Fetcher,
  type Reading,
  type Station,
} from "../sources/saih.js";
import { summarise, type MitecoDownload } from "../sources/miteco.js";
import { refreshForecast, type ForecastSource } from "../sources/aemet.js";
import type { History, Snapshot, WeeklyRow } from "../domain/types.js";
import type { HourlyArchive, Store } from "../store/store.js";

/** Fetches secondary stations one at a time. One failure must not lose the whole run. */
async function fetchOptional(
  configs: ReadonlyArray<StationConfig>,
  fetcher: Fetcher,
): Promise<Map<string, Station>> {
  const stations = new Map<string, Station>();
  for (const config of configs) {
    await pause();
    try {
      stations.set(config.code, await fetchStation(config, fetcher));
    } catch (error) {
      console.warn(`Skipping ${config.code}: ${String(error)}`);
    }
  }
  return stations;
}

export function archiveOf(station: Station): HourlyArchive {
  const archive: HourlyArchive = {};
  for (const signal of station.signals) {
    for (const reading of signal.readings) {
      const day = (archive[madridDay(reading.at)] ??= {});
      (day[signal.tag] ??= []).push(reading);
    }
  }
  return archive;
}

export interface HourlyResult {
  snapshot: Snapshot;
}

/**
 * Adds the closed days in a station's readings to that reservoir's history. Writes only when
 * something changed, and skips a reservoir whose history the backfill hasn't seeded yet.
 */
async function appendDailyHistory(store: Store, id: HistoryId, station: Station, now: Date): Promise<void> {
  const readings = signalOfType(station, SIGNAL.volume)?.readings ?? [];
  const history = await store.readHistory(id);
  if (!history) {
    console.warn(`No history for ${id} yet: run the backfill job`);
    return;
  }
  const daily = appendClosedDays(history.daily, readings, now);
  if (JSON.stringify(daily) === JSON.stringify(history.daily)) return;
  await store.writeHistory({ ...history, generatedAt: toInstant(now), daily }, id);
}

/** A fetch or validation failure throws before anything is written, so the last good data stays. */
export async function runHourly(
  store: Store,
  now: Date,
  fetcher: Fetcher = httpFetcher,
  forecastSource: ForecastSource | null = null,
): Promise<HourlyResult> {
  const previous = await store.readSnapshot();
  if (!previous) throw new Error("No snapshot yet: run the backfill job first");

  const main = await fetchStation(MAIN_STATION, fetcher);
  const neighbours = await fetchOptional(NEIGHBOURS, fetcher);
  const gauges = await fetchOptional(RAIN_GAUGES, fetcher);
  const forecast = await refreshForecast(previous.forecast, forecastSource, now);

  const built = buildSnapshot({ main, neighbours, gauges, weekly: previous.weekly, previous, now });
  const snapshot: Snapshot = forecast ? { ...built, forecast } : built;
  assertPublishable(snapshot, previous, now);

  await store.archiveReadings(archiveOf(main));
  await store.writeSnapshot(snapshot);

  const stations = new Map([[main.code, main], ...neighbours]);
  for (const reservoir of HISTORY_RESERVOIRS) {
    const station = stations.get(reservoir.stationCode);
    if (station) await appendDailyHistory(store, reservoir.id, station, now);
  }
  return { snapshot };
}

export function toHistoryWeekly(rows: readonly WeeklyRow[]): History["weekly"] {
  return rows.map((row) => [row.date, row.volumeHm3, row.capacityHm3]);
}

/** Applies a new MITECO archive to the archive, the three histories and the snapshot. */
export async function applyWeekly(store: Store, download: MitecoDownload, now: Date): Promise<void> {
  const weekly = summarise(download.rows);
  await store.archiveWeekly(download.rows);

  for (const reservoir of HISTORY_RESERVOIRS) {
    const rows = download.byReservoir[reservoir.id];
    if (rows.length === 0) {
      // A renamed reservoir must not wipe its history: keep the old rows and say so.
      console.warn(`MITECO has no rows for "${reservoir.mitecoName}"; ${reservoir.id} history left as it was`);
      continue;
    }
    const history = await store.readHistory(reservoir.id);
    await store.writeHistory(
      {
        schemaVersion: 1,
        generatedAt: toInstant(now),
        weekly: toHistoryWeekly(rows),
        daily: history?.daily ?? [],
      },
      reservoir.id,
    );
  }

  const snapshot = await store.readSnapshot();
  if (snapshot) await store.writeSnapshot({ ...snapshot, weekly, generatedAt: toInstant(now) });
  if (download.lastModified) await store.writeMitecoVersion(download.lastModified);
}

/** SAIH's 5 years of daily volume for a station, plus its last 24 hours. */
async function dailySeries(station: Station, fetcher: Fetcher): Promise<Reading[]> {
  const volume = signalOfType(station, SIGNAL.volume);
  if (!volume) throw new Error(`Station ${station.code} has no volume signal`);
  await pause();
  const longSeries = await fetchLongSeries(volume, "url10anos", fetcher);
  return [...longSeries, ...volume.readings];
}

function historyOf(
  reservoir: HistoryReservoir,
  download: MitecoDownload,
  existing: History | undefined,
  readings: readonly Reading[],
  now: Date,
): History {
  const kept = (existing?.daily ?? []).map(([date, volumeHm3]) => ({ date, volumeHm3 }));
  const rows = download.byReservoir[reservoir.id];
  return {
    schemaVersion: 1,
    generatedAt: toInstant(now),
    weekly: rows.length > 0 ? toHistoryWeekly(rows) : (existing?.weekly ?? []),
    daily: mergeDaily(kept, readings).map((point) => [point.date, point.volumeHm3]),
  };
}

/**
 * Seed: MITECO's full series, plus SAIH's 5 years of daily values, for San Juan and its two
 * neighbours. Safe to re-run: days already stored are kept, and SAIH's values win where they overlap.
 */
export async function runBackfill(
  store: Store,
  download: MitecoDownload,
  now: Date,
  fetcher: Fetcher = httpFetcher,
): Promise<Snapshot> {
  const main = await fetchStation(MAIN_STATION, fetcher);
  const mainReadings = await dailySeries(main, fetcher);
  const dailyAll = mergeDaily([], mainReadings);

  const neighbours = await fetchOptional(NEIGHBOURS, fetcher);
  const neighbourReadings = new Map<string, Reading[]>();
  for (const [code, station] of neighbours) {
    try {
      neighbourReadings.set(code, await dailySeries(station, fetcher));
    } catch (error) {
      console.warn(`No daily series for ${code}: ${String(error)}`);
    }
  }
  const gauges = await fetchOptional(RAIN_GAUGES, fetcher);

  const weekly = summarise(download.rows);
  const seed = buildSnapshot({ main, neighbours, gauges, weekly, now });
  const snapshot: Snapshot = { ...seed, daily: dailyAll.slice(-90) };
  assertPublishable(snapshot, undefined, now);

  await store.archiveWeekly(download.rows);
  await store.archiveReadings(archiveOf(main));
  for (const reservoir of HISTORY_RESERVOIRS) {
    const readings = reservoir.stationCode === main.code ? mainReadings : neighbourReadings.get(reservoir.stationCode);
    const existing = await store.readHistory(reservoir.id);
    await store.writeHistory(historyOf(reservoir, download, existing, readings ?? [], now), reservoir.id);
  }
  await store.writeSnapshot(snapshot);
  if (download.lastModified) await store.writeMitecoVersion(download.lastModified);
  return snapshot;
}
