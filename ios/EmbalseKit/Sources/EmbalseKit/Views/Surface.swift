import Charts
import SwiftUI

// The 2.0 design (docs/design/DESIGN-2.0.md): the screen is the reservoir. These pieces are shared by the app, the
// widgets, the watch and the share card, so a figure looks the same wherever it appears.

public extension Palette {
    /// The water follows how full the reservoir is: deep blue when full, a lighter teal when low. Its top is dark enough
    /// for white text to pass 4.5:1 at every level from 8 to 97 %.
    static func water(_ percent: Double) -> LinearGradient {
        let empty = 1 - min(max(percent / 100, 0), 1)
        let top = Color(red: 0.05 + empty * 0.03, green: 0.40 + empty * 0.10, blue: 0.74 - empty * 0.12)
        let bottom = Color(red: 0.01, green: 0.17 + empty * 0.08, blue: 0.47 - empty * 0.08)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// The back wave, lighter, behind the front one.
    static let waterCrest = Color(red: 0.36, green: 0.70, blue: 0.99).opacity(0.45)

    /// Text and panels in the water.
    static let onWater = Color.white
}

/// Clearance between any text and the highest crest of the waterline, whatever the wave's phase.
public let waterlineClearance: CGFloat = 12

/// Where the "Ahora" block goes, decided once for every format (DESIGN-2.0, rule 1): wholly in the water, in white,
/// or wholly in the sky when the water is too shallow for it. Never across the waterline.
public enum FigurePlacement: Equatable, Sendable {
    case water(top: CGFloat)
    case sky(bottom: CGFloat)

    public var isOnWater: Bool { if case .water = self { true } else { false } }

    /// - Parameters:
    ///   - height: the scene's height.
    ///   - percent: the level, 0–100.
    ///   - amplitude: the wave's crest above or below the mean waterline.
    ///   - block: the measured height of the block to place.
    ///   - bottomInset: space kept free at the bottom (tab bar, panels).
    public static func decide(height: CGFloat, percent: Double, amplitude: CGFloat, block: CGFloat, bottomInset: CGFloat = 0) -> FigurePlacement {
        let waterline = height * (1 - min(max(percent / 100, 0), 1))
        let top = waterline + amplitude + waterlineClearance
        if top + block <= height - bottomInset {
            return .water(top: top)
        }
        return .sky(bottom: max(waterline - amplitude - waterlineClearance, 0))
    }
}

/// Text style for figures: SF Rounded with tabular digits, the same in the app, widgets and watch.
public extension View {
    func figureFont(_ style: Font.TextStyle, size: CGFloat? = nil, weight: Font.Weight = .semibold) -> some View {
        let font: Font = size.map { .system(size: $0, weight: weight, design: .rounded) } ?? .system(style, design: .rounded, weight: weight)
        return self.font(font).monospacedDigit()
    }
}

/// "48,7 %", "67,0 hm³ de 138 hm³", "Estable · +0,12 hm³ en 24 h" and "SAIH Tajo · 30 oct, 16:00": the answer to the
/// one question, with its source, in one block that is read aloud as one sentence.
public struct FigureBlock: View {
    var reading: ReservoirReading
    var capacityHm3: Double
    var trendHm3: Double?
    var onWater: Bool
    var figureSize: CGFloat
    var compact: Bool

    /// `compact` keeps the figure and the volume only, for the year view, where the surface is the subject.
    public init(reading: ReservoirReading, capacityHm3: Double, trendHm3: Double?, onWater: Bool, figureSize: CGFloat = 88, compact: Bool = false) {
        self.reading = reading
        self.capacityHm3 = capacityHm3
        self.trendHm3 = trendHm3
        self.onWater = onWater
        self.figureSize = figureSize
        self.compact = compact
    }

