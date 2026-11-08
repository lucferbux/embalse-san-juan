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

/// The water fills the whole screen at the real level, with the figure, its volume, the trend word and the source.
private struct WatchHeroPage: View {
    var snapshot: Snapshot
    @ScaledMetric(relativeTo: .largeTitle) private var figure = 40.0

    var body: some View {
        let live = snapshot.live
        ZStack(alignment: .bottomLeading) {
            WaterBackground(percent: live.percent, amplitude: 4).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.percent(live.percent))
                    .font(.system(size: figure, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(Format.hm3(live.volumeHm3)).font(.headline)
                Label(Trend(change: live.trend24hHm3).label, systemImage: Trend(change: live.trend24hHm3).symbol)
                    .font(.footnote.weight(.semibold))
                Group {
                    if snapshot.isStale() {
                        Label(Format.dayMonthHour(live.observedAt), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    } else {
                        Text(verbatim: "SAIH · \(Format.hour(live.observedAt))").foregroundStyle(.white.opacity(0.8))
                    }
                }
                .font(.caption2.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("San Juan")
    }
}

/// Direction C on the watch: the last 90 days drawn as the water's surface, 0 to capacity, labelled at both ends.
private struct WatchChartPage: View {
    var snapshot: Snapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            SurfaceHistory(volumes: snapshot.daily.map(\.volumeHm3), capacityHm3: snapshot.weekly.capacityHm3)
                .ignoresSafeArea(edges: .bottom)
            Text("Últimos 90 días").font(.footnote.weight(.semibold)).padding(.horizontal, 8)
        }
    }
}

/// The main figures, each with its source: SAIH now, MITECO for the week.
private struct WatchDetailsPage: View {
    var snapshot: Snapshot

    var body: some View {
        List {
            Section {
                LabeledContent("Salida al río", value: Format.optional(snapshot.live.outflowM3s, decimals: 2, unit: "m³/s"))
                LabeledContent("Cota", value: Format.optional(snapshot.live.elevationM, decimals: 2, unit: "m"))
                LabeledContent("Lluvia 24 h", value: Format.optional(snapshot.weather.rain24hMm, unit: "mm"))
            } header: {
                Text(verbatim: Format.saihSource(snapshot.live.observedAt))
            }
            Section {
                LabeledContent("Esta semana", value: Format.hm3(snapshot.weekly.volumeHm3, .mitecoVolume))
                LabeledContent("Hace un año", value: snapshot.weekly.lastYearHm3.map { Format.hm3($0, .mitecoVolume) } ?? Format.optional(nil, unit: ""))
                LabeledContent("Media 10 años", value: snapshot.weekly.tenYearAvgHm3.map { Format.hm3($0, .mitecoVolume) } ?? Format.optional(nil, unit: ""))
            } header: {
                Text(verbatim: Format.mitecoWeek(snapshot.weekly.day))
            }
        }
    }
}
