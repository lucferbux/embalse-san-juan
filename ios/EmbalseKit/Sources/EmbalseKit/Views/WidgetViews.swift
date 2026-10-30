import Charts
import SwiftUI
import WidgetKit

/// Widget content lives here so tests can render every size to images.
///
/// Every home screen widget is one surface: the water fills the whole widget and all the text is
/// white, so it reads the same above and below the waterline and nothing is cut across it.

private enum WidgetStyle {
    static let secondary = Color.white.opacity(0.78)
    static let margin: CGFloat = 15
}

/// The full-bleed background: deep water colours, or a translucent layer on tinted and clear screens.
public struct WidgetWaterScene: View {
    var percent: Double
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var scheme

    public init(percent: Double) {
        self.percent = percent
    }

    public var body: some View {
        if renderingMode == .fullColor {
            ZStack {
                LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
                WaveShape(level: percent / 100, phase: 2.7, amplitude: 5)
                    .fill(Color(red: 0.30, green: 0.62, blue: 0.98).opacity(0.42))
                WaveShape(level: percent / 100, phase: 0.6, amplitude: 5)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.11, green: 0.45, blue: 0.90), Color(red: 0.03, green: 0.27, blue: 0.68)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
        } else {
            WaveShape(level: percent / 100, phase: 0.6, amplitude: 5)
                .fill(.white.opacity(0.22))
                .widgetAccentable()
        }
    }

    private var skyColors: [Color] {
        scheme == .dark
            ? [Color(red: 0.02, green: 0.07, blue: 0.16), Color(red: 0.04, green: 0.13, blue: 0.28)]
            : [Color(red: 0.06, green: 0.18, blue: 0.38), Color(red: 0.09, green: 0.27, blue: 0.52)]
    }
}

