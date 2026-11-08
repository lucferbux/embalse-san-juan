import Charts
import SwiftUI
import WidgetKit

/// Widget content lives here so tests can render every size to images.
///
/// docs/design/review-2.0/SYNTHESIS.md, widgets: the water card's light sky (dark in dark mode) and the real level.
/// The figure goes wholly in the water, in white, or wholly in the sky, in the label colour, never across the
/// waterline: the same rule as the app. The name and the source time sit at the top, which is always sky. History
/// widgets draw the last year (SAIH) or this year against the average (MITECO), never both.

private enum WidgetStyle {
    static let margin: CGFloat = 14
    /// Room at the top for the name and the time; the level is drawn below it.
    static func top(_ size: CGSize) -> CGFloat { size.height > 300 ? 62 : 36 }
}

/// What a widget shows: one reservoir's reading, and San Juan's snapshot for everything else (MITECO, trend).
public struct WidgetReading: Sendable, Equatable {
    public var reading: ReservoirReading
    public var capacityHm3: Double
    /// Only San Juan has a 24-hour trend in the snapshot.
    public var trendHm3: Double?
    public var weekly: Snapshot.Weekly?
    public var surface: YearSurface?
    public var comparison: YearComparison?

    public init(snapshot: Snapshot, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        let reading = snapshot.reading(of: reservoir)
            ?? ReservoirReading(reservoir: .sanJuan, observedAt: snapshot.live.observedAt, volumeHm3: snapshot.live.volumeHm3, percent: snapshot.live.percent)
        self.reading = reading
        if reading.reservoir == .sanJuan {
            capacityHm3 = snapshot.weekly.capacityHm3
            trendHm3 = snapshot.live.trend24hHm3
            weekly = snapshot.weekly
        } else {
            capacityHm3 = history?.weekly.last?.capacityHm3 ?? reading.capacityHm3
            trendHm3 = nil
            weekly = nil
        }
        surface = history.flatMap { YearSurface(history: $0, today: reading, capacityHm3: capacityHm3) }
        comparison = history.flatMap(YearComparison.init)
    }

    func isStale(at now: Date) -> Bool { now.timeIntervalSince(reading.observedAt) > Snapshot.staleAfter }
}

/// The sky, and the water at the real level below the header's room. On tinted and clear screens the water is a
/// translucent layer and colour belongs to the system.
struct WidgetLevelBackground: View {
    var percent: Double
    var top: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if renderingMode == .fullColor { Rectangle().fill(Palette.sky(scheme)) }
                Group {
                    if renderingMode == .fullColor {
                        ZStack {
                            WaveShape(level: percent / 100, phase: 2.7, amplitude: 3).fill(Palette.waterCrest)
                            WaveShape(level: percent / 100, phase: 0.6, amplitude: 3).fill(Palette.water(percent))
                        }
                    } else {
                        WaveShape(level: percent / 100, phase: 0.6, amplitude: 3).fill(.white.opacity(0.22)).widgetAccentable()
                    }
                }
                .frame(height: max(proxy.size.height - top, 0))
            }
        }
    }
}

