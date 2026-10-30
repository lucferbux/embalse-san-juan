import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import type { ErrorObject } from "ajv";
import type { Snapshot } from "./types.js";

const require = createRequire(import.meta.url);
const { Ajv2020 } = require("ajv/dist/2020.js") as typeof import("ajv/dist/2020.js");

const schema = JSON.parse(
  readFileSync(new URL("../../../contract/snapshot.schema.json", import.meta.url), "utf8"),
) as object;
const validateSchema = new Ajv2020({ allErrors: true }).compile(schema);

/** The SAIH sensor's own upper limit for this reservoir, above the 138 hm³ nominal capacity. */
const MAX_PLAUSIBLE_VOLUME_HM3 = 152;
const MAX_HOURLY_JUMP_HM3 = 15;
const MAX_FUTURE_MS = 15 * 60_000;
const MAX_AGE_MS = 24 * 3_600_000;
const MAX_PERCENT_DRIFT = 5;

export class SnapshotRejected extends Error {}

/** Throws rather than publish, so bad data never replaces the last good snapshot. */
export function assertPublishable(snapshot: Snapshot, previous: Snapshot | undefined, now: Date): void {
  const problems: string[] = [];

  if (!validateSchema(snapshot)) {
    problems.push(
      ...(validateSchema.errors ?? []).map((error: ErrorObject) => `schema ${error.instancePath} ${error.message}`),
    );
  }

  const { volumeHm3, percent, observedAt } = snapshot.live;
  if (!(volumeHm3 >= 0 && volumeHm3 <= MAX_PLAUSIBLE_VOLUME_HM3)) problems.push(`implausible volume ${volumeHm3}`);
  if (!(percent >= 0 && percent <= 100)) problems.push(`implausible percent ${percent}`);

  const age = now.getTime() - new Date(observedAt).getTime();
  if (age < -MAX_FUTURE_MS) problems.push(`reading is in the future: ${observedAt}`);
  if (age > MAX_AGE_MS) problems.push(`reading is too old: ${observedAt}`);

  // SAIH volume and percent come from separate signals, so they should agree with each other.
  const impliedPercent = (volumeHm3 / snapshot.weekly.capacityHm3) * 100;
  if (Math.abs(impliedPercent - percent) > MAX_PERCENT_DRIFT) {
    problems.push(`volume ${volumeHm3} and percent ${percent} disagree (implied ${impliedPercent.toFixed(2)})`);
  }

  if (previous) {
    const hours = Math.max(1, (new Date(observedAt).getTime() - new Date(previous.live.observedAt).getTime()) / 3_600_000);
    const jump = Math.abs(volumeHm3 - previous.live.volumeHm3);
    if (jump > MAX_HOURLY_JUMP_HM3 * hours) {
      problems.push(`volume jumped ${jump.toFixed(2)} hm³ in ${hours.toFixed(1)} h`);
    }
  }

  if (problems.length > 0) throw new SnapshotRejected(`Snapshot rejected:\n- ${problems.join("\n- ")}`);
}
