import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { buildSnapshot, mergeDaily } from "../src/domain/build.js";
import { assertPublishable, SnapshotRejected } from "../src/domain/validate.js";
import type { History, Snapshot, WeeklyRow, WeeklySummary } from "../src/domain/types.js";
import { madridDay, parseSaihTime, toInstant } from "../src/lib/time.js";
import { rowsFromRecords, summarise } from "../src/sources/miteco.js";
import { fetchStation, findStationPath, parseLongSeries, parseStation, type Fetcher } from "../src/sources/saih.js";
import { MAIN_STATION, NEIGHBOURS, RAIN_GAUGES } from "../src/config.js";
import { runHourly } from "../src/jobs/run.js";
import type { HourlyArchive, Store } from "../src/store/store.js";
import { issueFor } from "../src/domain/suggestions.js";

const fixture = (name: string): unknown =>
  JSON.parse(readFileSync(new URL(`./fixtures/${name}`, import.meta.url), "utf8"));

const weekly: WeeklySummary = {
  date: "2026-10-27",
  volumeHm3: 70,
  capacityHm3: 138,
  percent: 50.72,
  changeHm3: 0,
  lastYearHm3: 75,
  tenYearAvgHm3: 57.5,
};
const now = new Date("2026-10-30T15:30:00Z");
const main = () => parseStation(fixture("station-e19.json"), "E_19");

const snapshot = (): Snapshot =>
  buildSnapshot({
    main: main(),
    neighbours: new Map([["E_17", parseStation(fixture("station-e17.json"), "E_17")]]),
    gauges: new Map([["P_37", parseStation(fixture("station-p37.json"), "P_37")]]),
    weekly,
    now,
  });

describe("SAIH times", () => {
  it("converts Madrid summer and winter time to UTC", () => {
    expect(toInstant(parseSaihTime("15/07/2026 12:00"))).toBe("2026-07-15T10:00:00Z");
    expect(toInstant(parseSaihTime("30/10/2026 16:00h"))).toBe("2026-10-30T15:00:00Z");
  });

  it("keeps a series increasing through the repeated hour when clocks go back", () => {
    const first = parseSaihTime("25/10/2026 02:30");
    const second = parseSaihTime("25/10/2026 02:30", first);
    expect(toInstant(first)).toBe("2026-10-25T00:30:00Z");
    expect(toInstant(second)).toBe("2026-10-25T01:30:00Z");
  });

  it("places a date with no time at midday, on that Madrid day", () => {
    expect(toInstant(parseSaihTime("30/10/2021"))).toBe("2021-10-30T10:00:00Z");
    expect(madridDay(parseSaihTime("30/10/2021"))).toBe("2021-10-30");
  });

  it("rejects a time skipped when clocks go forward", () => {
    expect(() => parseSaihTime("29/03/2026 02:30")).toThrow(/does not exist/);
  });

  it("works out the Madrid day near midnight", () => {
    expect(madridDay("2026-10-30T23:30:00Z")).toBe("2026-10-31");
  });
});

describe("SAIH parsing", () => {
  it("reads the recorded station", () => {
    const station = main();
    expect(station.code).toBe("E_19");
    expect(station.signals).toHaveLength(15);
  });

  it("rejects a reply for another station", () => {
    expect(() => parseStation(fixture("station-e19.json"), "E_20")).toThrow(/Expected station E_20/);
  });

  it("rejects a reply with no response object", () => {
    expect(() => parseStation({ ok: 1 }, "E_19")).toThrow(/no `response`/);
  });

  it("reads a long series", () => {
    const readings = parseLongSeries(fixture("long-e19-volume.json"));
    expect(readings).toHaveLength(40);
    expect(readings.at(-1)?.value).toBe(66.99);
  });

  it("finds a station path in a nested list", () => {
    const body = { response: { subtree: [{ hijos: [{ codigo: "E_19", url: "new-path" }] }] } };
    expect(findStationPath(body, "E_19")).toBe("new-path");
    expect(findStationPath(body, "E_99")).toBeNull();
  });

  it("looks the station up again when the stored token fails", async () => {
    const calls: string[] = [];
    const fetcher: Fetcher = async (path) => {
      calls.push(path);
      if (path === MAIN_STATION.path) throw new Error("HTTP 500");
      if (path === "page-datos-tiempo-real") return { response: { list: [{ codigo: "E_19", url: "fresh" }] } };
      return fixture("station-e19.json");
    };
    const station = await fetchStation(MAIN_STATION, fetcher);
    expect(station.code).toBe("E_19");
    expect(calls).toEqual([MAIN_STATION.path, "page-datos-tiempo-real", "fresh"]);
  });
});

