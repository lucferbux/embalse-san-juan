import Charts
import SwiftUI
import WidgetKit

/// Widget content lives here so tests can render every size to images.
///
/// docs/design/DESIGN-2.0.md, widgets: one full-bleed surface with white text, so nothing reads differently above and
/// below the waterline. Every family shows the percentage, the volume, the trend as a word and a dated source; a stale
/// reading shows its full date first. Medium adds the MITECO panel, styled apart; large draws the last 90 days as the
/// water's surface.

private enum WidgetStyle {
    static let secondary = Color.white.opacity(0.8)
    static let margin: CGFloat = 15
}

/// What a widget shows: one reservoir's reading, and San Juan's snapshot for everything else (MITECO, trend).
public struct WidgetReading: Sendable, Equatable {
    public var reading: ReservoirReading
    public var capacityHm3: Double
    /// Only San Juan has a 24-hour trend in the snapshot.
    public var trendHm3: Double?
    /// Last days of SAIH volume, oldest first, for the large widget's surface.
    public var daily: [Double]
    public var weekly: Snapshot.Weekly?

    public init(snapshot: Snapshot, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        let reading = snapshot.reading(of: reservoir)
            ?? ReservoirReading(reservoir: .sanJuan, observedAt: snapshot.live.observedAt, volumeHm3: snapshot.live.volumeHm3, percent: snapshot.live.percent)
        self.reading = reading
        if reading.reservoir == .sanJuan {
            capacityHm3 = snapshot.weekly.capacityHm3
            trendHm3 = snapshot.live.trend24hHm3
            // The surface ends at the figure it sits under: today's daily value is replaced by the live reading.
            daily = snapshot.daily.dropLast().map(\.volumeHm3) + [reading.volumeHm3]
            weekly = snapshot.weekly
        } else {
            capacityHm3 = history?.weekly.last?.capacityHm3 ?? reading.capacityHm3
            trendHm3 = nil
            daily = (history?.daily.suffix(89).map(\.volumeHm3) ?? []) + [reading.volumeHm3]
            weekly = nil
        }
    }

    func isStale(at now: Date) -> Bool { now.timeIntervalSince(reading.observedAt) > Snapshot.staleAfter }
}

/// The full-bleed background: water at the real level in the 2.0 palette, or a translucent layer on tinted and clear
/// screens, where colour belongs to the system.
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
                WaveShape(level: percent / 100, phase: 2.7, amplitude: 4).fill(Palette.waterCrest)
                WaveShape(level: percent / 100, phase: 0.6, amplitude: 4).fill(Palette.water(percent))
            }
        } else {
            WaveShape(level: percent / 100, phase: 0.6, amplitude: 4)
                .fill(.white.opacity(0.22))
                .widgetAccentable()
        }
    }

    private var skyColors: [Color] {
        scheme == .dark
            ? [Color(red: 0.02, green: 0.07, blue: 0.16), Color(red: 0.04, green: 0.12, blue: 0.26)]
            : [Color(red: 0.07, green: 0.20, blue: 0.40), Color(red: 0.09, green: 0.26, blue: 0.50)]
    }
}

/// The name and the source time. When stale, the full date comes first and is never truncated.
private struct WidgetHeader: View {
    var data: WidgetReading
    var now: Date

    var body: some View {
        if data.isStale(at: now) {
            VStack(alignment: .leading, spacing: 1) {
                Text(data.reading.reservoir.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Label(Format.dayMonthHour(data.reading.observedAt), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .fixedSize()
                    .layoutPriority(2)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(data.reading.reservoir.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 0)
                Text(verbatim: "SAIH \(Format.hour(data.reading.observedAt))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WidgetStyle.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// The percentage, then "64,4 hm³ · Estable", in one block.
private struct WidgetFigure: View {
    var data: WidgetReading
    var figureSize: CGFloat
    var showsSentence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Format.percent(data.reading.percent))
                .font(.system(size: figureSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if showsSentence, let trend = data.trendHm3 {
                Text(Format.hm3(data.reading.volumeHm3)).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(Trend.sentence(trend)).font(.caption.weight(.medium)).foregroundStyle(WidgetStyle.secondary).lineLimit(2)
            } else {
                Text(volumeAndTrend).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }

    private var volumeAndTrend: String {
        let volume = Format.hm3(data.reading.volumeHm3)
        guard let trend = data.trendHm3 else { return volume }
        return "\(volume) · \(Trend(change: trend).label)"
    }
}

/// A compact MITECO panel for widgets: its own week and source, apart from the SAIH figure.
private struct WidgetMiteco: View {
    var weekly: Snapshot.Weekly

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Format.mitecoWeek(weekly.day)).font(.caption2.weight(.semibold)).foregroundStyle(WidgetStyle.secondary).lineLimit(1).minimumScaleFactor(0.7)
            row("Esta semana", weekly.volumeHm3)
            if let lastYear = weekly.lastYearHm3 { row("Hace un año", lastYear) }
            if let average = weekly.tenYearAvgHm3 { row("Media 10 años", average) }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.22)))
    }

    private func row(_ title: LocalizedStringKey, _ value: Double) -> some View {
        HStack(spacing: 6) {
            Text(title, bundle: .module).font(.caption2).foregroundStyle(WidgetStyle.secondary).lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 2)
            Text(Format.hm3(value, .mitecoVolume)).font(.caption.weight(.semibold)).monospacedDigit().lineLimit(1)
        }
    }
}

/// The last days as a line, for the watch's curve page: a 0-to-capacity scale would flatten it on a small screen.
public struct VolumeChart: View {
    var points: [Snapshot.DailyPoint]

    public init(points: [Snapshot.DailyPoint]) {
        self.points = points
    }

    public var body: some View {
        let values = points.map(\.volumeHm3)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let margin = max((high - low) * 0.25, 0.5)
        Chart(points) { point in
            AreaMark(x: .value("Día", point.day), y: .value("Volumen", point.volumeHm3))
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Día", point.day), y: .value("Volumen", point.volumeHm3))
                .foregroundStyle(.white)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartYScale(domain: (low - margin)...(high + margin))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: [low, high]) { value in
                AxisValueLabel {
                    if let volume = value.as(Double.self) { Text(Format.hm3(volume, decimals: 0)).foregroundStyle(WidgetStyle.secondary) }
                }
            }
        }
        .accessibilityLabel(Text("Últimos \(points.count) días, de \(Format.hm3(values.first ?? 0)) a \(Format.hm3(values.last ?? 0))", bundle: .module))
    }
}

// MARK: - Home Screen and StandBy

public struct SmallWidgetView: View {
    var data: WidgetReading
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir, history: history)
        self.now = now
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            WidgetWaterScene(percent: data.reading.percent)
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader(data: data, now: now)
                Spacer(minLength: 0)
                WidgetFigure(data: data, figureSize: 34)
            }
            .padding(WidgetStyle.margin)
        }
        .foregroundStyle(.white)
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
        ZStack(alignment: .topLeading) {
            WidgetWaterScene(percent: data.reading.percent)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetHeader(data: data, now: now)
                    Spacer(minLength: 0)
                    WidgetFigure(data: data, figureSize: 40, showsSentence: true)
                }
                if let weekly = data.weekly {
                    WidgetMiteco(weekly: weekly).frame(width: 150)
                }
            }
            .padding(WidgetStyle.margin)
        }
        .foregroundStyle(.white)
    }
}