/// Places a block over `WidgetLevelBackground`: at the bottom, in white, when the water is deep enough for it, or
/// just above the waterline in the label colour.
struct WidgetLevelLayout<Header: View, Block: View>: View {
    var percent: Double
    /// The block's height, estimated: widgets can't measure and re-lay out.
    var block: CGFloat
    @ViewBuilder var header: Header
    var content: (_ onWater: Bool) -> Block
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { proxy in
            let top = WidgetStyle.top(proxy.size)
            let placement = FigurePlacement.decide(height: proxy.size.height - top, percent: percent, amplitude: 3,
                                                   block: block, bottomInset: WidgetStyle.margin - 4)
            let onWater = placement.isOnWater && renderingMode == .fullColor
            ZStack(alignment: .topLeading) {
                WidgetLevelBackground(percent: percent, top: top)
                header
                    .padding(.horizontal, WidgetStyle.margin)
                    .padding(.top, WidgetStyle.margin - 2)
                Group {
                    switch placement {
                    case .water:
                        content(onWater).frame(maxHeight: .infinity, alignment: .bottomLeading).padding(.bottom, WidgetStyle.margin - 2)
                    case .sky(let bottom):
                        content(onWater).frame(height: top + bottom, alignment: .bottomLeading)
                    }
                }
                .foregroundStyle(onWater ? AnyShapeStyle(Palette.onWater) : AnyShapeStyle(.primary))
                .padding(.horizontal, WidgetStyle.margin)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The name and the source time, in the sky. When stale, the full date comes first and is never truncated.
private struct WidgetHeader: View {
    var data: WidgetReading
    var now: Date
    var subtitle: String?
    var source: String?

    var body: some View {
        if data.isStale(at: now) {
            VStack(alignment: .leading, spacing: 1) {
                Text(data.reading.reservoir.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Label(Format.dayMonthHour(data.reading.observedAt), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(.orange).lineLimit(1).fixedSize()
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(data.reading.reservoir.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                }
                Spacer(minLength: 0)
                Text(verbatim: source ?? Format.hour(data.reading.observedAt))
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary).lineLimit(1).fixedSize()
            }
        }
    }
}

private extension View {
    func secondary(_ onWater: Bool) -> some View { opacity(onWater ? 0.85 : 0.7) }
}

private func figure(_ data: WidgetReading, size: CGFloat) -> some View {
    Text(Format.percent(data.reading.percent))
        .font(.system(size: size, weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
}

private func trendLine(_ data: WidgetReading, sentence: Bool) -> Text? {
    guard let trend = data.trendHm3 else { return nil }
    return Text(sentence ? Trend.sentence(trend) : Trend(change: trend).label)
}

// MARK: - Home Screen and StandBy: Ahora

public struct SmallWidgetView: View {
    var data: WidgetReading
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir, history: history)
        self.now = now
    }

    public var body: some View {
        WidgetLevelLayout(percent: data.reading.percent, block: 54) {
            WidgetHeader(data: data, now: now)
        } content: { onWater in
            VStack(alignment: .leading, spacing: 1) {
                figure(data, size: 32)
                (trendLine(data, sentence: false) ?? Text(Format.hm3(data.reading.volumeHm3)))
                    .font(.caption.weight(.semibold)).secondary(onWater).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

public struct MediumWidgetView: View {
    var data: WidgetReading
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir, history: history)
        self.now = now
    }

    public var body: some View {
        WidgetLevelLayout(percent: data.reading.percent, block: 62) {
            WidgetHeader(data: data, now: now, source: "SAIH Tajo · " + Format.hour(data.reading.observedAt))
        } content: { onWater in
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    figure(data, size: 38)
                    (trendLine(data, sentence: true) ?? Text(Format.hm3(data.reading.volumeHm3)))
                        .font(.caption.weight(.medium)).secondary(onWater).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Format.volumeOfCapacity(data.reading.volumeHm3, data.capacityHm3)).font(.caption.weight(.semibold))
                    if data.reading.reservoir == .sanJuan, let weekly = data.weekly {
                        Text(verbatim: "MITECO \(Format.percent(weekly.percent))").font(.caption2).secondary(onWater)
                    }
                }
                .monospacedDigit().lineLimit(1)
            }
        }
    }
}

public struct LargeWidgetView: View {
    var data: WidgetReading
    var now: Date
    var snapshot: Snapshot

    public init(snapshot: Snapshot, now: Date = .now, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir, history: history)
        self.now = now
        self.snapshot = snapshot
    }

    public var body: some View {
        WidgetLevelLayout(percent: data.reading.percent, block: 112) {
            WidgetHeader(data: data, now: now, subtitle: data.reading.reservoir == .sanJuan ? "Río Alberche" : nil,
                         source: "SAIH Tajo · " + Format.hour(data.reading.observedAt))
        } content: { onWater in
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    figure(data, size: 56)
                    Text(Format.volumeOfCapacity(data.reading.volumeHm3, data.capacityHm3)).font(.subheadline.weight(.semibold))
                    trendLine(data, sentence: true)?.font(.caption.weight(.medium)).secondary(onWater)
                }
                .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if data.reading.reservoir == .sanJuan {
                    VStack(alignment: .trailing, spacing: 6) {
                        stat("Salida", Format.optional(snapshot.live.outflowM3s, decimals: 2, unit: "m³/s"), onWater)
                        stat("Cota", Format.optional(snapshot.live.elevationM, decimals: 1, unit: "m"), onWater)
                        stat("Lluvia 24 h", Format.optional(snapshot.weather.rain24hMm, unit: "mm"), onWater)
                    }
                }
            }
        }
    }

    private func stat(_ title: LocalizedStringKey, _ value: String, _ onWater: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(title, bundle: .module).font(.caption2).secondary(onWater)
            Text(value).font(.caption.weight(.semibold)).monospacedDigit()
        }
        .lineLimit(1)
    }
}