describe("MITECO", () => {
  const year = (y: number, volume: number): WeeklyRow => ({ date: `${y}-10-27`, volumeHm3: volume, capacityHm3: 138 });

  it("parses decimal commas and keeps only San Juan in the Tajo basin", () => {
    const rows = rowsFromRecords([
      { FECHA: "2026-10-27T00:00:00Z", AMBITO_NOMBRE: "Tajo", EMBALSE_NOMBRE: "San Juan", AGUA_TOTAL: "138,00", AGUA_ACTUAL: "70,00" },
      { FECHA: "2026-10-27T00:00:00Z", AMBITO_NOMBRE: "Miño - Sil", EMBALSE_NOMBRE: "Albarellos", AGUA_TOTAL: "91,00", AGUA_ACTUAL: "32,00" },
      { FECHA: "2026-10-20T00:00:00Z", AMBITO_NOMBRE: "Tajo ", EMBALSE_NOMBRE: "San Juan ", AGUA_TOTAL: "138,00", AGUA_ACTUAL: "70,50" },
    ]);
    expect(rows).toEqual([
      { date: "2026-10-20", volumeHm3: 70.5, capacityHm3: 138 },
      { date: "2026-10-27", volumeHm3: 70, capacityHm3: 138 },
    ]);
  });

  it("reproduces the published comparison figures", () => {
    const rows: WeeklyRow[] = [
      ...[2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024].map((y) => year(y, 56.89)),
      { date: "2025-10-28", volumeHm3: 75, capacityHm3: 138 },
      { date: "2026-10-20", volumeHm3: 70, capacityHm3: 138 },
      { date: "2026-10-27", volumeHm3: 70, capacityHm3: 138 },
    ];
    const summary = summarise(rows);
    expect(summary).toMatchObject({ date: "2026-10-27", volumeHm3: 70, percent: 50.72, changeHm3: 0, lastYearHm3: 75 });
    expect(summary.tenYearAvgHm3).toBeCloseTo(58.7, 1);
  });

  it("gives no 10-year mean when years are missing", () => {
    const rows = [year(2025, 75), { date: "2026-10-20", volumeHm3: 70, capacityHm3: 138 }, year(2026, 70)];
    expect(summarise(rows).tenYearAvgHm3).toBeNull();
  });
});

describe("snapshot", () => {
  it("matches the live figures in the recorded reply", () => {
    const s = snapshot();
    expect(s.live).toMatchObject({ volumeHm3: 67.03, percent: 48.66, elevationM: 566.12, levelM: 40.86, outflowM3s: 1.21 });
    expect(s.recent).toHaveLength(24);
    expect(s.live.trend24hHm3).toBe(0.12);
    expect(s.weather.temperatureC).toBe(22.48);
  });

  it("is publishable", () => {
    expect(() => assertPublishable(snapshot(), undefined, now)).not.toThrow();
  });

  it("keeps the previous neighbour when a station fails", () => {
    const previous = snapshot();
    const next = buildSnapshot({ main: main(), neighbours: new Map(), gauges: new Map(), weekly, previous, now });
    expect(next.neighbours).toEqual(previous.neighbours);
    expect(next.rainGauges).toEqual(previous.rainGauges);
  });

  it("merges days with the newest reading winning, up to the limit", () => {
    const merged = mergeDaily(
      [
        { date: "2026-10-29", volumeHm3: 1 },
        { date: "2026-10-30", volumeHm3: 2 },
      ],
      [
        { at: "2026-10-30T12:00:00Z", value: 4 },
        { at: "2026-10-30T10:00:00Z", value: 3 },
      ],
      1,
    );
    expect(merged).toEqual([{ date: "2026-10-30", volumeHm3: 4 }]);
  });

  it("keeps the contract fixture up to date", () => {
    expect(fixture("../../../contract/fixtures/snapshot.json")).toEqual(
      JSON.parse(JSON.stringify(snapshot())),
    );
  });
});