private struct WidgetHeader: View {
    var snapshot: Snapshot
    var now: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(snapshot.reservoir.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 0)
            Group {
                if snapshot.isStale(at: now) {
                    Label(Format.dayMonth(snapshot.live.observedAt), systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleAndIcon)
                } else {
                    Text(Format.hour(snapshot.live.observedAt))
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(WidgetStyle.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}

/// The percentage, with the volume and trend below it.
private struct WidgetReading: View {
    var snapshot: Snapshot
    var size: CGFloat

    var body: some View {
        let trend = Trend(change: snapshot.live.trend24hHm3)
        VStack(alignment: .leading, spacing: 1) {
            Text(Format.percent(snapshot.live.percent))
                .font(.system(size: size, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            HStack(spacing: 4) {
                Image(systemName: trend.symbol)
                    .accessibilityLabel(trend.label)
                Text(Format.hm3(snapshot.live.volumeHm3))
            }
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
    }
}

private struct WidgetStat: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(WidgetStyle.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// The evolution of the volume, drawn in white so it sits on the water as well as above it.
public struct VolumeChart: View {
    var points: [Snapshot.DailyPoint]

    public init(points: [Snapshot.DailyPoint]) {
        self.points = points
    }

    public var body: some View {
        let values = points.map(\.volumeHm3)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let margin = max((high - low) * 0.18, 0.5)
        Chart(points) { point in
            AreaMark(
                x: .value("Día", point.day),
                yStart: .value("Base", low - margin),
                yEnd: .value("Volumen", point.volumeHm3)
            )
            .foregroundStyle(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Día", point.day), y: .value("Volumen", point.volumeHm3))
                .foregroundStyle(.white)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .widgetAccentable()
        .chartYScale(domain: (low - margin)...(high + margin))
        .chartXAxis(.hidden)
        .chartYAxis {
            // On a nearly flat line, whole numbers would label both ends the same.
            AxisMarks(position: .trailing, values: high - low < 2 ? [high] : [low, high]) { value in
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(Format.number(number, decimals: 0))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(WidgetStyle.secondary)
                    }
                }
            }
        }
        .accessibilityLabel("Evolución del volumen")
    }
}

public struct SmallWidgetView: View {
    var snapshot: Snapshot
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        ZStack {
            WidgetWaterScene(percent: snapshot.live.percent)
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader(snapshot: snapshot, now: now)
                Spacer(minLength: 0)
                WidgetReading(snapshot: snapshot, size: 38)
            }
            .padding(WidgetStyle.margin)
        }
        .foregroundStyle(.white)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

public struct MediumWidgetView: View {
    var snapshot: Snapshot
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        ZStack {
            WidgetWaterScene(percent: snapshot.live.percent)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetHeader(snapshot: snapshot, now: now)
                    Spacer(minLength: 0)
                    WidgetReading(snapshot: snapshot, size: 36)
                }
                .frame(maxWidth: 134)
                VStack(alignment: .leading, spacing: 6) {
                    VolumeChart(points: Array(snapshot.daily.suffix(30)))
                        .frame(maxHeight: .infinity)
                    HStack(alignment: .top, spacing: 12) {
                        WidgetStat(title: "Boletín", value: Format.hm3(snapshot.weekly.volumeHm3, decimals: 0))
                        WidgetStat(title: "Hace un año", value: snapshot.weekly.lastYearHm3.map { Format.hm3($0, decimals: 0) } ?? "Sin dato")
                    }
                }
            }
            .padding(WidgetStyle.margin)
        }
        .foregroundStyle(.white)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

public struct LargeWidgetView: View {
    var snapshot: Snapshot
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        ZStack {
            WidgetWaterScene(percent: snapshot.live.percent)
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(snapshot: snapshot, now: now)
                WidgetReading(snapshot: snapshot, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Últimos 90 días")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WidgetStyle.secondary)
                    VolumeChart(points: snapshot.daily)
                }
                .frame(maxHeight: .infinity)
                HStack(alignment: .top, spacing: 0) {
                    WidgetStat(title: "Boletín", value: Format.hm3(snapshot.weekly.volumeHm3, decimals: 0))
                    Spacer(minLength: 6)
                    WidgetStat(title: "Hace un año", value: snapshot.weekly.lastYearHm3.map { Format.hm3($0, decimals: 0) } ?? "Sin dato")
                    Spacer(minLength: 6)
                    WidgetStat(title: "Caudal", value: Format.optional(snapshot.live.outflowM3s, unit: "m³/s"))
                }
            }
            .padding(WidgetStyle.margin + 1)
        }
        .foregroundStyle(.white)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/// iPad's extra large size: the same reading with room for the whole chain of reservoirs.
public struct ExtraLargeWidgetView: View {
    var snapshot: Snapshot
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        ZStack {
            WidgetWaterScene(percent: snapshot.live.percent)
            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    WidgetHeader(snapshot: snapshot, now: now)
                    WidgetReading(snapshot: snapshot, size: 64)
                    Spacer(minLength: 0)
                    WidgetStat(title: "Boletín", value: Format.hm3(snapshot.weekly.volumeHm3, decimals: 0))
                    WidgetStat(title: "Hace un año", value: snapshot.weekly.lastYearHm3.map { Format.hm3($0, decimals: 0) } ?? "Sin dato")
                    WidgetStat(title: "Media de 10 años", value: snapshot.weekly.tenYearAvgHm3.map { Format.hm3($0) } ?? "Sin dato")
                    WidgetStat(title: "Caudal al río", value: Format.optional(snapshot.live.outflowM3s, unit: "m³/s"))
                }
                .frame(width: 190, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Últimos 90 días")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetStyle.secondary)
                    VolumeChart(points: snapshot.daily)
                        .frame(maxHeight: .infinity)
                    HStack(alignment: .top) {
                        ForEach(snapshot.neighbours) { neighbour in
                            WidgetStat(title: neighbour.name, value: Format.percent(neighbour.percent))
                            Spacer(minLength: 8)
                        }
                        WidgetStat(title: "Lluvia en 24 h", value: Format.optional(snapshot.weather.rain24hMm, unit: "mm"))
                    }
                }
            }
            .padding(WidgetStyle.margin + 5)
        }
        .foregroundStyle(.white)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

public struct CircularLockWidgetView: View {
    var snapshot: Snapshot

    public init(snapshot: Snapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        Gauge(value: snapshot.live.percent, in: 0...100) {
            Image(systemName: "water.waves")
        } currentValueLabel: {
            Text(Format.number(snapshot.live.percent, decimals: 0))
                .font(.system(.title3, design: .rounded).weight(.semibold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

public struct RectangularLockWidgetView: View {
    var snapshot: Snapshot

    public init(snapshot: Snapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        let trend = Trend(change: snapshot.live.trend24hHm3)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "water.waves")
                Text(snapshot.reservoir.name)
            }
            .font(.caption.weight(.semibold))
            .widgetAccentable()
            HStack(spacing: 4) {
                Text("\(Format.percent(snapshot.live.percent)) · \(Format.hm3(snapshot.live.volumeHm3))")
                Image(systemName: trend.symbol)
                    .accessibilityLabel(trend.label)
            }
            .font(.footnote)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule()
                        .fill(.white)
                        .frame(width: proxy.size.width * min(max(snapshot.live.percent, 0), 100) / 100)
                        .widgetAccentable()
                }
            }
            .frame(height: 5)
            .accessibilityHidden(true)
        }
    }
}

public struct InlineLockWidgetView: View {
    var snapshot: Snapshot

    public init(snapshot: Snapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        Label("\(snapshot.reservoir.name) \(Format.percent(snapshot.live.percent))", systemImage: "water.waves")
    }
}

#if os(watchOS)
/// The corner complication: the percentage, with the gauge following the curve of the watch face.
public struct CornerWatchWidgetView: View {
    var snapshot: Snapshot

    public init(snapshot: Snapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        Text(Format.number(snapshot.live.percent, decimals: 0))
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .widgetAccentable()
            .widgetLabel {
                Gauge(value: snapshot.live.percent, in: 0...100) {
                    Text(snapshot.reservoir.name)
                } currentValueLabel: {
                    Text(Format.percent(snapshot.live.percent))
                }
            }
    }
}
#endif

/// The timeline shared by the iPhone, iPad and Apple Watch widgets.
public struct ReservoirEntry: TimelineEntry {
    public let date: Date
    public let snapshot: Snapshot

    public init(date: Date, snapshot: Snapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

public struct ReservoirProvider: TimelineProvider, Sendable {
    private let repository = SnapshotRepository()

    public init() {}

    public func placeholder(in context: Context) -> ReservoirEntry {
        ReservoirEntry(date: .now, snapshot: .placeholder)
    }

    public func getSnapshot(in context: Context, completion: @escaping @Sendable (ReservoirEntry) -> Void) {
        if context.isPreview {
            completion(ReservoirEntry(date: .now, snapshot: repository.cached() ?? .placeholder))
            return
        }
        Task {
            let result = try? await repository.load()
            completion(ReservoirEntry(date: .now, snapshot: result?.snapshot ?? .placeholder))
        }
    }

    public func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ReservoirEntry>) -> Void) {
        Task {
            let result = try? await repository.load()
            let snapshot = result?.snapshot ?? repository.cached() ?? .placeholder
            let entry = ReservoirEntry(date: .now, snapshot: snapshot)
            completion(Timeline(entries: [entry], policy: .after(Self.nextRefresh(after: .now))))
        }
    }

    /// New data lands a few minutes after the collector's :41 run, so aim for just after that.
    static func nextRefresh(after date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.nextDate(after: date, matching: DateComponents(minute: 50), matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(3600)
    }
}
