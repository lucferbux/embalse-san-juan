/**
 * Starts the GitHub workflows on time, because GitHub's own `schedule` is too irregular on this repo.
 * It runs in Google Apps Script, in the owner's Google account. See docs/decisions/0002-external-scheduler.md.
 *
 * Setup: add a script property GITHUB_TOKEN holding a fine-grained token limited to this repository,
 * with Actions: read and write. Then run `install` once from the editor and authorise it.
 */
const REPO = "lucferbux/embalse-san-juan";
const SNAPSHOT_URL =
  "https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents/public/snapshot";
const MAX_SNAPSHOT_AGE_HOURS = 3;
const HOURS_BETWEEN_ALERTS = 24;

/** Creates the hourly trigger, replacing any earlier one. */
function install() {
  ScriptApp.getProjectTriggers().forEach((trigger) => ScriptApp.deleteTrigger(trigger));
  ScriptApp.newTrigger("tick").timeBased().everyHours(1).nearMinute(41).inTimezone("Europe/Madrid").create();
  tick();
}

function tick() {
  const problems = [];
  const now = new Date();
  const hour = Number(Utilities.formatDate(now, "Europe/Madrid", "H"));
  const weekday = Number(Utilities.formatDate(now, "Europe/Madrid", "u")); // 1 is Monday

  // Checked first, so it reports on the run before this one.
  const age = snapshotAgeHours_(now);
  if (age === null) problems.push("No se ha podido leer public/snapshot.");
  else if (age > MAX_SNAPSHOT_AGE_HOURS) problems.push(`El dato publicado tiene ${age.toFixed(1)} horas.`);

  const workflows = ["ingest-hourly.yml"];
  // MITECO publishes on Tuesdays. Wednesday is a retry, and the job does nothing if nothing changed.
  if (hour === 16 && (weekday === 2 || weekday === 3)) workflows.push("ingest-weekly.yml");
  workflows.forEach((workflow) => {
    const problem = dispatch_(workflow);
    if (problem) problems.push(problem);
  });

  if (problems.length > 0) alert_(problems, now);
}

function dispatch_(workflow) {
  const token = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN");
  if (!token) return "Falta la propiedad GITHUB_TOKEN.";
  const response = UrlFetchApp.fetch(`https://api.github.com/repos/${REPO}/actions/workflows/${workflow}/dispatches`, {
    method: "post",
    contentType: "application/json",
    headers: { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json" },
    payload: JSON.stringify({ ref: "main" }),
    muteHttpExceptions: true,
  });
  const status = response.getResponseCode();
  if (status === 204) return null;
  const hint = status === 401 ? " El token de GitHub ha caducado o no es válido." : "";
  return `GitHub respondió ${status} al lanzar ${workflow}.${hint}`;
}

function snapshotAgeHours_(now) {
  try {
    const response = UrlFetchApp.fetch(SNAPSHOT_URL, { muteHttpExceptions: true });
    if (response.getResponseCode() !== 200) return null;
    const generatedAt = JSON.parse(response.getContentText()).fields.generatedAt.stringValue;
    return (now.getTime() - new Date(generatedAt).getTime()) / 3600000;
  } catch (error) {
    return null;
  }
}

/** Emails the script's owner, at most once a day so a long outage doesn't fill the inbox. */
function alert_(problems, now) {
  const properties = PropertiesService.getScriptProperties();
  const last = Number(properties.getProperty("LAST_ALERT") || 0);
  if (now.getTime() - last < HOURS_BETWEEN_ALERTS * 3600000) return;
  MailApp.sendEmail(
    Session.getEffectiveUser().getEmail(),
    "Embalse San Juan: la recogida de datos necesita atención",
    `${problems.join("\n")}\n\nEjecuciones: https://github.com/${REPO}/actions`,
  );
  properties.setProperty("LAST_ALERT", String(now.getTime()));
}
