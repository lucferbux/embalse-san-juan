# 2. Start the workflows from Google Apps Script

**Status:** Accepted, 30 October 2026. Refines [ADR 1](0001-github-actions-and-firestore.md).

## Context

GitHub's `schedule` trigger never fired on this repo: 0 scheduled runs in hours, while manual runs always worked. The workflows were active, on the default branch, and moving the cron minute and re-registering it changed nothing. [Community reports](https://github.com/orgs/community/discussions/210906) describe the same on private repos in 2026, and none confirms a fix. Making the repo public didn't help either: a test workflow on `*/5 * * * *` ran 0 times in 90 minutes.

## Decision

An hourly Apps Script trigger in the owner's Google account calls `workflow_dispatch` for each job. The code is in `scripts/heartbeat/Code.gs`. It also checks the age of `public/snapshot` and emails the owner, at most once a day, if the data is over 3 hours old or GitHub refuses a dispatch.

Once the script is running, the workflows drop `schedule`, so nothing can run twice.

Google Cloud Scheduler was ruled out because it needs the Blaze plan, and third-party cron services because they would hold the token.

## Consequences

- It stays free, with no card and no new account.
- Apps Script triggers fire within about 15 minutes of the requested minute.
- It depends on a fine-grained GitHub token, limited to this repo with Actions read and write, stored as a script property. It expires after a year at most: the 401 triggers the email, and then a new token goes in the same property.
- The script lives outside the repo. After changing `Code.gs`, paste it into the Apps Script project.
