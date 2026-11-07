import AppIntents
import EmbalseKit
import SwiftUI
import WidgetKit

struct ComplicationView: View {
    var entry: ReservoirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: CircularLockWidgetView(snapshot: entry.snapshot, reservoir: entry.reservoir)
        case .accessoryCorner: CornerWatchWidgetView(snapshot: entry.snapshot, reservoir: entry.reservoir)
        case .accessoryInline: InlineLockWidgetView(snapshot: entry.snapshot, reservoir: entry.reservoir)
        default: RectangularLockWidgetView(snapshot: entry.snapshot, reservoir: entry.reservoir)
        }
    }
}

struct ReservoirComplication: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ReservoirComplication", intent: SelectReservoirIntent.self, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("San Juan")
        .description("El nivel del embalse en la esfera.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct ComplicationProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ReservoirEntry { ReservoirTimeline.placeholder() }

    func snapshot(for configuration: SelectReservoirIntent, in context: Context) async -> ReservoirEntry {
        context.isPreview ? ReservoirTimeline.preview(configuration.reservoir.reservoir) : await ReservoirTimeline.entry(configuration.reservoir.reservoir)
    }

    func timeline(for configuration: SelectReservoirIntent, in context: Context) async -> Timeline<ReservoirEntry> {
        let entry = await ReservoirTimeline.entry(configuration.reservoir.reservoir)
        return Timeline(entries: [entry], policy: .after(ReservoirTimeline.nextRefresh(after: .now)))
    }

    /// The watch offers complications without asking the user to configure them first.
    func recommendations() -> [AppIntentRecommendation<SelectReservoirIntent>] {
        ReservoirChoice.allCases.map { AppIntentRecommendation(intent: SelectReservoirIntent(reservoir: $0), description: Text(verbatim: $0.reservoir.name)) }
    }
}

@main
struct EmbalseWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReservoirComplication()
    }
}
