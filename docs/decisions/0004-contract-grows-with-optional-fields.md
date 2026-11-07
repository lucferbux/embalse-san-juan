# 4. The contract only grows with optional fields while 1.0 is in the stores

**Status:** Accepted, 7 November 2026.

## Context

Version 1.0 is on the App Store and in Google Play testing, and people don't all update. Both 1.0 apps reject any snapshot whose `schemaVersion` is not 1 (`FirestoreClient.swift` in EmbalseKit, `SUPPORTED_SCHEMA` in `android/…/data/Remote.kt`): raising it would break every 1.0 install and its widgets at once. They do ignore keys they don't know, through Swift's `Codable` and Kotlin's `ignoreUnknownKeys`.

## Decision

While 1.0 can still be installed, `contract/snapshot.schema.json` stays at `schemaVersion` 1 and changes only by **adding optional fields**:

- No field is removed, renamed, made nullable or given a different type or meaning.
- New fields are optional (not in `required`), so the backend may omit them, and 2.0 apps must cope when they are missing.
- The schema keeps `additionalProperties: false`, so each new field is declared in it before the backend publishes it.
- New data that doesn't belong in the snapshot goes in new documents (`public/history-burguillo`, `public/history-picadas`), which 1.0 never reads.

The first additions are `forecast` in the snapshot and the two neighbour histories.

## Consequences

- 1.0 keeps working unchanged against the 2.0 backend.
- The schema accumulates some history. Cleaning it up means `schemaVersion` 2, served from new documents next to the old ones (for example `public/snapshot-v2`), and only once 1.0 is no longer in use. That would be its own ADR.
- `make fixture` must include the new optional fields, and the Swift and Kotlin tests must keep decoding the fixture: that is what proves the old apps still read it.
