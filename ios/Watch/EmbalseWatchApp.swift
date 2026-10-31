import Charts
import EmbalseKit
import SwiftUI

@main
struct EmbalseWatchApp: App {
    @State private var model = ReservoirModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView(model: model)
        }
    }
}

struct WatchContentView: View {
    var model: ReservoirModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var page = 0

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
            case .failed:
                ContentUnavailableView {
                    Label("Sin datos", systemImage: "wifi.slash")
                } actions: {
                    Button("Reintentar") {
                        Task { await model.refresh(force: true) }
                    }
                }
            case .loaded(let snapshot, _):
                TabView(selection: $page) {
                    WatchHeroPage(snapshot: snapshot).tag(0)
                    WatchChartPage(snapshot: snapshot).tag(1)
                    WatchDetailsPage(snapshot: snapshot).tag(2)
                }
                .tabViewStyle(.verticalPage)
                #if DEBUG
                // `-ScreenshotPage 1` opens a page directly, for scripts/export-screenshots.sh.
                .task { page = UserDefaults.standard.integer(forKey: "ScreenshotPage") }
                #endif
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }
}

/// The water fills the whole screen, with the reading on top of it.
private struct WatchHeroPage: View {
    var snapshot: Snapshot

    var body: some View {
        let live = snapshot.live
        let trend = Trend(change: live.trend24hHm3)
        ZStack {
            WidgetWaterScene(percent: live.percent)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.reservoir.name)
                    .font(.headline)
                Spacer(minLength: 0)
                Text(Format.percent(live.percent))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 4) {
                    Image(systemName: trend.symbol)
                        .accessibilityLabel(trend.label)
                    Text(Format.hm3(live.volumeHm3))
                }
                .font(.footnote.weight(.semibold))
                Text(snapshot.isStale() ? "Dato antiguo: \(Format.dayMonthHour(live.observedAt))" : Format.hour(live.observedAt))
                    .font(.caption2)
                    .foregroundStyle(snapshot.isStale() ? .orange : .white.opacity(0.78))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .foregroundStyle(.white)
        }
    }
}

private struct WatchChartPage: View {
    var snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Últimos 90 días")
                .font(.footnote.weight(.semibold))
            VolumeChart(points: snapshot.daily)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 4)
        .containerBackground(Color(red: 0.03, green: 0.20, blue: 0.48).gradient, for: .tabView)
    }
}

private struct WatchDetailsPage: View {
    var snapshot: Snapshot

    var body: some View {
        List {
            Section("SAIH Tajo") {
                LabeledContent("Caudal", value: Format.optional(snapshot.live.outflowM3s, unit: "m³/s"))
                LabeledContent("Cota", value: Format.optional(snapshot.live.elevationM, unit: "m"))
                LabeledContent("Lluvia 24 h", value: Format.optional(snapshot.weather.rain24hMm, unit: "mm"))
            }
            Section("Boletín semanal") {
                LabeledContent("Agua", value: Format.hm3(snapshot.weekly.volumeHm3, decimals: 0))
                LabeledContent("Hace un año", value: snapshot.weekly.lastYearHm3.map { Format.hm3($0, decimals: 0) } ?? "Sin dato")
                LabeledContent("Media 10 años", value: snapshot.weekly.tenYearAvgHm3.map { Format.hm3($0) } ?? "Sin dato")
            }
        }
    }
}
