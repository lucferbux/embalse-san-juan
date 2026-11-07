import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import { appendClosedDays, buildSnapshot, mergeDaily } from "../src/domain/build.js";
import { assertPublishable, SnapshotRejected } from "../src/domain/validate.js";
import type { History, Snapshot, WeeklyRow, WeeklySummary } from "../src/domain/types.js";
import { madridDay, parseSaihTime, toInstant } from "../src/lib/time.js";
import { rowsByReservoir, rowsFromRecords, summarise, type MitecoDownload } from "../src/sources/miteco.js";
import { fetchStation, findStationPath, parseLongSeries, parseStation, type Fetcher } from "../src/sources/saih.js";
import { MAIN_STATION, NEIGHBOURS, RAIN_GAUGES, type HistoryId } from "../src/config.js";
import { applyWeekly, runBackfill, runHourly } from "../src/jobs/run.js";
import { fetchForecast, parseForecast, refreshForecast, type ForecastSource } from "../src/sources/aemet.js";
import type { Forecast } from "../src/domain/types.js";

// The pause between SAIH requests is for the real servers; tests don't need to wait for it.
vi.mock("../src/sources/saih.js", async (original) => ({
  ...(await original<typeof import("../src/sources/saih.js")>()),
  pause: async () => {},
}));
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
    const forecast = parseForecast(fixture("aemet-28133-diaria.json"), new Date("2026-11-07T09:30:00Z"));
    expect(fixture("../../../contract/fixtures/snapshot.json")).toEqual(
      JSON.parse(JSON.stringify({ ...snapshot(), forecast })),
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
  it("rejects a malformed forecast", () =>
    rejects(
      corrupt((s) => {
        s.forecast = parseForecast(fixture("aemet-28133-diaria.json"), new Date("2026-11-07T09:30:00Z"));
        s.forecast.days[0]!.rainProbabilityPct = 140;
      }),
    ));
  it("rejects an implausible jump", () => {
    const previous = corrupt((s) => void (s.live.volumeHm3 = 20));
    rejects(snapshot(), previous);
  });
});

type MemoryStore = Store & {
  written: Snapshot[];
  archives: HourlyArchive[];
  histories: Map<HistoryId, History>;
  historyWrites: HistoryId[];
};

function memoryStore(snapshotValue?: Snapshot, histories = new Map<HistoryId, History>()): MemoryStore {
  const written: Snapshot[] = [];
  const archives: HourlyArchive[] = [];
  const historyWrites: HistoryId[] = [];
  let version: string | null = null;
  return {
    written,
    archives,
    histories,
    historyWrites,
    readSnapshot: async () => written.at(-1) ?? snapshotValue,
    writeSnapshot: async (s) => void written.push(s),
    readHistory: async (id = "san-juan") => histories.get(id),
    writeHistory: async (h, id = "san-juan") => {
      histories.set(id, h);
      historyWrites.push(id);
    },
    archiveReadings: async (a) => void archives.push(a),
    archiveWeekly: async () => {},
    readMitecoVersion: async () => version,
    writeMitecoVersion: async (v) => void (version = v),
  };
}

const seeded = (daily: History["daily"] = []): History => ({
  schemaVersion: 1,
  generatedAt: "2026-10-01T00:00:00Z",
  weekly: [["2026-09-29", 70, 138]],
  daily,
});

