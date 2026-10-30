/**
 * Calls the real sources without writing anywhere, and exits non-zero if their
 * shape or values look wrong. `--skip-miteco` avoids the 10 MB download.
 */
import { MAIN_STATION, NEIGHBOURS, RAIN_GAUGES, SIGNAL } from "../config.js";
import { buildSnapshot } from "../domain/build.js";
import { assertPublishable } from "../domain/validate.js";
import type { WeeklySummary } from "../domain/types.js";
import { downloadWeeklyRows, summarise } from "../sources/miteco.js";
import { fetchLongSeries, fetchStation, pause, signalOfType, type Station } from "../sources/saih.js";

const skipMiteco = process.argv.includes("--skip-miteco");
const now = new Date();

const main = await fetchStation(MAIN_STATION);
console.log(`SAIH ${main.code} ${main.name}: ${main.signals.length} signals`);

const neighbours = new Map<string, Station>();
for (const config of NEIGHBOURS) {
  await pause();
  neighbours.set(config.code, await fetchStation(config));
}
const gauges = new Map<string, Station>();
for (const config of RAIN_GAUGES) {
  await pause();
  gauges.set(config.code, await fetchStation(config));
}

const volume = signalOfType(main, SIGNAL.volume);
if (!volume) throw new Error("No volume signal");
await pause();
const long = await fetchLongSeries(volume, "url10anos");
console.log(`SAIH long series: ${long.length} points, ${long[0]?.at} to ${long.at(-1)?.at}`);
if (long.length < 1000) throw new Error("SAIH long series is shorter than expected");

let weekly: WeeklySummary;
if (skipMiteco) {
  weekly = {
    date: "2026-10-27",
    volumeHm3: 70,
    capacityHm3: 138,
    percent: 50.72,
    changeHm3: 0,
    lastYearHm3: 75,
    tenYearAvgHm3: 57.5,
  };
  console.log("MITECO skipped");
} else {
  const download = await downloadWeeklyRows();
  if (!download) throw new Error("MITECO download returned nothing");
  if (download.rows.length < 2000) throw new Error(`MITECO series too short: ${download.rows.length}`);
  weekly = summarise(download.rows);
  console.log(`MITECO: ${download.rows.length} weeks, latest ${weekly.date} = ${weekly.volumeHm3} hm³`);
  console.log(`MITECO comparison: last year ${weekly.lastYearHm3}, 10-year mean ${weekly.tenYearAvgHm3}`);
}

const snapshot = buildSnapshot({ main, neighbours, gauges, weekly, now });
assertPublishable(snapshot, undefined, now);
console.log(
  `Live: ${snapshot.live.volumeHm3} hm³, ${snapshot.live.percent} %, cota ${snapshot.live.elevationM} m, ` +
    `caudal ${snapshot.live.outflowM3s} m³/s, observed ${snapshot.live.observedAt}`,
);
console.log(`Neighbours: ${snapshot.neighbours.map((n) => `${n.name} ${n.percent} %`).join(", ")}`);
console.log(`Gauges: ${snapshot.rainGauges.map((g) => `${g.name} ${g.rain24hMm} mm`).join(", ")}`);
console.log("live-check OK");
