import Charts
import EmbalseKit
import SwiftUI

/// "Ahora": the screen is the reservoir. The water stays put at the real level while the details scroll over it.
/// Compact widths show one column; regular widths (iPad, iPhone Duo open) show the figure as a full-width band with
/// columns below, the fold always in a gap between them. Layout follows size classes only.
struct NowView: View {
    var snapshot: Snapshot
    var origin: SnapshotRepository.Origin
    var history: HistoryModel
    var refresh: @Sendable () async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fold = FoldGeometry()
    @State private var blockHeight: CGFloat = 220
    @State private var motion = DeviceTilt()

    private var regular: Bool { horizontalSizeClass == .regular }
    private var amplitude: CGFloat { regular ? 8 : 6 }

    var body: some View {
        GeometryReader { proxy in
            let viewport = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let placement = FigurePlacement.decide(height: viewport, percent: snapshot.live.percent, amplitude: amplitude,
                                                   block: blockHeight, bottomInset: proxy.safeAreaInsets.bottom + 24)
            ZStack(alignment: .top) {
                background
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(placement, topInset: proxy.safeAreaInsets.top)
                            .frame(height: max(viewport - proxy.safeAreaInsets.top, 0), alignment: .top)
                        details
                            .padding(.bottom, 24)
                    }
                    .frame(maxWidth: regular ? 1200 : .infinity)
                    .frame(maxWidth: .infinity)
                }
                .scrollContentBackground(.hidden)
                .refreshable { await refresh() }
                .onGeometryChange(for: FoldGeometry.self) { FoldGeometry($0) } action: { fold = $0 }
            }
        }
        .navigationTitle("San Juan")
        .toolbarTitleDisplayMode(.inlineLarge)
        .onAppear { if !reduceMotion { motion.start() } }
        .onDisappear { motion.stop() }
        .task { await history.load(.sanJuan) }
    }

    private var background: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            WaterBackground(percent: snapshot.live.percent,
                            phase: reduceMotion ? 0.6 : WaterScene<EmptyView, EmptyView>.phase(at: context.date),
                            amplitude: amplitude, tilt: reduceMotion ? 0 : motion.angle)
        }
        .ignoresSafeArea()
    }

    /// The first viewport: the place and the stale or offline notice above the water, the figure where the
    /// placement rule puts it. Placement is in screen coordinates; the scroll content starts below `topInset`.
    @ViewBuilder
    private func header(_ placement: FigurePlacement, topInset: CGFloat) -> some View {
        let reading = snapshot.reading(of: .sanJuan)!
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Río Alberche · Madrid").font(.subheadline).foregroundStyle(.secondary)
                Notice(snapshot: snapshot, origin: origin)
            }
            switch placement {
            case .water(let top):
                block(reading, onWater: true).padding(.top, top - topInset)
            case .sky(let bottom):
                block(reading, onWater: false)
                    .frame(maxHeight: max(bottom - topInset, 0), alignment: .bottomLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, regular ? 40 : 22)
    }

    private func block(_ reading: ReservoirReading, onWater: Bool) -> some View {
        FigureBlock(reading: reading, capacityHm3: snapshot.weekly.capacityHm3, trendHm3: snapshot.live.trend24hHm3,
                    onWater: onWater, figureSize: regular ? 128 : 88)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { blockHeight = $0 }
    }

    @ViewBuilder private var details: some View {
        if regular {
            DashboardColumns(fold: fold, columns: fold.center == nil && fold.width >= 1000 ? 3 : 2) {
                RealtimePanel(snapshot: snapshot)
                OutflowPanel(snapshot: snapshot)
                WeatherPanel(weather: snapshot.weather)
            } middle: {
                YearSummaryPanel(snapshot: snapshot, history: history)
            } trailing: {
                RiverSummaryPanel(snapshot: snapshot)
            }
        } else {
            VStack(spacing: 16) {
                RealtimePanel(snapshot: snapshot)
                OutflowPanel(snapshot: snapshot)
                MitecoPanel(weekly: snapshot.weekly)
                WeatherPanel(weather: snapshot.weather)
            }
            .padding(.horizontal, 16)
        }
    }
}

/// The stale and offline notices. A stale reading always shows its full date.
struct Notice: View {
    var snapshot: Snapshot
    var origin: SnapshotRepository.Origin

