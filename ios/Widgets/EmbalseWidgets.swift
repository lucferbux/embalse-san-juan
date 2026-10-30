import EmbalseKit
import SwiftUI
import WidgetKit

struct ReservoirEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
}

struct ReservoirProvider: TimelineProvider {
    private let repository = SnapshotRepository()

    func placeholder(in context: Context) -> ReservoirEntry {
        ReservoirEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ReservoirEntry) -> Void) {
        if context.isPreview {
            completion(ReservoirEntry(date: .now, snapshot: repository.cached() ?? .placeholder))
            return
        }
        Task {
            let result = try? await repository.load()
            completion(ReservoirEntry(date: .now, snapshot: result?.snapshot ?? .placeholder))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ReservoirEntry>) -> Void) {
        Task {
            let result = try? await repository.load()
            let snapshot = result?.snapshot ?? repository.cached() ?? .placeholder
            let entry = ReservoirEntry(date: .now, snapshot: snapshot)
            completion(Timeline(entries: [entry], policy: .after(Self.nextRefresh(after: .now))))
        }
    }

    /// New data lands a few minutes after the collector's :17 run, so aim for just after that.
    static func nextRefresh(after date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.nextDate(after: date, matching: DateComponents(minute: 30), matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(3600)
    }
}

struct HomeScreenView: View {
    var entry: ReservoirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: MediumWidgetView(snapshot: entry.snapshot, now: entry.date)
        case .systemLarge: LargeWidgetView(snapshot: entry.snapshot, now: entry.date)
        default: SmallWidgetView(snapshot: entry.snapshot, now: entry.date)
        }
    }
}

struct ReservoirWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReservoirWidget", provider: ReservoirProvider()) { entry in
            HomeScreenView(entry: entry)
                .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
        }
        .configurationDisplayName("Embalse de San Juan")
        .description("El nivel del embalse de un vistazo.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct LockScreenView: View {
    var entry: ReservoirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: CircularLockWidgetView(snapshot: entry.snapshot)
        case .accessoryInline: InlineLockWidgetView(snapshot: entry.snapshot)
        default: RectangularLockWidgetView(snapshot: entry.snapshot)
        }
    }
}

struct ReservoirLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReservoirLockWidget", provider: ReservoirProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("San Juan")
        .description("El nivel del embalse en la pantalla de bloqueo.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct EmbalseWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReservoirWidget()
        ReservoirLockWidget()
    }
}
