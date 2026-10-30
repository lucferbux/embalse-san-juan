import { downloadWeeklyRows } from "../sources/miteco.js";
import { firestoreStore } from "../store/firestore.js";
import { applyWeekly } from "./run.js";

const store = firestoreStore();
const download = await downloadWeeklyRows(await store.readMitecoVersion());
if (download) {
  await applyWeekly(store, download, new Date());
  console.log(`Applied MITECO archive up to ${download.rows.at(-1)?.date}`);
} else {
  console.log("MITECO archive unchanged");
}
