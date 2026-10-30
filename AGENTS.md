# AGENTS.md

Portable summary for coding agents. [CLAUDE.md](CLAUDE.md) has the detail: **update both together.**

- **What:** iOS 27 app and widgets for the San Juan reservoir, fed by GitHub Actions and Firestore.
- **Repo:** own git repo, nested in the Tech monorepo and ignored by it.
- **Before finishing:** run `make check`. After changing sources, `make live-check`. After changing widgets, `make widgets` and look at the images.
- **Contract:** `contract/snapshot.schema.json`. Changes touch backend, Swift models and `make fixture`.
- **Xcode project:** generated from `ios/project.yml`. Never edit the `.xcodeproj`.
- **Never:** mix SAIH and MITECO figures, scrape embalses.net, add the Firebase SDK to iOS, or commit credentials.
