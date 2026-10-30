import { MAIN_STATION, NEIGHBOURS, RAIN_GAUGES, SIGNAL, type StationConfig } from "../config.js";
import { assertPublishable } from "../domain/validate.js";
import { buildSnapshot, mergeDaily } from "../domain/build.js";
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

/** A fetch or validation failure throws before anything is written, so the last good data stays. */
export async function runHourly(store: Store, now: Date, fetcher: Fetcher = httpFetcher): Promise<HourlyResult> {
  const previous = await store.readSnapshot();
  if (!previous) throw new Error("No snapshot yet: run the backfill job first");

  const main = await fetchStation(MAIN_STATION, fetcher);
  const neighbours = await fetchOptional(NEIGHBOURS, fetcher);
  const gauges = await fetchOptional(RAIN_GAUGES, fetcher);

  const snapshot = buildSnapshot({ main, neighbours, gauges, weekly: previous.weekly, previous, now });
  assertPublishable(snapshot, previous, now);

  await store.archiveReadings(archiveOf(main));
  await store.writeSnapshot(snapshot);
  return { snapshot };
}

export function toHistoryWeekly(rows: readonly WeeklyRow[]): History["weekly"] {
  return rows.map((row) => [row.date, row.volumeHm3, row.capacityHm3]);
}

/** Applies a new MITECO archive to the archive, history and snapshot. */
export async function applyWeekly(store: Store, download: MitecoDownload, now: Date): Promise<void> {
  const weekly = summarise(download.rows);
  await store.archiveWeekly(download.rows);

  const history = await store.readHistory();
  await store.writeHistory({
    schemaVersion: 1,
    generatedAt: toInstant(now),
    weekly: toHistoryWeekly(download.rows),
    daily: history?.daily ?? [],
  });

  const snapshot = await store.readSnapshot();
  if (snapshot) await store.writeSnapshot({ ...snapshot, weekly, generatedAt: toInstant(now) });
  if (download.lastModified) await store.writeMitecoVersion(download.lastModified);
}

/** One-off seed: MITECO's full series, plus SAIH's 5 years of daily values. Safe to re-run. */
export async function runBackfill(
  store: Store,
  download: MitecoDownload,
  now: Date,
  fetcher: Fetcher = httpFetcher,
): Promise<Snapshot> {
  const main = await fetchStation(MAIN_STATION, fetcher);
  const volume = signalOfType(main, SIGNAL.volume);
  if (!volume) throw new Error("Main station has no volume signal");

  await pause();
  const longSeries: Reading[] = await fetchLongSeries(volume, "url10anos", fetcher);
  const dailyAll = mergeDaily([], [...longSeries, ...volume.readings]);

  const neighbours = await fetchOptional(NEIGHBOURS, fetcher);
  const gauges = await fetchOptional(RAIN_GAUGES, fetcher);

  const weekly = summarise(download.rows);
  const seed = buildSnapshot({ main, neighbours, gauges, weekly, now });
  const snapshot: Snapshot = { ...seed, daily: dailyAll.slice(-90) };
  assertPublishable(snapshot, undefined, now);

  await store.archiveWeekly(download.rows);
  await store.archiveReadings(archiveOf(main));
  await store.writeHistory({
    schemaVersion: 1,
    generatedAt: toInstant(now),
    weekly: toHistoryWeekly(download.rows),
    daily: dailyAll.map((point) => [point.date, point.volumeHm3]),
  });
  await store.writeSnapshot(snapshot);
  if (download.lastModified) await store.writeMitecoVersion(download.lastModified);
  return snapshot;
}
