import EmbalseKit
import SwiftUI
import WidgetKit

struct HomeScreenView: View {
    var entry: ReservoirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: MediumWidgetView(snapshot: entry.snapshot, now: entry.date)
        case .systemLarge: LargeWidgetView(snapshot: entry.snapshot, now: entry.date)
        case .systemExtraLarge: ExtraLargeWidgetView(snapshot: entry.snapshot, now: entry.date)
        default: SmallWidgetView(snapshot: entry.snapshot, now: entry.date)
        }
    }
}

struct ReservoirWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReservoirWidget", provider: ReservoirProvider()) { entry in
            HomeScreenView(entry: entry)
                .containerBackground(for: .widget) { Color(red: 0.06, green: 0.18, blue: 0.38) }
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
