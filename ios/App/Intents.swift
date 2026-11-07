import AppIntents
import EmbalseKit

/// "¿Cuánta agua hay en San Juan?": Siri, Spotlight and Shortcuts answer with the figure, its volume, its trend and
/// its source, without opening the app.
struct ReservoirLevelIntent: AppIntent {
    static let title: LocalizedStringResource = "Nivel del embalse"
    static let description = IntentDescription("Cuánta agua hay en el embalse de San Juan ahora mismo.")

    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let snapshot = try await SnapshotRepository().load().snapshot
        let live = snapshot.live
        let answer = String(localized: "San Juan está al \(Format.percent(live.percent)): \(Format.volumeOfCapacity(live.volumeHm3, snapshot.weekly.capacityHm3)). \(Trend.sentence(live.trend24hHm3)). \(Format.saihSource(live.observedAt)).")
        return .result(value: live.percent, dialog: IntentDialog(stringLiteral: answer))
    }
}

struct EmbalseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReservoirLevelIntent(),
            phrases: [
                "¿Cuánta agua hay en \(.applicationName)?",
                "Nivel de \(.applicationName)",
                "How much water is in \(.applicationName)?",
            ],
            shortTitle: "Nivel del embalse",
            systemImageName: "drop.fill"
        )
    }
}
