import { unzipSync } from "fflate";
import MDBReader from "mdb-reader";
import { MITECO_ZIP_URL, USER_AGENT } from "../config.js";
import type { WeeklyRow, WeeklySummary } from "../domain/types.js";

const RESERVOIR_NAME = "San Juan";
const BASIN_NAME = "Tajo";
const SAME_WEEK_TOLERANCE_DAYS = 3;
const DAY_MS = 86_400_000;

export interface MitecoDownload {
  lastModified: string | null;
  rows: WeeklyRow[];
}

/** Returns null when the archive has not changed since `knownLastModified`. */
export async function downloadWeeklyRows(knownLastModified?: string | null): Promise<MitecoDownload | null> {
  const headers = { "User-Agent": USER_AGENT };
  const head = await fetch(MITECO_ZIP_URL, { method: "HEAD", headers, signal: AbortSignal.timeout(60_000) });
  if (!head.ok) throw new Error(`MITECO HEAD returned HTTP ${head.status}`);
  const lastModified = head.headers.get("last-modified");
  if (knownLastModified && lastModified === knownLastModified) return null;

  const response = await fetch(MITECO_ZIP_URL, { headers, signal: AbortSignal.timeout(300_000) });
  if (!response.ok) throw new Error(`MITECO download returned HTTP ${response.status}`);
  const zip = new Uint8Array(await response.arrayBuffer());
  return { lastModified, rows: parseArchive(zip) };
}

export function parseArchive(zip: Uint8Array): WeeklyRow[] {
  const entry = Object.entries(unzipSync(zip)).find(([name]) => name.toLowerCase().endsWith(".mdb"));
  if (!entry) throw new Error("MITECO archive has no .mdb file");
  const reader = new MDBReader(Buffer.from(entry[1]));
  // The year in the table name changes over time: "T_Datos Embalses 1988-2026".
  const tableName = reader.getTableNames().find((name) => name.startsWith("T_Datos Embalses"));
  if (!tableName) throw new Error(`No data table in MITECO database: ${reader.getTableNames().join(", ")}`);
  const records = reader
    .getTable(tableName)
    .getData({ columns: ["FECHA", "AMBITO_NOMBRE", "EMBALSE_NOMBRE", "AGUA_TOTAL", "AGUA_ACTUAL"] });
  return rowsFromRecords(records);
}

/** MITECO stores numbers as text with a decimal comma ("138,00"). */
function toNumber(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(String(value).trim().replace(",", "."));
  if (!Number.isFinite(parsed)) throw new Error(`Not a number in MITECO data: ${String(value)}`);
  return parsed;
}

function toDay(value: unknown): string {
  const date = value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(date.getTime())) throw new Error(`Not a date in MITECO data: ${String(value)}`);
  return date.toISOString().slice(0, 10);
}

export function rowsFromRecords(records: ReadonlyArray<Record<string, unknown>>): WeeklyRow[] {
  return records
    .filter(
      (record) =>
        String(record.EMBALSE_NOMBRE).trim() === RESERVOIR_NAME && String(record.AMBITO_NOMBRE).trim() === BASIN_NAME,
    )
    .map((record) => ({
      date: toDay(record.FECHA),
      volumeHm3: toNumber(record.AGUA_ACTUAL),
      capacityHm3: toNumber(record.AGUA_TOTAL),
    }))
    .sort((a, b) => a.date.localeCompare(b.date));
}

function sameWeekOfYear(rows: readonly WeeklyRow[], date: string, year: number): WeeklyRow | undefined {
  const target = new Date(date);
  target.setUTCFullYear(year);
  return rows.find(
    (row) => Math.abs(new Date(row.date).getTime() - target.getTime()) <= SAME_WEEK_TOLERANCE_DAYS * DAY_MS,
  );
}

export function summarise(rows: readonly WeeklyRow[]): WeeklySummary {
  const latest = rows.at(-1);
  const previous = rows.at(-2);
  if (!latest || !previous) throw new Error("MITECO series is too short to summarise");

  const year = Number(latest.date.slice(0, 4));
  const pastTen = Array.from({ length: 10 }, (_, i) => sameWeekOfYear(rows, latest.date, year - 1 - i)).filter(
    (row): row is WeeklyRow => row !== undefined,
  );
  const lastYear = sameWeekOfYear(rows, latest.date, year - 1);

  return {
    date: latest.date,
    volumeHm3: latest.volumeHm3,
    capacityHm3: latest.capacityHm3,
    percent: round((latest.volumeHm3 / latest.capacityHm3) * 100),
    changeHm3: round(latest.volumeHm3 - previous.volumeHm3),
    lastYearHm3: lastYear?.volumeHm3 ?? null,
    tenYearAvgHm3:
      pastTen.length === 10 ? round(pastTen.reduce((sum, row) => sum + row.volumeHm3, 0) / pastTen.length) : null,
  };
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}
