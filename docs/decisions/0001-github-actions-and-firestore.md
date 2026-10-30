# 1. GitHub Actions and Firestore on the Spark plan

**Status:** Accepted, 30 October 2026.

## Context

The backend has to collect data hourly and serve it to an app, at no cost. Firebase Cloud Functions need the Blaze plan, which requires a card and could produce charges if something went wrong.

## Decision

Scheduled GitHub Actions in a private repo write to Firestore on the Spark plan. Clients read through the Firestore REST API, without the Firebase SDK.

## Consequences

- The cost is zero and cannot grow: on Spark, exceeding a quota returns errors, not a bill.
- GitHub's cron can run several minutes late, which is fine for hourly data.
- The hourly job uses about 720 of the 2,000 free minutes a month, which limits other scheduled jobs and rules out routine macOS CI.
- A service account key is stored as a GitHub secret.
- If SAIH blocks GitHub's IP ranges, this design needs revisiting.
