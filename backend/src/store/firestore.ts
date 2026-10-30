import { cert, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import type { History, Snapshot, WeeklyRow } from "../domain/types.js";
import type { HourlyArchive, Store } from "./store.js";

const SNAPSHOT = "public/snapshot";
const HISTORY = "public/history";
const MITECO_META = "meta/miteco";

/** Firestore limits a batch by size, so large backfills are split up. */
const MAX_BATCH_DOCS = 50;

export function connect(): Firestore {
  const key = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!key) throw new Error("FIREBASE_SERVICE_ACCOUNT is not set");
  const app = initializeApp({ credential: cert(JSON.parse(key) as object) });
  return getFirestore(app);
}

/**
 * Public documents hold the contract JSON in one string field, so clients decode
 * plain JSON instead of Firestore's verbose typed REST format.
 */
async function readPayload<T>(db: Firestore, path: string): Promise<T | undefined> {
  const doc = await db.doc(path).get();
  const payload = doc.get("payload") as string | undefined;
  return payload ? (JSON.parse(payload) as T) : undefined;
}

export function firestoreStore(db: Firestore = connect()): Store {
  return {
    readSnapshot: () => readPayload<Snapshot>(db, SNAPSHOT),
    readHistory: () => readPayload<History>(db, HISTORY),

    async writeSnapshot(snapshot) {
      await db.doc(SNAPSHOT).set({ payload: JSON.stringify(snapshot), generatedAt: snapshot.generatedAt });
    },

    async writeHistory(history) {
      await db.doc(HISTORY).set({ payload: JSON.stringify(history), generatedAt: history.generatedAt });
    },

    async archiveReadings(archive: HourlyArchive) {
      const days = Object.entries(archive);
      for (let i = 0; i < days.length; i += MAX_BATCH_DOCS) {
        const batch = db.batch();
        for (const [day, tags] of days.slice(i, i + MAX_BATCH_DOCS)) {
          const values: Record<string, Record<string, number>> = {};
          for (const [tag, readings] of Object.entries(tags)) {
            values[tag] = Object.fromEntries(readings.map((reading) => [reading.at, reading.value]));
          }
          batch.set(db.doc(`readings/${day}`), values, { merge: true });
        }
        await batch.commit();
      }
    },

    async archiveWeekly(rows: readonly WeeklyRow[]) {
      const byYear = new Map<string, WeeklyRow[]>();
      for (const row of rows) {
        const year = row.date.slice(0, 4);
        byYear.set(year, [...(byYear.get(year) ?? []), row]);
      }
      const years = [...byYear.entries()];
      for (let i = 0; i < years.length; i += MAX_BATCH_DOCS) {
        const batch = db.batch();
        for (const [year, yearRows] of years.slice(i, i + MAX_BATCH_DOCS)) {
          batch.set(db.doc(`weekly/${year}`), { rows: yearRows });
        }
        await batch.commit();
      }
    },

    async readMitecoVersion() {
      const doc = await db.doc(MITECO_META).get();
      return (doc.get("lastModified") as string | undefined) ?? null;
    },

    async writeMitecoVersion(lastModified) {
      await db.doc(MITECO_META).set({ lastModified });
    },
  };
}
