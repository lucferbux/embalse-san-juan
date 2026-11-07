import { firestoreStore } from "../store/firestore.js";
import { aemetFromEnv } from "../sources/aemet.js";
import { httpFetcher } from "../sources/saih.js";
import { runHourly } from "./run.js";

const forecastSource = aemetFromEnv();
if (!forecastSource) console.warn("AEMET_API_KEY is not set: publishing without a forecast");
const { snapshot } = await runHourly(firestoreStore(), new Date(), httpFetcher, forecastSource);
console.log(`Published ${snapshot.live.volumeHm3} hm³ (${snapshot.live.percent} %) observed at ${snapshot.live.observedAt}`);
if (snapshot.forecast) console.log(`Forecast issued at ${snapshot.forecast.issuedAt}, ${snapshot.forecast.days.length} days`);
