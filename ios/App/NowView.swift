import Charts
import EmbalseKit
import SwiftUI

/// "Ahora" (docs/design/review-2.0/SYNTHESIS.md): the water card, then one-source modules. On compact widths the card
/// is about two thirds of the screen and the first modules show below it; scrolling past it pins a strip with the
/// figure. In a regular, tall window (iPad in portrait) it is a wide band with two columns of modules below. In a
/// regular, wide window (iPad in landscape, iPhone Duo open, a Mac) it becomes a pane the full height of the window,
/// with the modules scrolling beside it, and on iPhone Duo the fold falls between the two. Layout follows size
/// classes and the window's size, never the device.
struct NowView: View {
    var snapshot: Snapshot
    var origin: SnapshotRepository.Origin
    var history: HistoryModel
    var refresh: @Sendable () async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var mode: WaterCard.Mode = Self.initialMode
    @State private var cardVisible = true
    @State private var fold = FoldGeometry()
    @State private var motion = DeviceTilt()

    /// Always today. `-CardMode year` opens the year view, for the capture scripts.
    private static var initialMode: WaterCard.Mode {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "CardMode") == "year" { return .year }
        #endif
        return .today
    }

    private var reading: ReservoirReading { snapshot.reading(of: .sanJuan)! }
    private var surface: YearSurface? {
        history.history(.sanJuan).flatMap { YearSurface(history: $0, today: reading, capacityHm3: snapshot.weekly.capacityHm3) }
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if horizontalSizeClass == .regular && proxy.size.width >= 700 && proxy.size.width >= proxy.size.height * 0.9 {
                    pane(proxy)
                } else {
                    stack(proxy)
                }
            }
            .onGeometryChange(for: FoldGeometry.self) { FoldGeometry($0) } action: { fold = $0 }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("San Juan")
        .toolbarTitleDisplayMode(.inlineLarge)
        .onAppear { if !reduceMotion { motion.start() } }
        .onDisappear { motion.stop() }
        .task { await history.load(.sanJuan) }
    }

    private func card(figure: CGFloat) -> some View {
        WaterCard(reading: reading, capacityHm3: snapshot.weekly.capacityHm3, trendHm3: snapshot.live.trend24hHm3,
                  surface: surface, mode: $mode, figureSize: figure, tilt: motion.angle)
    }

    private var place: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Río Alberche · Madrid").font(.subheadline).foregroundStyle(.secondary)
            Notice(snapshot: snapshot, origin: origin)
        }
    }

    /// Compact: the card, then the modules, with the strip once the card has scrolled away.
    private func stack(_ proxy: GeometryProxy) -> some View {
        let large = typeSize.isAccessibilitySize
        let regular = horizontalSizeClass == .regular
        let height = regular
            ? max(proxy.size.height * 0.46, large ? 620 : 420)
            : max(proxy.size.height * (large ? 0.85 : 0.66), large ? 620 : 420)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                place.padding(.horizontal, 4)
                card(figure: regular ? 96 : 64)
                    .frame(height: height)
                    .onScrollVisibilityChange(threshold: 0.2) { visible in
                        withAnimation(.smooth(duration: 0.3)) { cardVisible = visible }
                    }
                Modules(snapshot: snapshot, columns: large ? 1 : 2)
            }
            .padding(.horizontal, regular ? 24 : 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await refresh() }
        .overlay(alignment: .top) {
            if !cardVisible {
                WaterStrip(reading: reading, trendHm3: snapshot.live.trend24hHm3)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    /// Regular: the card as a pane the window's height, the modules scrolling beside it.
    private func pane(_ proxy: GeometryProxy) -> some View {
        let margin: CGFloat = 20
        let gap = fold.keepClear.map { max(margin, $0.upperBound - $0.lowerBound) } ?? margin
        let paneWidth = fold.center.map { $0 - gap / 2 - margin } ?? min(max(proxy.size.width * 0.42, 320), 540)
        let rest = proxy.size.width - paneWidth - gap - margin * 2
        return HStack(alignment: .top, spacing: gap) {
            VStack(alignment: .leading, spacing: 10) {
                place.padding(.horizontal, 4)
                card(figure: 96)
            }
            .frame(width: paneWidth)
            .padding(.bottom, margin)
            ScrollView {
                Modules(snapshot: snapshot, columns: rest >= 560 && !typeSize.isAccessibilitySize ? 2 : 1)
                    .padding(.bottom, margin)
            }
            .refreshable { await refresh() }
            .frame(width: max(rest, 0))
        }
        .padding(.horizontal, margin)
        .padding(.top, 8)
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