public struct ExtraLargeWidgetView: View {
    var large: LargeWidgetView

    public init(snapshot: Snapshot, now: Date = .now, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        large = LargeWidgetView(snapshot: snapshot, now: now, reservoir: reservoir, history: history)
    }

    public var body: some View { large }
}

// MARK: - Histórico

/// The last 12 months as the water's surface (SAIH), with last year's line and today marked.
public struct YearWidgetView: View {
    var data: WidgetReading
    var now: Date
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(snapshot: Snapshot, now: Date = .now, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir, history: history)
        self.now = now
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let top = WidgetStyle.top(size) + 4
            ZStack(alignment: .topLeading) {
                if renderingMode == .fullColor { Rectangle().fill(Palette.sky(scheme)) }
                if let surface = data.surface {
                    surfaceDrawing(surface, size: size, top: top)
                } else {
                    WidgetLevelBackground(percent: data.reading.percent, top: top)
                }
                WidgetHeader(data: data, now: now, source: "SAIH Tajo")
                    .padding(.horizontal, WidgetStyle.margin).padding(.top, WidgetStyle.margin - 2)
                VStack(alignment: .leading, spacing: 1) {
                    figure(data, size: size.height > 300 ? 48 : 30)
                    if let change = data.surface?.changeFromLastYearHm3 {
                        Text(change < 0 ? "\(Format.hm3(-change)) menos que hace un año" : "\(Format.hm3(change)) más que hace un año", bundle: .module)
                            .font(.caption.weight(.medium)).opacity(0.88).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .foregroundStyle(renderingMode == .fullColor ? AnyShapeStyle(Palette.onWater) : AnyShapeStyle(.primary))
                .padding(WidgetStyle.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func surfaceDrawing(_ surface: YearSurface, size: CGSize, top: CGFloat) -> some View {
        let usable = size.height - top
        let y = { (fraction: Double) in top + usable * (1 - min(max(fraction, 0), 1.02)) }
        let x = { (index: Int, count: Int) in size.width * CGFloat(index) / CGFloat(max(count - 1, 1)) }
        let line = { (values: [Double]) -> Path in
            var path = Path()
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: x(index, values.count), y: y(value))
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            return path
        }
        var area = line(surface.levels)
        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.addLine(to: CGPoint(x: 0, y: size.height))
        area.closeSubpath()
        var band = Path()
        if let ranges = surface.band, ranges.count > 1 {
            band.move(to: CGPoint(x: 0, y: y(ranges[0].upperBound)))
            for (index, range) in ranges.enumerated() { band.addLine(to: CGPoint(x: x(index, ranges.count), y: y(range.upperBound))) }
            for (index, range) in ranges.enumerated().reversed() { band.addLine(to: CGPoint(x: x(index, ranges.count), y: y(range.lowerBound))) }
            band.closeSubpath()
        }
        let today = CGPoint(x: size.width - 6, y: y(surface.levels.last ?? 0))
        return ZStack {
            band.fill(Palette.band(scheme))
            if renderingMode == .fullColor {
                area.fill(Palette.water(data.reading.percent))
                line(surface.levels).stroke(Palette.crestLine, lineWidth: 1.8)
                if let lastYear = surface.lastYear { line(lastYear).stroke(Palette.lastYear, style: StrokeStyle(lineWidth: 1.4, dash: [4, 3])) }
                Circle().fill(.white).frame(width: 9, height: 9).overlay(Circle().stroke(Palette.waterTop, lineWidth: 2)).position(today)
            } else {
                area.fill(.white.opacity(0.22)).widgetAccentable()
                line(surface.levels).stroke(.white, lineWidth: 1.5)
            }
        }
    }
}

/// This year against last year, the 10-year average and the range since 1988, MITECO weekly, on the water.
public struct ComparisonWidgetView: View {
    var data: WidgetReading
    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(snapshot: Snapshot, history: History?) {
        data = WidgetReading(snapshot: snapshot, reservoir: .sanJuan, history: history)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if renderingMode == .fullColor { Rectangle().fill(Palette.water(data.reading.percent)) }
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Este año, el anterior y la media", bundle: .module).font(.subheadline.weight(.bold))
                    if let weekly = data.weekly { Text(Format.mitecoWeek(weekly.day)).font(.caption).opacity(0.75) }
                }
                if let weekly = data.weekly {
                    HStack(alignment: .lastTextBaseline, spacing: 16) {
                        Text(Format.percent(weekly.percent)).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                        if let average = weekly.tenYearAvgHm3 { stat("Media 10 años", Format.hm3(average, .mitecoVolume)) }
                        if let last = weekly.lastYearHm3 { stat("Hace un año", Format.hm3(last, .mitecoVolume)) }
                    }
                    .lineLimit(1).minimumScaleFactor(0.8)
                }
                if let comparison = data.comparison {
                    chart(comparison)
                    legend
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(WidgetStyle.margin + 2)
        }
        .foregroundStyle(renderingMode == .fullColor ? AnyShapeStyle(Palette.onWater) : AnyShapeStyle(.primary))
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title, bundle: .module).font(.caption2).opacity(0.75)
            Text(value).font(.caption.weight(.semibold)).monospacedDigit()
        }
    }

