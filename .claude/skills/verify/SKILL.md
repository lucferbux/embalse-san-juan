---
name: verify
description: Run the full verification for this project before saying work is done. Use after any change to the backend, contract, app or widgets.
---

# Verify

1. Run `make check`. Everything must pass.
2. If `backend/src/sources` or the contract changed, run `make live-check`.
3. If the contract changed, run `make fixture` and make sure `git diff contract/` shows what you expected.
4. If the app or widgets changed, run `make widgets`, then open the images in `build/widget-snapshots/` and look at them. A passing test doesn't prove a widget looks right. Use the `run-ios` skill to check the app.
5. If the data pipeline changed, trigger the workflow with `gh workflow run "Ingest hourly"`, then read `public/snapshot`:

   ```bash
   curl -s 'https://firestore.googleapis.com/v1/projects/embalse-san-juan/databases/(default)/documents/public/snapshot' | jq -r '.fields.payload.stringValue | fromjson | .live'
   ```

Report what you ran and what you could not check. Don't say it works if a step was skipped.