public struct LargeWidgetView: View {
    var data: WidgetReading
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir, history: history)
        self.now = now
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Direction C, where the curve is the subject: the surface is the last 90 days, 0 to capacity.
            LinearGradient(colors: [Color(red: 0.07, green: 0.20, blue: 0.40), Color(red: 0.09, green: 0.26, blue: 0.50)], startPoint: .top, endPoint: .bottom)
            if data.daily.count > 1 {
                SurfaceHistory(volumes: data.daily, capacityHm3: data.capacityHm3)
            } else {
                WidgetWaterScene(percent: data.reading.percent)
            }
            // The figure in the sky above the surface, MITECO in the bottom corner, clear of the surface's labels.
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(data: data, now: now)
                WidgetFigure(data: data, figureSize: 48, showsSentence: true)
                Spacer(minLength: 0)
                if let weekly = data.weekly {
                    HStack {
                        Spacer(minLength: 0)
                        WidgetMiteco(weekly: weekly).frame(width: 190)
                    }
                }
            }
            .padding(WidgetStyle.margin)
        }
        .foregroundStyle(.white)
    }
}

public struct ExtraLargeWidgetView: View {
    var data: WidgetReading
    var now: Date

    public init(snapshot: Snapshot, now: Date = .now, reservoir: ReservoirID = .sanJuan, history: History? = nil) {
        data = WidgetReading(snapshot: snapshot, reservoir: reservoir, history: history)
        self.now = now
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.07, green: 0.20, blue: 0.40), Color(red: 0.09, green: 0.26, blue: 0.50)], startPoint: .top, endPoint: .bottom)
            if data.daily.count > 1 {
                SurfaceHistory(volumes: data.daily, capacityHm3: data.capacityHm3)
            } else {
                WidgetWaterScene(percent: data.reading.percent)
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetHeader(data: data, now: now)
                    WidgetFigure(data: data, figureSize: 64, showsSentence: true)
                }
                Spacer(minLength: 0)
                if let weekly = data.weekly {
                    WidgetMiteco(weekly: weekly).frame(width: 220)
                }
            }
            .padding(WidgetStyle.margin + 4)
        }
        .foregroundStyle(.white)
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
            // "48,7" with its unit in the label below: a circular complication has no room for "%" at this size.
            Text(Format.number(data.reading.percent, decimals: 1)).monospacedDigit()
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
        VStack(alignment: .leading, spacing: 1) {
            Label(data.reading.reservoir.name, systemImage: "water.waves").font(.headline).widgetAccentable()
            Text(verbatim: "\(Format.percent(data.reading.percent)) · \(Format.hm3(data.reading.volumeHm3))")
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: "\(data.trendHm3.map { Trend(change: $0).label } ?? "") · SAIH \(Format.hour(data.reading.observedAt))")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
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
            Image(systemName: "water.waves")
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

    public static func preview(_ reservoir: ReservoirID) -> ReservoirEntry {
        ReservoirEntry(date: .now, snapshot: repository.cached() ?? .placeholder, reservoir: reservoir,
                       history: reservoir == .sanJuan ? nil : HistoryRepository().cached(reservoir))
    }

    public static func entry(_ reservoir: ReservoirID) async -> ReservoirEntry {
        let snapshot = (try? await repository.load().snapshot) ?? repository.cached() ?? .placeholder
        let history = reservoir == .sanJuan ? nil : try? await HistoryRepository().load(reservoir)
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
