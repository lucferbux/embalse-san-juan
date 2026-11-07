import EmbalseKit
import SwiftUI

/// The image the share button sends: the "Ahora" block on the water, with its source and date, so a shared figure
/// never travels without them.
struct ShareCard: View {
    var snapshot: Snapshot

    var body: some View {
        let reading = snapshot.reading(of: .sanJuan)!
        ZStack(alignment: .topLeading) {
            WaterBackground(percent: max(snapshot.live.percent, 55), amplitude: 10)
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: "Embalse de San Juan").font(.title2.bold()).foregroundStyle(.primary)
                Text("Río Alberche · Madrid").font(.headline).foregroundStyle(.secondary)
                Spacer()
                FigureBlock(reading: reading, capacityHm3: snapshot.weekly.capacityHm3, trendHm3: snapshot.live.trend24hHm3,
                            onWater: true, figureSize: 120)
                Text(verbatim: "embalse-san-juan.web.app").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
            }
            .padding(48)
        }
        .frame(width: 1080 / 2, height: 1350 / 2)
        .environment(\.colorScheme, .light)
    }

    /// Rendered at 2x: 1080 × 1350, the portrait size most apps show uncropped.
    @MainActor
    static func image(for snapshot: Snapshot) -> Image {
        let renderer = ImageRenderer(content: ShareCard(snapshot: snapshot))
        renderer.scale = 2
        guard let image = renderer.uiImage else { return Image(systemName: "drop.fill") }
        return Image(uiImage: image)
    }
}
