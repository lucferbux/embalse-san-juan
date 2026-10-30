import { firestoreStore } from "../store/firestore.js";
import { runHourly } from "./run.js";

const { snapshot } = await runHourly(firestoreStore(), new Date());
console.log(`Published ${snapshot.live.volumeHm3} hm³ (${snapshot.live.percent} %) observed at ${snapshot.live.observedAt}`);