    @ScaledMetric(relativeTo: .largeTitle) private var scale = 1.0

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Format.percent(reading.percent))
                .figureFont(.largeTitle, size: figureSize * scale)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(Format.volumeOfCapacity(reading.volumeHm3, capacityHm3))
                .font(.title3.weight(.semibold))
            if !compact, let trendHm3 {
                Label(Trend.sentence(trendHm3), systemImage: Trend(change: trendHm3).symbol)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.92)
            }
            if !compact {
                Label(Format.saihSource(reading.observedAt), systemImage: "clock")
                    .font(.footnote.weight(.medium))
                    .opacity(0.8)
            }
        }
        .foregroundStyle(onWater ? AnyShapeStyle(Palette.onWater) : AnyShapeStyle(.primary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySentence)
    }

    private var accessibilitySentence: String {
        var parts = [reading.reservoir.name, Format.percent(reading.percent), Format.volumeOfCapacity(reading.volumeHm3, capacityHm3)]
        if let trendHm3 { parts.append(Trend.sentence(trendHm3)) }
        parts.append(Format.saihSource(reading.observedAt))
        return parts.joined(separator: ", ")
    }
}

/// The sky, and water at `percent` that fills the space. `phase` animates the wave; `tilt` leans the surface by a
/// fraction of the height across the width, for the device's motion.
public struct WaterBackground: View {
    var percent: Double
    var phase: Double
    var amplitude: CGFloat
    var tilt: Double
    @Environment(\.colorScheme) private var scheme

    public init(percent: Double, phase: Double = 0.6, amplitude: CGFloat = 6, tilt: Double = 0) {
        self.percent = percent
        self.phase = phase
        self.amplitude = amplitude
        self.tilt = tilt
    }

    public var body: some View {
        ZStack {
            Rectangle().fill(Palette.sky(scheme))
            WaveShape(level: percent / 100, phase: phase + 2.1, amplitude: amplitude * 0.8)
                .fill(Palette.waterCrest)
                .offset(x: -20)
            WaveShape(level: percent / 100, phase: phase, amplitude: amplitude)
                .fill(Palette.water(percent))
        }
        .rotationEffect(.radians(tilt), anchor: .center)
        .scaleEffect(tilt == 0 ? 1 : 1.15)
        .accessibilityHidden(true)
    }
}

/// A full-bleed scene with the "Ahora" block placed by `FigurePlacement`: in the water when it fits, in the sky
/// otherwise. `content` receives whether it is on the water, to pick its colours.
public struct WaterScene<Header: View, Figure: View>: View {
    var percent: Double
    var amplitude: CGFloat
    var bottomInset: CGFloat
    var animated: Bool
    var header: Header
    var figure: (_ onWater: Bool) -> Figure

    @State private var blockHeight: CGFloat = 200
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(percent: Double, amplitude: CGFloat = 6, bottomInset: CGFloat = 0, animated: Bool = true,
                @ViewBuilder header: () -> Header, @ViewBuilder figure: @escaping (_ onWater: Bool) -> Figure) {
        self.percent = percent
        self.amplitude = amplitude
        self.bottomInset = bottomInset
        self.animated = animated
        self.header = header()
        self.figure = figure
    }

    public var body: some View {
        GeometryReader { proxy in
            let placement = FigurePlacement.decide(height: proxy.size.height, percent: percent, amplitude: amplitude,
                                                   block: blockHeight, bottomInset: bottomInset)
            ZStack(alignment: .topLeading) {
                if animated && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        WaterBackground(percent: percent, phase: Self.phase(at: context.date), amplitude: amplitude)
                    }
                } else {
                    WaterBackground(percent: percent, amplitude: amplitude)
                }
                header
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Group {
                    switch placement {
                    case .water(let top):
                        figure(true).padding(.top, top)
                    case .sky(let bottom):
                        figure(false)
                            .frame(maxHeight: bottom, alignment: .bottomLeading)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    // Only the block's own height matters; padding is the placement itself.
                    if case .water(let top) = placement { blockHeight = height - top } else { blockHeight = height }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    public static func phase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 2 * .pi
    }
}

/// A content panel over the water or the page. Real Liquid Glass is kept for chrome (tab bar, toolbars); content uses
/// a fixed translucent fill, so white text keeps 4.5:1 against the water underneath.
public struct PanelStyle: ViewModifier {
    var onWater: Bool
    var corner: CGFloat
    @Environment(\.colorScheme) private var scheme

    public func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(onWater ? Color.black.opacity(0.22) : Color(uiColorFallback: scheme))
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(onWater ? 0.22 : 0), lineWidth: 1)
            }
            .foregroundStyle(onWater ? AnyShapeStyle(Palette.onWater) : AnyShapeStyle(.primary))
    }
}

