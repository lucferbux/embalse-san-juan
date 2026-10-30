# CLAUDE.md

App iOS 27 and free backend showing the state of the San Juan reservoir (Alberche river, Madrid).
[AGENTS.md](AGENTS.md) is the portable summary: **update both together.**

## Repo

This is its own git repo, `lucferbux/embalse-san-juan`, nested in the Tech monorepo and ignored by it.
Check `git rev-parse --show-toplevel` before committing. Commits: Conventional Commits (`feat(ios): …`,
`fix(backend): …`). Docs and code are in English; the app's text is in Spanish.

## Commands (run from this directory)

| Command | What it does |
|---|---|
| `make check` | Secret scan, backend types and tests, iOS build and tests. **Run before saying work is done.** |
| `make check-backend` | Backend only, about 15 s. |
| `make live-check` | Calls the real sources without writing. Run after touching `backend/src/sources`. |
| `make widgets` | Renders every widget to `build/widget-snapshots/`. Look at them after any widget change. |
| `make fixture` | Rebuilds `contract/fixtures/snapshot.json`. |
| `make generate` | Regenerates the Xcode project from `ios/project.yml`. Never edit the `.xcodeproj`. |

## How it fits together

```
SAIH Tajo (hourly) ─┐
                    ├─ GitHub Actions ─ backend/ ─ Firestore public/* ─ REST ─ EmbalseKit ─ App + Widgets
MITECO (weekly) ────┘
```

- `contract/snapshot.schema.json` is the contract. The backend validates against it before publishing,
  and the Swift tests decode the same fixture. Changing it means changing both sides and `make fixture`.
- `backend/src/domain/validate.ts` is the guard: if a check fails, nothing is written and the workflow fails.
- `ios/EmbalseKit` holds all logic and views. The app and widget targets stay thin.

## Rules

- **Never mix SAIH and MITECO figures.** They differ, sometimes by several hm³. The big number is SAIH;
  the weekly block is MITECO. Always show the source and date.
- **Only official sources.** Do not scrape embalses.net.
- **Be polite to SAIH:** requests in series with a pause, no more often than hourly. See `docs/DATA_SOURCES.md`.
- **No Firebase SDK in iOS:** widgets have tight memory limits. Clients use the Firestore REST API.
- **Native first:** system components, SF Symbols, semantic colours, Dynamic Type, dark mode.
- **Secrets:** the service account key lives only in the GitHub secret `FIREBASE_SERVICE_ACCOUNT`.
  Never write it to a file in this repo or print it. A hook blocks the obvious cases.
- **GitHub minutes:** the hourly cron uses about 720 of the 2,000 free minutes a month. Don't add
  scheduled jobs or macOS CI without working out the cost.

## Skills

- `verify`: full check before finishing work.
- `debug-source`: what to do when a data source changes or a workflow fails.
- `run-ios`: build, run and inspect the app and widgets in the simulator.
