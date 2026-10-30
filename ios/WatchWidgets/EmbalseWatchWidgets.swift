import EmbalseKit
import SwiftUI
import WidgetKit

struct ComplicationView: View {
    var entry: ReservoirEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: CircularLockWidgetView(snapshot: entry.snapshot)
        case .accessoryCorner: CornerWatchWidgetView(snapshot: entry.snapshot)
        case .accessoryInline: InlineLockWidgetView(snapshot: entry.snapshot)
        default: RectangularLockWidgetView(snapshot: entry.snapshot)
        }
    }
}

struct ReservoirComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReservoirComplication", provider: ReservoirProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("San Juan")
        .description("El nivel del embalse en la esfera.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct EmbalseWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReservoirComplication()
    }
}