public extension View {
    func panel(onWater: Bool = false, corner: CGFloat = 22) -> some View {
        modifier(PanelStyle(onWater: onWater, corner: corner))
    }
}

private extension Color {
    /// The grouped secondary background, available on iOS and watchOS alike.
    init(uiColorFallback scheme: ColorScheme) {
        self = scheme == .dark ? Color(white: 0.11) : Color.white
    }
}

/// The MITECO panel (DESIGN-2.0, rule 5): this week's bulletin with last year and the 10-year average, headed by its
/// own source and week, styled apart from every SAIH figure.
public struct MitecoPanel: View {
    var weekly: Snapshot.Weekly
    var onWater: Bool

    public init(weekly: Snapshot.Weekly, onWater: Bool = false) {
        self.weekly = weekly
        self.onWater = onWater
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Format.mitecoWeek(weekly.day)).font(.footnote.weight(.semibold))
                Spacer(minLength: 8)
                Text("semanal", bundle: .module)
                    .font(.caption2.weight(.bold)).textCase(.uppercase)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().strokeBorder(lineWidth: 1).opacity(0.5))
            }
            .opacity(0.9)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) { figures }
                VStack(alignment: .leading, spacing: 10) { figures }
            }
        }
        .panel(onWater: onWater)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var figures: some View {
        figure("Esta semana", weekly.volumeHm3)
        if let lastYear = weekly.lastYearHm3 { figure("Hace un año", lastYear) }
        if let average = weekly.tenYearAvgHm3 { figure("Media 10 años", average) }
    }

    private func figure(_ title: LocalizedStringKey, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title, bundle: .module).font(.caption).opacity(0.8)
            Text(Format.hm3(value, .mitecoVolume)).figureFont(.title2)
        }
    }
}

/// This year, last year and the 10-year average, MITECO weekly, in three distinct solid colours, with today marked.
public struct YearComparisonChart: View {
    var comparison: YearComparison
    var compact: Bool

    public init(comparison: YearComparison, compact: Bool = false) {
        self.comparison = comparison
        self.compact = compact
    }

    public static let thisYearColor = Color(red: 0.08, green: 0.45, blue: 0.92)
    public static let lastYearColor = Color(red: 0.93, green: 0.52, blue: 0.10)
    public static let averageColor = Color.gray
    public static let rangeColor = Color.blue.opacity(0.1)

    public var body: some View {
        Chart {
            ForEach(comparison.range) { point in
                AreaMark(x: .value("Fecha", point.date), yStart: .value("Mínimo", point.lowHm3), yEnd: .value("Máximo", point.highHm3),
                         series: .value("Serie", "range"))
                    .foregroundStyle(Self.rangeColor)
            }
            ForEach(comparison.average) { point in
                LineMark(x: .value("Fecha", point.date), y: .value("hm³", point.volumeHm3), series: .value("Serie", "average"))
                    .foregroundStyle(Self.averageColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            ForEach(comparison.lastYear) { point in
                LineMark(x: .value("Fecha", point.date), y: .value("hm³", point.volumeHm3), series: .value("Serie", "lastYear"))
                    .foregroundStyle(Self.lastYearColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            ForEach(comparison.thisYear) { point in
                LineMark(x: .value("Fecha", point.date), y: .value("hm³", point.volumeHm3), series: .value("Serie", "thisYear"))
                    .foregroundStyle(Self.thisYearColor)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            if let today = comparison.thisYear.last {
                PointMark(x: .value("Fecha", today.date), y: .value("hm³", today.volumeHm3))
                    .foregroundStyle(Self.thisYearColor)
                    .symbolSize(compact ? 40 : 70)
                    .annotation(position: .top, alignment: .trailing) {
                        if !compact {
                            Text("hoy", bundle: .module).font(.caption2.weight(.bold)).foregroundStyle(Self.thisYearColor)
                        }
                    }
            }
            RuleMark(y: .value("Capacidad", comparison.capacityHm3))
                .foregroundStyle(.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }
        .chartYScale(domain: 0...(max(comparison.capacityHm3, (comparison.lastYear + comparison.thisYear).map(\.volumeHm3).max() ?? 0) * 1.05))
        .chartYAxisLabel("hm³")
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: compact ? 3 : 2)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Format.locale))
            }
        }
        .chartLegend(.hidden)
        .accessibilityChartDescriptor(YearComparisonDescriptor(comparison: comparison))
    }

    /// The legend, separate so it can sit above or below the chart and reflow at large text sizes.
    public struct Legend: View {
        public init() {}
        public var body: some View {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { items }
                VStack(alignment: .leading, spacing: 4) { items }
            }
            .font(.caption.weight(.medium))
        }

        @ViewBuilder private var items: some View {
            item("Este año", YearComparisonChart.thisYearColor, dashed: false)
            item("Año pasado", YearComparisonChart.lastYearColor, dashed: false)
            item("Media 10 años", YearComparisonChart.averageColor, dashed: true)
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(YearComparisonChart.rangeColor.opacity(2.5)).frame(width: 14, height: 9)
                Text("Desde 1988", bundle: .module)
            }
        }

