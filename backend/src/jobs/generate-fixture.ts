/** Rebuilds contract/fixtures/snapshot.json from the recorded SAIH replies, so Swift tests use real data. */
import { readFileSync, writeFileSync } from "node:fs";
import { buildSnapshot } from "../domain/build.js";
import { parseStation } from "../sources/saih.js";
import { assertPublishable } from "../domain/validate.js";

const fixture = (name: string): unknown =>
  JSON.parse(readFileSync(new URL(`../../test/fixtures/${name}`, import.meta.url), "utf8"));

const now = new Date("2026-10-30T15:30:00Z");
const snapshot = buildSnapshot({
  main: parseStation(fixture("station-e19.json"), "E_19"),
  neighbours: new Map([["E_17", parseStation(fixture("station-e17.json"), "E_17")]]),
  gauges: new Map([["P_37", parseStation(fixture("station-p37.json"), "P_37")]]),
  weekly: {
    date: "2026-10-27",
    volumeHm3: 70,
    capacityHm3: 138,
    percent: 50.72,
    changeHm3: 0,
    lastYearHm3: 75,
    tenYearAvgHm3: 57.5,
  },
  now,
});
assertPublishable(snapshot, undefined, now);
writeFileSync(
  new URL("../../../contract/fixtures/snapshot.json", import.meta.url),
  `${JSON.stringify(snapshot, null, 2)}\n`,
);
console.log("Wrote contract/fixtures/snapshot.json");
