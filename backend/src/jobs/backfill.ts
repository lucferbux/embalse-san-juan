import { downloadWeeklyRows } from "../sources/miteco.js";
import { firestoreStore } from "../store/firestore.js";
import { runBackfill } from "./run.js";

const download = await downloadWeeklyRows();
if (!download) throw new Error("MITECO download returned nothing");
const snapshot = await runBackfill(firestoreStore(), download, new Date());
console.log(`Seeded ${download.rows.length} weeks; live ${snapshot.live.volumeHm3} hm³ at ${snapshot.live.observedAt}`);