        private func item(_ title: LocalizedStringKey, _ color: Color, dashed: Bool) -> some View {
            HStack(spacing: 6) {
                Capsule().fill(color).frame(width: 16, height: 3).opacity(dashed ? 0.7 : 1)
                Text(title, bundle: .module)
            }
        }
    }
}

/// Audio Graphs for the year chart: one series per line, the date on x and the volume on y.
struct YearComparisonDescriptor: AXChartDescriptorRepresentable {
    var comparison: YearComparison

    func makeChartDescriptor() -> AXChartDescriptor {
        let dates = (comparison.lastYear + comparison.thisYear).map(\.date)
        let start = dates.min() ?? .now
        let end = dates.max() ?? .now
        let x = AXNumericDataAxisDescriptor(title: String(localized: "Fecha", bundle: .module),
                                            range: start.timeIntervalSince1970...max(end.timeIntervalSince1970, start.timeIntervalSince1970 + 1),
                                            gridlinePositions: []) { Format.dayMonth(Date(timeIntervalSince1970: $0)) }
        let y = AXNumericDataAxisDescriptor(title: "hm³", range: 0...comparison.capacityHm3, gridlinePositions: []) { Format.hm3($0, .mitecoVolume) }
        func series(_ name: String, _ points: [YearComparison.Point]) -> AXDataSeriesDescriptor {
            AXDataSeriesDescriptor(name: name, isContinuous: true, dataPoints: points.map {
                AXDataPoint(x: $0.date.timeIntervalSince1970, y: $0.volumeHm3)
            })
        }
        return AXChartDescriptor(
            title: String(localized: "Este año, el año pasado y la media de 10 años", bundle: .module),
            summary: summary,
            xAxis: x, yAxis: y, additionalAxes: [],
            series: [
                series(String(localized: "Este año", bundle: .module), comparison.thisYear),
                series(String(localized: "Año pasado", bundle: .module), comparison.lastYear),
                series(String(localized: "Media 10 años", bundle: .module), comparison.average),
            ]
        )
    }

    private var summary: String {
        guard let now = comparison.thisYear.last?.volumeHm3 else { return "" }
        var parts = [String(localized: "Esta semana \(Format.hm3(now, .mitecoVolume))", bundle: .module)]
        if let last = comparison.lastYearNow { parts.append(String(localized: "hace un año \(Format.hm3(last, .mitecoVolume))", bundle: .module)) }
        if let average = comparison.averageNow { parts.append(String(localized: "media de 10 años \(Format.hm3(average, .mitecoVolume))", bundle: .module)) }
        return parts.joined(separator: ", ")
    }
}

/// "El río": each reservoir as a small tank at its own level, with its percentage, volume and SAIH time. From
/// direction B, so the three can be compared at a glance.
public struct ReservoirTank: View {
    var reading: ReservoirReading
    var isCurrent: Bool
    var tankHeight: CGFloat
    @Environment(\.colorScheme) private var scheme

