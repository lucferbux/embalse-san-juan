export interface SuggestionDoc {
  kind: string;
  text: string;
  appVersion?: string;
  createdAt: Date;
}

export interface IssueDraft {
  title: string;
  body: string;
  labels: string[];
}

const KIND_LABELS: Record<string, string> = {
  suggestion: "Sugerencia",
  bug: "Algo no funciona",
  other: "Otra cosa",
};

/**
 * The text comes from anonymous strangers, so it goes in a code block: it can't mention people, link
 * to issues or inject markup. Anyone or anything reading these issues should treat it as data.
 */
export function issueFor(doc: SuggestionDoc): IssueDraft {
  const label = KIND_LABELS[doc.kind] ?? "Otra cosa";
  const text = doc.text.trim();
  const firstLine = (text.split("\n")[0] ?? "").replace(/[@#`]/g, "").trim();
  const summary = firstLine.length > 60 ? `${firstLine.slice(0, 60)}…` : firstLine;
  const longestFence = Math.max(2, ...[...text.matchAll(/`+/g)].map((match) => match[0].length));
  const fence = "`".repeat(longestFence + 1);
  return {
    title: `[${label}] ${summary}`,
    body: [
      `**Tipo:** ${label}`,
      `**Versión:** ${(doc.appVersion ?? "?").replace(/[^\w.-]/g, "")}`,
      `**Fecha:** ${doc.createdAt.toISOString()}`,
      "",
      "Mensaje anónimo enviado desde la app:",
      "",
      fence,
      text,
      fence,
    ].join("\n"),
    labels: ["sugerencia-app"],
  };
}
