const madridParts = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Europe/Madrid",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

function wallClock(date: Date): string {
  const p = Object.fromEntries(madridParts.formatToParts(date).map((x) => [x.type, x.value]));
  return `${p.year}-${p.month}-${p.day} ${p.hour}:${p.minute}`;
}

export function toInstant(date: Date): string {
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}

/** Madrid calendar day of an instant, as yyyy-mm-dd. */
export function madridDay(instant: string | Date): string {
  return wallClock(new Date(instant)).slice(0, 10);
}

/**
 * Parses a SAIH local time ("30/10/2026 16:00", optional trailing "h") into UTC.
 * Long daily series give only the date ("30/10/2021"), which becomes midday so it
 * stays on that Madrid day.
 *
 * The repeated hour when clocks go back has two valid answers. `after` is the
 * previous reading of an ascending series: the result is the earliest answer
 * later than it, which keeps the series strictly increasing.
 */
export function parseSaihTime(text: string, after?: Date): Date {
  const match = /^(\d{2})\/(\d{2})\/(\d{4})(?: (\d{2}):(\d{2}))?/.exec(text.trim());
  if (!match) throw new Error(`Unrecognised SAIH time: "${text}"`);
  const [, dd, mm, yyyy, hh = "12", min = "00"] = match;
  const wanted = `${yyyy}-${mm}-${dd} ${hh}:${min}`;
  const asUtc = Date.UTC(Number(yyyy), Number(mm) - 1, Number(dd), Number(hh), Number(min));

  const candidates = [2, 1]
    .map((offsetHours) => new Date(asUtc - offsetHours * 3_600_000))
    .filter((candidate) => wallClock(candidate) === wanted);

  if (candidates.length === 0) throw new Error(`Time does not exist in Madrid: "${text}"`);
  if (after) {
    const later = candidates.find((candidate) => candidate > after);
    if (later) return later;
  }
  return candidates[0]!;
}