    public init(reading: ReservoirReading, isCurrent: Bool, tankHeight: CGFloat = 110) {
        self.reading = reading
        self.isCurrent = isCurrent
        self.tankHeight = tankHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.sky(scheme))
                WaveShape(level: reading.percent / 100, phase: 0.6, amplitude: 2.5)
                    .fill(Palette.water(reading.percent))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.primary.opacity(isCurrent ? 0.35 : 0.12), lineWidth: isCurrent ? 2 : 1)
            }
            .frame(height: tankHeight)
            .accessibilityHidden(true)
            Text(reading.reservoir.name).font(.subheadline.weight(isCurrent ? .bold : .semibold)).lineLimit(2)
            Text(Format.percent(reading.percent)).figureFont(.title3)
            Text(Format.hm3(reading.volumeHm3)).font(.footnote).foregroundStyle(.secondary)
            Text(Format.saihSource(reading.observedAt)).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Direction C's idea, where the curve is the subject: the last days drawn as the water's surface on a 0-to-capacity
/// scale, labelled at both ends inside the water.
public struct SurfaceHistory: View {
    var volumes: [Double]
    var capacityHm3: Double
    var showsLabels: Bool

    public init(volumes: [Double], capacityHm3: Double, showsLabels: Bool = true) {
        self.volumes = volumes
        self.capacityHm3 = capacityHm3
        self.showsLabels = showsLabels
    }

    public var body: some View {
        GeometryReader { proxy in
            let levels = volumes.map { min(max($0 / max(capacityHm3, 1), 0), 1) }
            let lowest = levels.min() ?? 0
            ZStack(alignment: .bottom) {
                CurveShape(levels: levels).fill(Palette.waterCrest).offset(x: -14, y: -3)
                CurveShape(levels: levels).fill(Palette.water((levels.last ?? 0) * 100))
                if showsLabels, let first = volumes.first, let last = volumes.last {
                    // Below the lowest point of the surface, so no label ever touches it.
                    HStack(alignment: .top) {
                        label(String(localized: "hace \(volumes.count) días", bundle: .module), first)
                        Spacer()
                        label(String(localized: "hoy", bundle: .module), last).multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: proxy.size.height * lowest - waterlineClearance, alignment: .top)
                    .padding(.top, waterlineClearance)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Últimos \(volumes.count) días, de \(Format.hm3(volumes.first ?? 0)) a \(Format.hm3(volumes.last ?? 0))", bundle: .module))
    }

    private func label(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2.weight(.semibold)).opacity(0.85)
            Text(Format.hm3(value)).figureFont(.caption)
        }
        .foregroundStyle(Palette.onWater)
    }
}

struct CurveShape: Shape {
    var levels: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard levels.count > 1 else { return Path(rect) }
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for (index, level) in levels.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(levels.count - 1)
            path.addLine(to: CGPoint(x: x, y: rect.maxY - rect.height * level))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// AEMET's forecast for the coming days: a prediction, shown apart from measured rain with its own source.
public struct ForecastStrip: View {
    var forecast: Snapshot.Forecast

    public init(forecast: Snapshot.Forecast) { self.forecast = forecast }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Previsión", bundle: .module).font(.headline)
                Spacer()
                Text(verbatim: "AEMET · " + Format.dayMonthHour(forecast.issuedAt)).font(.caption).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(forecast.days) { day in
                        VStack(spacing: 4) {
                            Text(Format.weekday(day.day)).font(.caption.weight(.semibold))
                            Image(systemName: (day.rainProbabilityPct ?? 0) >= 50 ? "cloud.rain" : "cloud.sun")
                                .symbolRenderingMode(.multicolor).font(.title3)
                            Text(day.rainProbabilityPct.map { Format.number($0, decimals: 0) + Format.space + "%" } ?? "—").figureFont(.subheadline)
                            if let high = day.maxTemperatureC, let low = day.minTemperatureC {
                                Text("\(Format.number(high, decimals: 0))° \(Format.number(low, decimals: 0))°").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Text("Probabilidad de lluvia. Es una predicción, no una medida.", bundle: .module).font(.caption).foregroundStyle(.secondary)
        }
    }
}
