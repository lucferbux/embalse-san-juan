import AppIntents
import EmbalseKit
import SwiftUI
import WidgetKit

struct HomeScreenView: View {
    var entry: ReservoirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: MediumWidgetView(snapshot: entry.snapshot, now: entry.date, reservoir: entry.reservoir, history: entry.history)
        case .systemLarge: LargeWidgetView(snapshot: entry.snapshot, now: entry.date, reservoir: entry.reservoir, history: entry.history)
        case .systemExtraLarge: ExtraLargeWidgetView(snapshot: entry.snapshot, now: entry.date, reservoir: entry.reservoir, history: entry.history)
        default: SmallWidgetView(snapshot: entry.snapshot, now: entry.date, reservoir: entry.reservoir, history: entry.history)
        }
    }
}

/// Home Screen and StandBy, with the reservoir chosen in the widget's settings.
struct ConfigurableProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ReservoirEntry { ReservoirTimeline.placeholder() }

    func snapshot(for configuration: SelectReservoirIntent, in context: Context) async -> ReservoirEntry {
        context.isPreview ? ReservoirTimeline.preview(configuration.reservoir.reservoir) : await ReservoirTimeline.entry(configuration.reservoir.reservoir)
    }

    func timeline(for configuration: SelectReservoirIntent, in context: Context) async -> Timeline<ReservoirEntry> {
        let entry = await ReservoirTimeline.entry(configuration.reservoir.reservoir)
        return Timeline(entries: [entry], policy: .after(ReservoirTimeline.nextRefresh(after: .now)))
    }
}

struct ReservoirWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ReservoirWidget", intent: SelectReservoirIntent.self, provider: ConfigurableProvider()) { entry in
            HomeScreenView(entry: entry)
                .containerBackground(for: .widget) { Color(red: 0.07, green: 0.20, blue: 0.40) }
        }
        .configurationDisplayName("Embalse de San Juan")
        .description("El nivel del embalse de un vistazo.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

struct LockScreenView: View {
    var entry: ReservoirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: CircularLockWidgetView(snapshot: entry.snapshot, reservoir: entry.reservoir)
        case .accessoryInline: InlineLockWidgetView(snapshot: entry.snapshot, reservoir: entry.reservoir)
        default: RectangularLockWidgetView(snapshot: entry.snapshot, reservoir: entry.reservoir)
        }
    }
}

struct ReservoirLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ReservoirLockWidget", intent: SelectReservoirIntent.self, provider: ConfigurableProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("San Juan")
        .description("El nivel del embalse en la pantalla de bloqueo.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// Control Center and the Action button: the current percentage, which opens the app.
struct LevelControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LevelControl", provider: LevelValueProvider()) { value in
            ControlWidgetButton(action: OpenReservoirIntent()) {
                Label(value, systemImage: "drop.fill")
            }
        }
        .displayName("San Juan")
        .description("El nivel del embalse. Toca para abrir la app.")
    }
}

struct LevelValueProvider: ControlValueProvider {
    var previewValue: String { Format.percent(48.7) }

    func currentValue() async throws -> String {
        let repository = SnapshotRepository()
        let snapshot = (try? await repository.load().snapshot) ?? repository.cached() ?? .placeholder
        return Format.percent(snapshot.live.percent)
    }
}

@main
struct EmbalseWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReservoirWidget()
        ReservoirLockWidget()
        LevelControl()
    }
}
