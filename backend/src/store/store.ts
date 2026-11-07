import type { HistoryId } from "../config.js";
import type { History, Snapshot, WeeklyRow } from "../domain/types.js";
import type { Reading } from "../sources/saih.js";

export interface HourlyArchive {
  /** Keyed by Madrid day, then signal tag. */
  [day: string]: { [tag: string]: Reading[] };
}

export interface Store {
  readSnapshot(): Promise<Snapshot | undefined>;
  writeSnapshot(snapshot: Snapshot): Promise<void>;
  /** San Juan's history unless another reservoir is named. */
  readHistory(id?: HistoryId): Promise<History | undefined>;
  writeHistory(history: History, id?: HistoryId): Promise<void>;
  /** Idempotent: writing the same reading twice leaves one copy. */
  archiveReadings(archive: HourlyArchive): Promise<void>;
  archiveWeekly(rows: readonly WeeklyRow[]): Promise<void>;
  readMitecoVersion(): Promise<string | null>;
  writeMitecoVersion(lastModified: string): Promise<void>;
}