    private func chart(_ comparison: YearComparison) -> some View {
        Chart {
            ForEach(comparison.range) { point in
                AreaMark(x: .value("Fecha", point.date), yStart: .value("Mínimo", point.lowHm3), yEnd: .value("Máximo", point.highHm3), series: .value("Serie", "range"))
                    .foregroundStyle(.white.opacity(0.12))
            }
            ForEach(comparison.average) { point in
                LineMark(x: .value("Fecha", point.date), y: .value("hm³", point.volumeHm3), series: .value("Serie", "average"))
                    .foregroundStyle(.white.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
            }
            ForEach(comparison.lastYear) { point in
                LineMark(x: .value("Fecha", point.date), y: .value("hm³", point.volumeHm3), series: .value("Serie", "lastYear"))
                    .foregroundStyle(Palette.lastYear).lineStyle(StrokeStyle(lineWidth: 1.6))
            }
            ForEach(comparison.thisYear) { point in
                LineMark(x: .value("Fecha", point.date), y: .value("hm³", point.volumeHm3), series: .value("Serie", "thisYear"))
                    .foregroundStyle(.white).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .chartYScale(domain: 0...comparison.capacityHm3)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            item("Este año", .white, dashed: false)
            item("Año pasado", Palette.lastYear, dashed: false)
            item("Media", .white.opacity(0.6), dashed: true)
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.2)).frame(width: 12, height: 8)
                Text("Desde 1988", bundle: .module)
            }
        }
        .font(.caption2).opacity(0.85).lineLimit(1).minimumScaleFactor(0.7)
    }

    private func item(_ title: LocalizedStringKey, _ color: Color, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 12, height: dashed ? 1.5 : 3)
            Text(title, bundle: .module)
        }
    }
}

/// "El río": the three reservoirs in river order, each at its own level.
public struct RiverWidgetView: View {
    var snapshot: Snapshot
    var now: Date
    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(snapshot: Snapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        GeometryReader { proxy in content(showsNames: proxy.size.width > 220) }
    }

    private func content(showsNames: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("El río", bundle: .module).font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text(verbatim: Format.hour(snapshot.live.observedAt)).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            }
            HStack(spacing: 7) {
                ForEach(snapshot.chain) { reading in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(renderingMode == .fullColor ? AnyShapeStyle(Palette.sky(scheme)) : AnyShapeStyle(.white.opacity(0.08)))
                            WaveShape(level: reading.percent / 100, phase: 0.6, amplitude: 2)
                                .fill(renderingMode == .fullColor ? AnyShapeStyle(Palette.water(reading.percent)) : AnyShapeStyle(.white.opacity(0.3)))
                                .widgetAccentable()
                            Text(Format.number(reading.percent, decimals: 0) + Format.space + "%")
                                .font(.caption.weight(.bold)).monospacedDigit()
                                .foregroundStyle(renderingMode == .fullColor ? AnyShapeStyle(Palette.onWater) : AnyShapeStyle(.primary))
                                .padding(.bottom, 6)
                        }
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                        .overlay {
                            if reading.reservoir == .sanJuan {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.primary.opacity(0.35), lineWidth: 1.5)
                            }
                        }
                        if showsNames {
                            Text(reading.reservoir.name).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                }
            }
        }
        .padding(WidgetStyle.margin)
        .background { if renderingMode == .fullColor { Rectangle().fill(Palette.sky(scheme).opacity(0.5)) } }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Lock Screen and complications: the same figures and number style

public struct CircularLockWidgetView: View {
    var data: WidgetReading

    public init(snapshot: Snapshot, reservoir: ReservoirID = .sanJuan) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir)
    }

    public var body: some View {
        Gauge(value: data.reading.percent, in: 0...100) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            // A circular complication has no room for decimals and "%" at this size.
            Text(Format.number(data.reading.percent, decimals: 0)).monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel(Text(verbatim: "\(data.reading.reservoir.name), \(Format.percent(data.reading.percent))"))
    }
}