    var body: some View {
        if snapshot.isStale() {
            Label("Este dato es del \(Format.dayMonthHour(snapshot.live.observedAt)). La recogida puede estar fallando.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold)).foregroundStyle(.orange)
        } else if origin == .cache {
            Label("Sin conexión. Mostrando el último dato guardado.", systemImage: "wifi.slash")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Panels below the fold

struct PanelTitle: View {
    var title: LocalizedStringKey
    var source: String?

    init(_ title: LocalizedStringKey, source: String? = nil) {
        self.title = title
        self.source = source
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let source { Text(source).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

/// A row that keeps label and value side by side, and stacks them at accessibility sizes instead of breaking words.
struct ValueRow: View {
    var title: LocalizedStringKey
    var symbol: String?
    var value: String
    @Environment(\.dynamicTypeSize) private var size

    init(_ title: LocalizedStringKey, symbol: String? = nil, value: String) {
        self.title = title
        self.symbol = symbol
        self.value = value
    }

    var body: some View {
        let label = Group {
            if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
        }
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                label.foregroundStyle(.secondary)
                Text(value).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            LabeledContent { Text(value).monospacedDigit() } label: { label }
        }
    }
}

struct RealtimePanel: View {
    var snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle("Últimas 24 horas", source: Format.saihSource(snapshot.live.observedAt))
            RecentChart(readings: snapshot.recent).frame(height: 150)
            ValueRow("Cota", value: Format.optional(snapshot.live.elevationM, decimals: 2, unit: "m"))
            ValueRow("Nivel", value: Format.optional(snapshot.live.levelM, decimals: 2, unit: "m"))
        }
        .panel()
    }
}

struct RecentChart: View {
    var readings: [Snapshot.RecentReading]

    var body: some View {
        let values = readings.map(\.volumeHm3)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let margin = max((high - low) * 0.3, 0.05)
        Chart(readings) { reading in
            LineMark(x: .value("Hora", reading.at), y: .value("Volumen", reading.volumeHm3))
                .foregroundStyle(YearComparisonChart.thisYearColor)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .chartYScale(domain: (low - margin)...(high + margin))
        .chartYAxisLabel("hm³")
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine()
                AxisValueLabel { if let date = value.as(Date.self) { Text(Format.hour(date)) } }
            }
        }
        .accessibilityLabel(Text("Volumen en las últimas 24 horas, de \(Format.hm3(values.first ?? 0)) a \(Format.hm3(values.last ?? 0))"))
    }
}

struct OutflowPanel: View {
    var snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle("Caudal desembalsado", source: Format.saihSource(snapshot.live.observedAt))
            ValueRow("Salida al río", value: Format.optional(snapshot.live.outflowM3s, decimals: 2, unit: "m³/s"))
            ValueRow("Trasvase a Valmayor", value: Format.optional(snapshot.live.transferM3s, decimals: 2, unit: "m³/s"))
            let readings = snapshot.recent.filter { $0.outflowM3s != nil }
            if !readings.isEmpty {
                Chart(readings) { reading in
                    AreaMark(x: .value("Hora", reading.at), y: .value("Caudal", reading.outflowM3s ?? 0))
                        .foregroundStyle(YearComparisonChart.thisYearColor.opacity(0.2))
                        .interpolationMethod(.stepEnd)
                    LineMark(x: .value("Hora", reading.at), y: .value("Caudal", reading.outflowM3s ?? 0))
                        .foregroundStyle(YearComparisonChart.thisYearColor)
                        .interpolationMethod(.stepEnd)
                }
                .chartYAxisLabel("m³/s")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                        AxisGridLine()
                        AxisValueLabel { if let date = value.as(Date.self) { Text(Format.hour(date)) } }
                    }
                }
                .frame(height: 100)
                .accessibilityLabel(Text("Caudal de salida en las últimas 24 horas"))
            }
        }
        .panel()
    }
}

struct WeatherPanel: View {
    var weather: Snapshot.Weather

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitle("Tiempo en la presa", source: Format.saihSource(weather.observedAt))
            ValueRow("Temperatura", symbol: "thermometer.medium", value: Format.optional(weather.temperatureC, unit: "°C"))
            ValueRow("Viento", symbol: "wind", value: wind)
            ValueRow("Humedad", symbol: "humidity", value: Format.optional(weather.humidityPct, decimals: 0, unit: "%"))
            ValueRow("Presión", symbol: "gauge.with.dots.needle.33percent", value: Format.optional(weather.pressureHpa, decimals: 0, unit: "hPa"))
            ValueRow("Radiación solar", symbol: "sun.max", value: Format.optional(weather.solarWm2, decimals: 0, unit: "W/m²"))
            ValueRow("Lluvia en 1 h", symbol: "cloud.rain", value: Format.optional(weather.rain1hMm, unit: "mm"))
            ValueRow("Lluvia en 24 h", symbol: "cloud.heavyrain", value: Format.optional(weather.rain24hMm, unit: "mm"))
        }
        .panel()
    }

    private var wind: String {
        let speed = Format.optional(weather.windMs, unit: "m/s")
        guard weather.windMs != nil, let direction = weather.windDirectionDeg else { return speed }
        return "\(speed) \(Format.compass(direction))"
    }
}

/// On regular widths, "Este año" in short: the MITECO panel and a small comparison chart.
struct YearSummaryPanel: View {
    var snapshot: Snapshot
    var history: HistoryModel

    var body: some View {
        VStack(spacing: 16) {
            MitecoPanel(weekly: snapshot.weekly)
            if let comparison = history.history(.sanJuan).flatMap(YearComparison.init) {
                VStack(alignment: .leading, spacing: 10) {
                    PanelTitle("Este año", source: Format.mitecoWeek(snapshot.weekly.day))
                    YearComparisonChart(comparison: comparison, compact: true).frame(height: 170)
                    YearComparisonChart.Legend()
                }
                .panel()
            }
        }
    }
}

/// On regular widths, "El río" in short: the three tanks side by side.
struct RiverSummaryPanel: View {
    var snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle("El río", source: String(localized: "De aguas arriba a aguas abajo"))
            HStack(alignment: .top, spacing: 12) {
                ForEach(snapshot.chain) { reading in
                    NavigationLink(value: Route.reservoir(reading.reservoir)) {
                        ReservoirTank(reading: reading, isCurrent: reading.reservoir == .sanJuan, tankHeight: 90)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .panel()
    }
}
