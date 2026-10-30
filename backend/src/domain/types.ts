/** TypeScript view of contract/snapshot.schema.json. The schema is what gets enforced. */
export interface DailyPoint {
  date: string;
  volumeHm3: number;
}

export interface RecentReading {
  at: string;
  volumeHm3: number;
  percent: number;
  outflowM3s: number | null;
}

export interface WeeklySummary {
  date: string;
  volumeHm3: number;
  capacityHm3: number;
  percent: number;
  changeHm3: number;
  lastYearHm3: number | null;
  tenYearAvgHm3: number | null;
}

export interface Snapshot {
  schemaVersion: 1;
  generatedAt: string;
  reservoir: {
    id: string;
    name: string;
    river: string;
    basin: string;
    province: string;
    municipality: string;
    damType: string;
    yearBuilt: number;
    surfaceHa: number;
    uses: string[];
  };
  live: {
    observedAt: string;
    volumeHm3: number;
    percent: number;
    elevationM: number | null;
    levelM: number | null;
    trend24hHm3: number;
    outflowM3s: number | null;
    transferM3s: number | null;
  };
  recent: RecentReading[];
  daily: DailyPoint[];
  weather: {
    observedAt: string;
    temperatureC: number | null;
    windMs: number | null;
    windDirectionDeg: number | null;
    humidityPct: number | null;
    pressureHpa: number | null;
    solarWm2: number | null;
    rain1hMm: number | null;
    rain24hMm: number | null;
  };
  weekly: WeeklySummary;
  neighbours: Array<{
    code: string;
    name: string;
    position: "upstream" | "downstream";
    observedAt: string;
    volumeHm3: number;
    percent: number;
  }>;
  rainGauges: Array<{
    code: string;
    name: string;
    observedAt: string;
    rain1hMm: number | null;
    rain24hMm: number | null;
  }>;
  sources: Array<{ name: string; publisher: string; url: string; note: string }>;
}

/** Payload of public/history, in compact rows to keep the document small. */
export interface History {
  schemaVersion: 1;
  generatedAt: string;
  /** [date, volumeHm3, capacityHm3] from MITECO. */
  weekly: Array<[string, number, number]>;
  /** [date, volumeHm3] from SAIH, last value of each day. */
  daily: Array<[string, number]>;
}

export interface WeeklyRow {
  date: string;
  volumeHm3: number;
  capacityHm3: number;
}
