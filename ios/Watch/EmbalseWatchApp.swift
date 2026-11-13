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
                    WatchYearPage(snapshot: snapshot).tag(1)
                    WatchRiverPage(snapshot: snapshot).tag(2)
                    WatchDetailsPage(snapshot: snapshot).tag(3)
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
/// The block goes wholly in the water or wholly above it, never across the waterline, as on the iPhone. The sky is
/// dark here, so the text stays white either way.
private struct WatchHeroPage: View {
    var snapshot: Snapshot
    @ScaledMetric(relativeTo: .largeTitle) private var figure = 34.0
    @State private var blockHeight: CGFloat = 100
    @State private var size: CGSize = .zero
    @State private var insets = EdgeInsets()

    /// Where the block goes, from the real waterline: the water is drawn under the safe areas too.
    private struct Layout {
        var bottomPadding: CGFloat
        var showsTrend: Bool
    }

    var body: some View {
        let live = snapshot.live
        let layout = layout(percent: live.percent)
        ZStack(alignment: .bottomLeading) {
            WaterBackground(percent: live.percent, amplitude: 4).ignoresSafeArea()
            Text("San Juan")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            block(live, showsTrend: layout.showsTrend)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { blockHeight = $0 }
                .padding(.bottom, layout.bottomPadding)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets = $0 }
        .navigationTitle("San Juan")
    }

    private func layout(percent: Double) -> Layout {
        let full = size.height + insets.top + insets.bottom
        // Water above the safe area's bottom edge, which is where the block's bottom sits.
        let depth = full * min(max(percent / 100, 0), 1) - insets.bottom
        let crest: CGFloat = 4 * 1.45 + waterlineClearance
        let sky = size.height - depth - crest
        // The trend line is about 20 pt; it is also on the details page.
        for showsTrend in [true, false] {
            let block = blockHeight - (showsTrend ? 0 : 20)
            if depth >= block + crest + 4 { return Layout(bottomPadding: 4, showsTrend: showsTrend) }
            if sky >= block { return Layout(bottomPadding: depth + crest, showsTrend: showsTrend) }
        }
        return Layout(bottomPadding: 4, showsTrend: false)
    }

