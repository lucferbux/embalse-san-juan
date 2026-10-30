---
name: debug-source
description: Diagnose a failing ingest workflow or a data source that changed or looks wrong (SAIH Tajo, MITECO). Use when a workflow fails, the app shows stale data, or live-check fails.
---

# Debug a data source

Read `docs/DATA_SOURCES.md` first.

1. See what failed: `gh run list --workflow "Ingest hourly" --limit 5`, then `gh run view <id> --log-failed`.
2. Reproduce without writing anything: `make live-check`. Add `-- --skip-miteco` to the npm script to skip the download.
3. Work out which case it is:

| Symptom | Likely cause | Fix |
|---|---|---|
| `Snapshot rejected` | The guard stopped bad data. Last good data is still live | Check whether the value is real on the SAIH site. Change a limit in `validate.ts` only if it is |
| `Update config.ts: E_19 now lives at …` in the log | The token changed and rediscovery worked | Copy the new path to `backend/src/config.ts` |
| `is not in the SAIH list` | The station code changed | Search `page-datos-tiempo-real` by name |
| `did not return JSON` or HTTP 403 | The site changed or is blocking | Open the site in a browser and watch its network requests |
| Works locally, fails on GitHub | GitHub's IPs are blocked | Stop and ask the user: the hosting decision needs revisiting (ADR 0001) |
| `Not a number in MITECO data` | The database format changed | Inspect the `.mdb`; the table name includes the year |

4. Record any new reply format as a fixture in `backend/test/fixtures/` and add a test before fixing it.
5. Keep requests polite: never add parallel requests or poll SAIH in a loop.