describe("daily history", () => {
  const readings = [
    { at: "2026-10-28T21:00:00Z", value: 66.8 },
    { at: "2026-10-29T10:00:00Z", value: 66.9 },
    { at: "2026-10-29T22:00:00Z", value: 66.95 },
    { at: "2026-10-30T09:00:00Z", value: 67 },
  ];

  it("appends each closed Madrid day, not today", () => {
    const daily = appendClosedDays([["2026-10-27", 66.7]], readings, now);
    expect(daily).toEqual([
      ["2026-10-27", 66.7],
      ["2026-10-28", 66.8],
      ["2026-10-29", 66.95],
    ]);
  });

  it("is idempotent, sorted and deduplicated", () => {
    const once = appendClosedDays([["2026-10-27", 66.7], ["2026-10-26", 66.6], ["2026-10-27", 66.7]], readings, now);
    expect(appendClosedDays(once, readings, now)).toEqual(once);
    expect(once.map(([date]) => date)).toEqual(["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29"]);
  });

  it("refines the newest stored day but never rewrites older ones", () => {
    const daily = appendClosedDays([["2026-10-28", 1], ["2026-10-29", 2]], readings, now);
    expect(daily).toEqual([
      ["2026-10-28", 1],
      ["2026-10-29", 66.95],
    ]);
  });

  it("treats the last hour before midnight as part of that day", () => {
    // 22:30 UTC on 29 October is 23:30 in Madrid (winter time), still the 29th.
    const daily = appendClosedDays([], [{ at: "2026-10-29T22:30:00Z", value: 5 }], new Date("2026-10-29T23:10:00Z"));
    expect(daily).toEqual([["2026-10-29", 5]]);
  });
});

/** Serves the recorded stations; the others are down. */
const hourlyFetcher: Fetcher = async (path) => {
  const stations: Record<string, string> = {
    E_17: "station-e17.json",
    E_20: "station-e20.json",
    P_37: "station-p37.json",
  };
  if (path === MAIN_STATION.path) return fixture("station-e19.json");
  const config = [...NEIGHBOURS, ...RAIN_GAUGES].find((c) => c.path === path);
  const file = config && stations[config.code];
  if (!file) throw new Error("station down");
  return fixture(file);
};

describe("hourly job", () => {
  const fetcher = hourlyFetcher;

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

  it("appends the closed day to each seeded history", async () => {
    const histories = new Map<HistoryId, History>([
      ["san-juan", seeded([["2026-10-28", 66.8]])],
      ["burguillo", seeded()],
      ["picadas", seeded()],
    ]);
    const store = memoryStore(snapshot(), histories);
    await runHourly(store, now, fetcher);

    expect(histories.get("san-juan")?.daily.map(([date]) => date)).toEqual(["2026-10-28", "2026-10-29"]);
    expect(histories.get("san-juan")?.generatedAt).toBe(toInstant(now));
    expect(histories.get("burguillo")?.daily.map(([date]) => date)).toEqual(["2026-10-29"]);
    expect(histories.get("san-juan")?.weekly).toEqual(seeded().weekly);
    // The E_20 recording is from 7 November, which is after `now`: nothing closed yet for Picadas.
    expect(histories.get("picadas")?.daily).toEqual([]);
    expect(store.historyWrites).toEqual(["san-juan", "burguillo"]);

    // A second run in the same hour changes nothing and writes nothing.
    await runHourly(store, now, fetcher);
    expect(store.historyWrites).toEqual(["san-juan", "burguillo"]);
  });

  it("closes Picadas' day from its own readings", () => {
    const picadas = parseStation(fixture("station-e20.json"), "E_20");
    const volume = picadas.signals.find((signal) => signal.type === "VE")!;
    expect(volume.readings).toHaveLength(24);
    const daily = appendClosedDays([], volume.readings, new Date(volume.readings.at(-1)!.at));
    expect(daily).toHaveLength(1);
    const [date, value] = daily[0]!;
    expect(value).toBe(volume.readings.filter((r) => madridDay(r.at) === date).at(-1)!.value);
  });

  it("leaves unseeded histories alone", async () => {
    const store = memoryStore(snapshot());
    await runHourly(store, now, fetcher);
    expect(store.historyWrites).toEqual([]);
  });

  it("adds the forecast and keeps publishing when AEMET fails", async () => {
    const forecast = parseForecast(fixture("aemet-28133-diaria.json"), now);
    const good = memoryStore(snapshot());
    const { snapshot: withForecast } = await runHourly(good, now, fetcher, async () => forecast);
    expect(withForecast.forecast).toEqual(forecast);

    const failing = memoryStore(snapshot());
    const { snapshot: without } = await runHourly(failing, now, fetcher, async () => {
      throw new Error("AEMET down");
    });
    expect(without.forecast).toBeUndefined();
    expect(failing.written).toHaveLength(1);
  });
});