    private func block(_ live: Snapshot.Live, showsTrend: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Format.percent(live.percent))
                .font(.system(size: figure, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(Format.hm3(live.volumeHm3)).font(.headline)
            if showsTrend {
                Label(Trend(change: live.trend24hHm3).label, systemImage: Trend(change: live.trend24hHm3).symbol)
                    .font(.footnote.weight(.semibold))
            }
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
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// "Último año": the last 12 months of SAIH as the water's surface, with last year's line and the range of the years
/// before, standing on a strip of water that holds the figure, as in the widget.
private struct WatchYearPage: View {
    var snapshot: Snapshot
    @State private var history: History?

    var body: some View {
        let reading = snapshot.reading(of: .sanJuan)
        let surface = history.flatMap { YearSurface(history: $0, today: reading, capacityHm3: snapshot.weekly.capacityHm3) }
        ZStack(alignment: .topLeading) {
            Palette.sky(.dark).ignoresSafeArea()
            if let surface {
                WatchYearSurface(surface: surface, percent: snapshot.live.percent).ignoresSafeArea(edges: .bottom)
                VStack(alignment: .leading, spacing: 1) {
                    Text(Format.percent(snapshot.live.percent))
                        .font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                    if let change = surface.changeFromLastYearHm3 {
                        Text(change < 0 ? "\(Format.hm3(-change)) menos que hace un año" : "\(Format.hm3(change)) más que hace un año")
                            .font(.caption2.weight(.medium)).opacity(0.9).lineLimit(2).minimumScaleFactor(0.8)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Último año").font(.headline)
                Text(verbatim: "SAIH Tajo").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .task { history = try? await HistoryRepository().load(.sanJuan) }
    }
}

private struct WatchYearSurface: View {
    var surface: YearSurface
    var percent: Double

    var body: some View {
        Canvas { context, size in
            let top: CGFloat = 52
            // The figure and its line sit in this strip, always under the surface.
            let floor: CGFloat = 92
            let usable = size.height - top - floor
            let y = { (fraction: Double) in top + usable * (1 - min(max(fraction, 0), 1.02)) }
            let x = { (index: Int, count: Int) in size.width * CGFloat(index) / CGFloat(max(count - 1, 1)) }
            if let band = surface.band, band.count > 1 {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y(band[0].upperBound)))
                for (index, range) in band.enumerated() { path.addLine(to: CGPoint(x: x(index, band.count), y: y(range.upperBound))) }
                for (index, range) in band.enumerated().reversed() { path.addLine(to: CGPoint(x: x(index, band.count), y: y(range.lowerBound))) }
                path.closeSubpath()
                context.fill(path, with: .color(Palette.band(.dark)))
            }
            var line = Path()
            for (index, level) in surface.levels.enumerated() {
                let point = CGPoint(x: x(index, surface.levels.count), y: y(level))
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            var area = line
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(Gradient(colors: [Color(red: 0.05, green: 0.42, blue: 0.70), Color(red: 0.01, green: 0.15, blue: 0.38)]),
                                                     startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(line, with: .color(Palette.crestLine), lineWidth: 2)
            if let lastYear = surface.lastYear, lastYear.count > 1 {
                var path = Path()
                for (index, value) in lastYear.enumerated() {
                    let point = CGPoint(x: x(index, lastYear.count), y: y(value))
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
                context.stroke(path, with: .color(Palette.lastYear), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
            }
            let today = CGPoint(x: size.width - 6, y: y(surface.levels.last ?? 0))
            context.fill(Path(ellipseIn: CGRect(x: today.x - 4, y: today.y - 4, width: 8, height: 8)), with: .color(.white))
        }
        .accessibilityHidden(true)
    }
}

/// "El río": Burguillo, San Juan and Picadas in river order, each as a tank at its own level.
private struct WatchRiverPage: View {
    var snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("El río").font(.headline)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(snapshot.chain) { reading in
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.sky(.dark))
                            WaveShape(level: reading.percent / 100, phase: 0.6, amplitude: 2)
                                .fill(Palette.water(reading.percent))
                            Text(Format.number(reading.percent, decimals: 0) + Format.space + "%")
                                .font(.system(.footnote, design: .rounded).weight(.bold)).monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.bottom, 6)
                        }
                        .clipShape(.rect(cornerRadius: 12, style: .continuous))
                        .overlay {
                            if reading.reservoir == .sanJuan {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
                            }
                        }
                        Text(reading.reservoir.name).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
            Text(verbatim: Format.saihSource(snapshot.live.observedAt)).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }
}

/// The main figures, each with its symbol and source: SAIH now, MITECO for the week.
private struct WatchDetailsPage: View {
    var snapshot: Snapshot

    var body: some View {
        List {
            Section {
                row("Salida al río", "arrow.down.right.circle.fill", .cyan, Format.optional(snapshot.live.outflowM3s, decimals: 2, unit: "m³/s"))
                row("Cota", "ruler.fill", .blue, Format.optional(snapshot.live.elevationM, decimals: 2, unit: "m"))
                row("Lluvia 24 h", "cloud.rain.fill", .teal, Format.optional(snapshot.weather.rain24hMm, unit: "mm"))
            } header: {
                Text(verbatim: Format.saihSource(snapshot.live.observedAt))
            }
            Section {
                row("Esta semana", "calendar", .indigo, Format.hm3(snapshot.weekly.volumeHm3, .mitecoVolume))
                row("Hace un año", "clock.arrow.circlepath", .orange, snapshot.weekly.lastYearHm3.map { Format.hm3($0, .mitecoVolume) } ?? Format.optional(nil, unit: ""))
                row("Media 10 años", "chart.line.flattrend.xyaxis", .gray, snapshot.weekly.tenYearAvgHm3.map { Format.hm3($0, .mitecoVolume) } ?? Format.optional(nil, unit: ""))
            } header: {
                Text(verbatim: Format.mitecoWeek(snapshot.weekly.day))
            }
        }
    }

    private func row(_ title: LocalizedStringKey, _ symbol: String, _ tint: Color, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint).font(.body)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
            }
        }
    }
}