describe("publishing guard", () => {
  const corrupt = (change: (s: Snapshot) => void): Snapshot => {
    const s = snapshot();
    change(s);
    return s;
  };
  const rejects = (s: Snapshot, previous?: Snapshot) =>
    expect(() => assertPublishable(s, previous, now)).toThrow(SnapshotRejected);

  it("rejects a percent above 100", () => rejects(corrupt((s) => void (s.live.percent = 140))));
  it("rejects a negative volume", () => rejects(corrupt((s) => void (s.live.volumeHm3 = -1))));
  it("rejects a volume above the sensor limit", () => rejects(corrupt((s) => void (s.live.volumeHm3 = 400))));
  it("rejects a reading from the future", () =>
    rejects(corrupt((s) => void (s.live.observedAt = "2026-10-31T15:00:00Z"))));
  it("rejects a stale reading", () => rejects(corrupt((s) => void (s.live.observedAt = "2026-10-20T15:00:00Z"))));
  it("rejects volume and percent that disagree", () => rejects(corrupt((s) => void (s.live.percent = 10))));
  it("rejects a malformed field", () =>
    rejects(corrupt((s) => void ((s.live as unknown as Record<string, unknown>).volumeHm3 = "67"))));
  it("rejects an implausible jump", () => {
    const previous = corrupt((s) => void (s.live.volumeHm3 = 20));
    rejects(snapshot(), previous);
  });
});

function memoryStore(snapshotValue?: Snapshot): Store & { written: Snapshot[]; archives: HourlyArchive[] } {
  const written: Snapshot[] = [];
  const archives: HourlyArchive[] = [];
  let history: History | undefined;
  let version: string | null = null;
  return {
    written,
    archives,
    readSnapshot: async () => written.at(-1) ?? snapshotValue,
    writeSnapshot: async (s) => void written.push(s),
    readHistory: async () => history,
    writeHistory: async (h) => void (history = h),
    archiveReadings: async (a) => void archives.push(a),
    archiveWeekly: async () => {},
    readMitecoVersion: async () => version,
    writeMitecoVersion: async (v) => void (version = v),
  };
}

describe("hourly job", () => {
  const stations: Record<string, string> = { E_17: "station-e17.json", P_37: "station-p37.json" };
  const fetcher: Fetcher = async (path) => {
    if (path === MAIN_STATION.path) return fixture("station-e19.json");
    const config = [...NEIGHBOURS, ...RAIN_GAUGES].find((c) => c.path === path);
    const file = config && stations[config.code];
    if (!file) throw new Error("station down");
    return fixture(file);
  };

  it("publishes and archives good data", { timeout: 30_000 }, async () => {
    const store = memoryStore(snapshot());
    const { snapshot: s } = await runHourly(store, now, fetcher);
    expect(store.written).toEqual([s]);
    expect(Object.keys(store.archives[0]!)).toEqual(["2026-10-29", "2026-10-30"]);
  });

  it("writes nothing when the main station is corrupt", { timeout: 30_000 }, async () => {
    const store = memoryStore(snapshot());
    const corrupted = fixture("station-e19.json") as {
      response: { senales: Array<{ tiposenal: string; valores: Array<{ valor: number }> }> };
    };
    for (const signal of corrupted.response.senales) {
      if (signal.tiposenal === "PO") signal.valores.at(-1)!.valor = 500;
    }
    const bad: Fetcher = async (path) => (path === MAIN_STATION.path ? corrupted : fetcher(path));
    await expect(runHourly(store, now, bad)).rejects.toThrow(SnapshotRejected);
    expect(store.written).toEqual([]);
    expect(store.archives).toEqual([]);
  });

  it("refuses to run without a snapshot", async () => {
    await expect(runHourly(memoryStore(), now, fetcher)).rejects.toThrow(/backfill/);
  });
});

describe("suggestions", () => {
  const createdAt = new Date("2026-10-30T19:00:00Z");

  it("builds an issue with the message intact", () => {
    const issue = issueFor({ kind: "bug", text: " Falla el gráfico\nen iPad ", appVersion: "1.0", createdAt });
    expect(issue.title).toBe("[Algo no funciona] Falla el gráfico");
    expect(issue.body).toContain("**Versión:** 1.0");
    expect(issue.body).toContain("```\nFalla el gráfico\nen iPad\n```");
  });

  it("keeps a stranger's text from mentioning people or breaking out of its block", () => {
    const issue = issueFor({ kind: "other", text: "@lucas #1 ``` **hola**", createdAt });
    expect(issue.title).toBe("[Otra cosa] lucas 1  **hola**");
    expect(issue.body).toContain("````\n@lucas #1 ``` **hola**\n````");
  });

  it("copes with unknown kinds, odd versions and long first lines", () => {
    const issue = issueFor({ kind: "x", text: "a".repeat(80), appVersion: "<b>1</b>", createdAt });
    expect(issue.title).toBe(`[Otra cosa] ${"a".repeat(60)}…`);
    expect(issue.body).toContain("**Versión:** b1b");
  });
});