describe("weekly job and backfill", () => {
  const rows = (capacity: number) => [
    { date: "2026-10-20", volumeHm3: capacity / 2, capacityHm3: capacity },
    { date: "2026-10-27", volumeHm3: capacity / 2 + 1, capacityHm3: capacity },
  ];
  const download = (byReservoir: MitecoDownload["byReservoir"]): MitecoDownload => ({
    lastModified: "Tue, 03 Nov 2026 10:00:00 GMT",
    rows: byReservoir["san-juan"],
    byReservoir,
  });

  it("finds the three reservoirs by their MITECO names", () => {
    const record = (name: string, total: string) => ({
      FECHA: "2026-11-03T00:00:00Z",
      AMBITO_NOMBRE: "Tajo",
      EMBALSE_NOMBRE: name,
      AGUA_TOTAL: total,
      AGUA_ACTUAL: "10,00",
    });
    const byReservoir = rowsByReservoir([
      record("San Juan", "138,00"),
      record("Burguillo - Puente Nuevo", "201,00"),
      record("Picadas", "15,00"),
      record("Burguillo", "1,00"),
    ]);
    expect(byReservoir["san-juan"].map((r) => r.capacityHm3)).toEqual([138]);
    expect(byReservoir.burguillo.map((r) => r.capacityHm3)).toEqual([201]);
    expect(byReservoir.picadas.map((r) => r.capacityHm3)).toEqual([15]);
  });

  it("updates the weekly rows of every history and keeps their daily rows", async () => {
    const histories = new Map<HistoryId, History>([["burguillo", seeded([["2026-10-29", 80]])]]);
    const store = memoryStore(snapshot(), histories);
    await applyWeekly(store, download({ "san-juan": rows(138), burguillo: rows(201), picadas: [] }), now);

    expect(histories.get("san-juan")?.weekly).toEqual([
      ["2026-10-20", 69, 138],
      ["2026-10-27", 70, 138],
    ]);
    expect(histories.get("burguillo")).toMatchObject({ daily: [["2026-10-29", 80]], weekly: [["2026-10-20", 100.5, 201], ["2026-10-27", 101.5, 201]] });
    // No MITECO rows for Picadas (a renamed reservoir, say) leaves its history untouched.
    expect(histories.has("picadas")).toBe(false);
  });

  it("seeds San Juan and both neighbours from SAIH's long series", { timeout: 30_000 }, async () => {
    const chartUrls = new Set<string>();
    for (const file of ["station-e19.json", "station-e17.json", "station-e20.json"]) {
      const body = fixture(file) as { response: { senales: Array<{ url: string }> } };
      for (const signal of body.response.senales) chartUrls.add(signal.url);
    }
    const backfillFetcher: Fetcher = async (path) => {
      if (chartUrls.has(path)) return { response: { url10anos: "long" } };
      if (path === "long") return fixture("long-e19-volume.json");
      return hourlyFetcher(path);
    };
    const histories = new Map<HistoryId, History>([["picadas", seeded([["2001-01-01", 12]])]]);
    const store = memoryStore(undefined, histories);
    await runBackfill(store, download({ "san-juan": rows(138), burguillo: rows(201), picadas: rows(15) }), now, backfillFetcher);

    const long = parseLongSeries(fixture("long-e19-volume.json"));
    for (const id of ["san-juan", "burguillo", "picadas"] as const) {
      const daily = histories.get(id)!.daily;
      expect(daily.length).toBeGreaterThanOrEqual(long.length);
      expect(daily.map(([date]) => date)).toEqual([...new Set(daily.map(([date]) => date))].sort());
    }
    expect(histories.get("picadas")!.daily[0]).toEqual(["2001-01-01", 12]);
    expect(histories.get("burguillo")!.weekly.at(-1)).toEqual(["2026-10-27", 101.5, 201]);
    expect(store.written).toHaveLength(1);
  });
});