public struct RectangularLockWidgetView: View {
    var data: WidgetReading

    public init(snapshot: Snapshot, reservoir: ReservoirID = .sanJuan) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "\(data.reading.reservoir.name) · \(Format.hour(data.reading.observedAt))").font(.caption.weight(.semibold)).widgetAccentable()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Format.percent(data.reading.percent)).font(.title3.weight(.bold)).monospacedDigit()
                if let trend = data.trendHm3 { Text(Trend(change: trend).label).font(.caption) }
            }
            .lineLimit(1).minimumScaleFactor(0.8)
            Gauge(value: data.reading.percent, in: 0...100) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct InlineLockWidgetView: View {
    var data: WidgetReading

    public init(snapshot: Snapshot, reservoir: ReservoirID = .sanJuan) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir)
    }

    public var body: some View {
        Label {
            Text(verbatim: "\(data.reading.reservoir.name) \(Format.percent(data.reading.percent))\(data.trendHm3.map { " · " + Trend(change: $0).label } ?? "")")
        } icon: {
            Image(systemName: "drop.fill")
        }
    }
}

#if os(watchOS)
/// The corner complication: the percentage, with the level as the curved gauge.
public struct CornerWatchWidgetView: View {
    var data: WidgetReading

    public init(snapshot: Snapshot, reservoir: ReservoirID = .sanJuan) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir)
    }

    public var body: some View {
        Text(Format.percent(data.reading.percent))
            .monospacedDigit()
            .widgetCurvesContent()
            .widgetLabel {
                Gauge(value: data.reading.percent, in: 0...100) { Text(verbatim: data.reading.reservoir.name) }
                    .tint(Palette.waterTop)
            }
    }
}
#endif

// MARK: - Timeline

/// The timeline shared by the iPhone, iPad and Apple Watch widgets.
public struct ReservoirEntry: TimelineEntry {
    public let date: Date
    public let snapshot: Snapshot
    public let reservoir: ReservoirID
    public let history: History?

    public init(date: Date, snapshot: Snapshot, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        self.date = date
        self.snapshot = snapshot
        self.reservoir = reservoir
        self.history = history
    }
}

/// Loads the snapshot, plus a neighbour's history when the widget shows Burguillo or Picadas.
public enum ReservoirTimeline {
    static let repository = SnapshotRepository()

    public static func placeholder() -> ReservoirEntry { ReservoirEntry(date: .now, snapshot: .placeholder) }

    public static func preview(_ reservoir: ReservoirID, withHistory: Bool = false) -> ReservoirEntry {
        ReservoirEntry(date: .now, snapshot: repository.cached() ?? .placeholder, reservoir: reservoir,
                       history: reservoir == .sanJuan && !withHistory ? nil : HistoryRepository().cached(reservoir))
    }

    /// `withHistory` also loads San Juan's history, for the history widgets; neighbours always need theirs.
    public static func entry(_ reservoir: ReservoirID, withHistory: Bool = false) async -> ReservoirEntry {
        let snapshot = (try? await repository.load().snapshot) ?? repository.cached() ?? .placeholder
        let history = reservoir == .sanJuan && !withHistory ? nil : try? await HistoryRepository().load(reservoir)
        return ReservoirEntry(date: .now, snapshot: snapshot, reservoir: reservoir, history: history)
    }

    /// New data lands a few minutes after the collector's :41 run, so aim for just after that.
    public static func nextRefresh(after date: Date) -> Date {
        Calendar(identifier: .gregorian).nextDate(after: date, matching: DateComponents(minute: 50), matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(3600)
    }
}

/// For the Lock Screen and complications, which always show San Juan.
public struct ReservoirProvider: TimelineProvider, Sendable {
    public init() {}

    public func placeholder(in context: Context) -> ReservoirEntry { ReservoirTimeline.placeholder() }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (ReservoirEntry) -> Void) {
        if context.isPreview { return completion(ReservoirTimeline.preview(.sanJuan)) }
        Task { completion(await ReservoirTimeline.entry(.sanJuan)) }
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ReservoirEntry>) -> Void) {
        Task {
            let entry = await ReservoirTimeline.entry(.sanJuan)
            completion(Timeline(entries: [entry], policy: .after(ReservoirTimeline.nextRefresh(after: .now))))
        }
    }
}
