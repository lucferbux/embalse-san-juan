import EmbalseKit
import SwiftUI

/// "El río": Burguillo, San Juan and Picadas in river order, each at its own level with its own SAIH time, then the
/// basin's rain gauges. Each reservoir opens its own page.
struct RiverView: View {
    var snapshot: Snapshot
    var history: HistoryModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    PanelTitle("De aguas arriba a aguas abajo")
                    let layout = size.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
                    layout {
                        ForEach(snapshot.chain) { reading in
                            NavigationLink(value: Route.reservoir(reading.reservoir)) {
                                ReservoirTank(reading: reading, isCurrent: reading.reservoir == .sanJuan,
                                              tankHeight: horizontalSizeClass == .regular ? 200 : 130)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .panel()

                if !snapshot.rainGauges.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        PanelTitle("Lluvia en la cuenca, 24 h", source: snapshot.rainGauges.map(\.observedAt).max().map { Format.saihSource($0) })
                        ForEach(snapshot.rainGauges) { gauge in
                            ValueRow(LocalizedStringKey(gauge.name), symbol: "cloud.rain", value: Format.optional(gauge.rain24hMm, unit: "mm"))
                        }
                        Text("Pluviómetros del SAIH Tajo en la cuenca del Alberche. Es lluvia medida; la previsión está en Este año.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .panel()
                }
            }
            .padding(horizontalSizeClass == .regular ? 24 : 16)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("El río")
    }
}

/// One reservoir's own page: its water and figure, the last 90 days as the water's surface, and its history.
struct ReservoirPage: View {
    var id: ReservoirID
    var snapshot: Snapshot
    @Environment(HistoryModel.self) private var history

    var body: some View {
        let reading = snapshot.reading(of: id)
        let loaded = history.history(id)
        let capacity = loaded?.weekly.last?.capacityHm3 ?? (id == .sanJuan ? snapshot.weekly.capacityHm3 : reading?.capacityHm3 ?? 0)
        ScrollView {
            VStack(spacing: 16) {
                if let reading {
                    WaterScene(percent: reading.percent, animated: false) {
                        EmptyView()
                    } figure: { onWater in
                        FigureBlock(reading: reading, capacityHm3: capacity,
                                    trendHm3: id == .sanJuan ? snapshot.live.trend24hHm3 : nil,
                                    onWater: onWater, figureSize: 64)
                            .padding(.horizontal, 20)
                    }
                    .frame(height: 360)
                    .clipShape(.rect(cornerRadius: 28, style: .continuous))
                } else {
                    ContentUnavailableView("Sin dato reciente", systemImage: "drop.triangle", description: Text("El SAIH no ha dado una lectura de \(id.name) en la última hora."))
                }

                if let loaded, loaded.daily.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        PanelTitle("Últimos 90 días", source: "SAIH Tajo")
                        SurfaceHistory(volumes: Array(loaded.daily.suffix(90).map(\.volumeHm3)) + (reading.map { [$0.volumeHm3] } ?? []),
                                       capacityHm3: capacity)
                            .frame(height: 200)
                            .clipShape(.rect(cornerRadius: 16, style: .continuous))
                    }
                    .panel()
                }

                HistoryPanel(reservoir: id, capacity: capacity, today: reading, history: history)
            }
            .padding(16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(id.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await history.load(id) }
    }
}
