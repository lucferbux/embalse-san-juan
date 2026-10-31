# Embalse de San Juan

Native iOS 27 and Android apps, widgets and an Apple Watch app showing the live state of the San Juan reservoir, on the Alberche river in Madrid.

**Status:** In progress.

## How it works

GitHub Actions, started every hour by a Google Apps Script trigger, collect official data and publish it to Firestore. The app and widgets read it over REST.

| Source | Publisher | Frequency | Provides |
|---|---|---|---|
| [SAIH Tajo](https://saihtajo.chtajo.es/) | Confederación Hidrográfica del Tajo | Hourly | Volume, level, flows, weather, rain |
| [Boletín Hidrológico](https://www.miteco.gob.es/es/agua/temas/evaluacion-de-los-recursos-hidricos/boletin-hidrologico.html) | MITECO | Weekly | Weekly volume and the series since 1988 |

All data is provisional. This project is not affiliated with or endorsed by these bodies.
See [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md).

## Run it

Needs Xcode 27, Node 24, XcodeGen (`brew install xcodegen`), JDK 21 and the Android SDK.

```bash
make check
```

```bash
make generate && open ios/EmbalseSanJuan.xcodeproj
```

```bash
make run-android
```


## Backend setup

The Firebase project runs on the free Spark plan. The GitHub secret `FIREBASE_SERVICE_ACCOUNT` holds a service account key.
After setting it, run the **Backfill** workflow once. The Apps Script trigger takes over from there: see [ADR 2](docs/decisions/0002-external-scheduler.md).

## License

[MIT](LICENSE). The data belongs to its sources, listed above.