describe("AEMET forecast", () => {
  const issued = new Date("2026-11-07T09:30:00Z");
  const forecast = () => parseForecast(fixture("aemet-28133-diaria.json"), issued);

  it("reads seven days, using the periods left when today's total is blank", () => {
    const f = forecast();
    expect(f.issuedAt).toBe("2026-11-07T07:59:00Z");
    expect(f.fetchedAt).toBe("2026-11-07T09:30:00Z");
    expect(f.days).toHaveLength(7);
    expect(f.days[0]).toEqual({ date: "2026-11-07", rainProbabilityPct: 0, maxTemperatureC: 19, minTemperatureC: 6 });
    expect(f.days[1]).toEqual({ date: "2026-11-08", rainProbabilityPct: 80, maxTemperatureC: 16, minTemperatureC: 8 });
    expect(f.days.at(-1)).toEqual({ date: "2026-11-13", rainProbabilityPct: 100, maxTemperatureC: 15, minTemperatureC: 8 });
  });

  it("drops the days that have passed", () => {
    const f = parseForecast(fixture("aemet-28133-diaria.json"), new Date("2026-11-09T08:00:00Z"));
    expect(f.days.map((d) => d.date)).toEqual(["2026-11-09", "2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13"]);
  });

  it("rejects an unexpected reply", () => {
    expect(() => parseForecast({ estado: 404 }, issued)).toThrow(/unexpected shape/);
    expect(() => parseForecast(fixture("aemet-28133-diaria.json"), new Date("2026-12-01T00:00:00Z"))).toThrow(/no days/);
  });

  it("follows the link in AEMET's first reply", async () => {
    const calls: string[] = [];
    const f = await fetchForecast(async (url) => {
      calls.push(url);
      if (url.includes("/diaria/28133")) return { descripcion: "exito", estado: 200, datos: "https://opendata.aemet.es/opendata/sh/abc" };
      return fixture("aemet-28133-diaria.json");
    }, issued);
    expect(calls).toEqual([
      "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/diaria/28133",
      "https://opendata.aemet.es/opendata/sh/abc",
    ]);
    expect(f.days).toHaveLength(7);
  });

  it("fails when AEMET refuses the key", async () => {
    await expect(fetchForecast(async () => ({ descripcion: "API key invalido", estado: 401 }), issued)).rejects.toThrow(/401/);
  });

  describe("refresh", () => {
    const later = (hours: number) => new Date(issued.getTime() + hours * 3_600_000);
    const counting = () => {
      const source = vi.fn<ForecastSource>(async (at) => ({ ...forecast(), fetchedAt: toInstant(at) }));
      return source;
    };
    const failing: ForecastSource = async () => {
      throw new Error("AEMET down");
    };

    it("keeps a recent forecast without asking AEMET", async () => {
      const source = counting();
      expect(await refreshForecast(forecast(), source, later(1))).toEqual(forecast());
      expect(source).not.toHaveBeenCalled();
    });

    it("asks again once the forecast is a few hours old", async () => {
      const source = counting();
      const f = await refreshForecast(forecast(), source, later(4));
      expect(source).toHaveBeenCalledOnce();
      expect(f?.fetchedAt).toBe(toInstant(later(4)));
    });

    it("keeps the old forecast for a day when AEMET fails, minus past days", async () => {
      const kept = (await refreshForecast(forecast(), failing, later(20))) as Forecast;
      expect(kept.days[0]?.date).toBe("2026-11-08");
      expect(await refreshForecast(forecast(), failing, later(25))).toBeUndefined();
      expect(await refreshForecast(forecast(), null, later(25))).toBeUndefined();
    });

    it("has no forecast without a key", async () => {
      expect(await refreshForecast(undefined, null, issued)).toBeUndefined();
    });
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
