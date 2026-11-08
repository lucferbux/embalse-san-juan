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
                .containerBackground(for: .widget) { WidgetSky() }
        }
        .configurationDisplayName("Ahora")
        .description("El nivel del embalse de un vistazo.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

/// The sky behind the level widgets, removed by the system on tinted and clear screens.
struct WidgetSky: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View { Rectangle().fill(Palette.sky(scheme)) }
}

/// Like `ConfigurableProvider`, with the reservoir's history for the year's surface.
struct HistoryProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ReservoirEntry { ReservoirTimeline.placeholder() }

    func snapshot(for configuration: SelectReservoirIntent, in context: Context) async -> ReservoirEntry {
        context.isPreview
            ? ReservoirTimeline.preview(configuration.reservoir.reservoir, withHistory: true)
            : await ReservoirTimeline.entry(configuration.reservoir.reservoir, withHistory: true)
    }

    func timeline(for configuration: SelectReservoirIntent, in context: Context) async -> Timeline<ReservoirEntry> {
        let entry = await ReservoirTimeline.entry(configuration.reservoir.reservoir, withHistory: true)
        return Timeline(entries: [entry], policy: .after(ReservoirTimeline.nextRefresh(after: .now)))
    }
}

/// San Juan with its history, for the MITECO comparison and the river.
struct SanJuanHistoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReservoirEntry { ReservoirTimeline.placeholder() }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ReservoirEntry) -> Void) {
        if context.isPreview { return completion(ReservoirTimeline.preview(.sanJuan, withHistory: true)) }
        Task { completion(await ReservoirTimeline.entry(.sanJuan, withHistory: true)) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ReservoirEntry>) -> Void) {
        Task {
            let entry = await ReservoirTimeline.entry(.sanJuan, withHistory: true)
            completion(Timeline(entries: [entry], policy: .after(ReservoirTimeline.nextRefresh(after: .now))))
        }
    }
}

struct YearWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "YearWidget", intent: SelectReservoirIntent.self, provider: HistoryProvider()) { entry in
            YearWidgetView(snapshot: entry.snapshot, now: entry.date, reservoir: entry.reservoir, history: entry.history)
                .containerBackground(for: .widget) { WidgetSky() }
        }
        .configurationDisplayName("Último año")
        .description("Los últimos 12 meses del embalse, con el año anterior. SAIH Tajo.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

struct ComparisonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ComparisonWidget", provider: SanJuanHistoryProvider()) { entry in
            ComparisonWidgetView(snapshot: entry.snapshot, history: entry.history)
                .containerBackground(for: .widget) { Palette.water(entry.snapshot.live.percent) }
        }
        .configurationDisplayName("Este año y la media")
        .description("San Juan este año, el anterior, la media de 10 años y el rango desde 1988. MITECO.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

struct RiverWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RiverWidget", provider: ReservoirProvider()) { entry in
            RiverWidgetView(snapshot: entry.snapshot, now: entry.date)
                .containerBackground(for: .widget) { WidgetSky() }
        }
        .configurationDisplayName("El río")
        .description("Burguillo, San Juan y Picadas, de aguas arriba a aguas abajo.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
        YearWidget()
        ComparisonWidget()
        RiverWidget()
        ReservoirLockWidget()
        LevelControl()
    }
}
