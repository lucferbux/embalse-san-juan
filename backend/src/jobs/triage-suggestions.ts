/**
 * Turns suggestions sent from the app into GitHub issues in this private repo, so they arrive by email,
 * then deletes them from Firestore. Text written by strangers stays in one place, for as little time as possible.
 */
import { connect } from "../store/firestore.js";
import { issueFor, type SuggestionDoc } from "../domain/suggestions.js";

const repo = process.env.GITHUB_REPOSITORY;
const token = process.env.GITHUB_TOKEN;
if (!repo || !token) throw new Error("GITHUB_REPOSITORY and GITHUB_TOKEN must be set");

const db = connect();
const pending = await db.collection("suggestions").orderBy("createdAt").limit(50).get();
console.log(`${pending.size} pending suggestion(s)`);

for (const doc of pending.docs) {
  const data = doc.data() as Omit<SuggestionDoc, "createdAt"> & { createdAt: { toDate(): Date } };
  const issue = issueFor({ ...data, createdAt: data.createdAt.toDate() });
  const response = await fetch(`https://api.github.com/repos/${repo}/issues`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json", "User-Agent": "embalse-san-juan" },
    body: JSON.stringify(issue),
  });
  if (!response.ok) throw new Error(`GitHub returned HTTP ${response.status}: ${await response.text()}`);
  // Only once the issue exists: a failure here means a duplicate at worst, never a lost message.
  await doc.ref.delete();
}
