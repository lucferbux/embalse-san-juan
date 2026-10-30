import Charts
import SwiftUI
import WidgetKit

/// Widget content lives here so tests can render every size to images. Each view fills its
/// space edge to edge: the widget target disables content margins.

private struct WidgetWater<Content: View>: View {
    var percent: Double
    @ViewBuilder var content: () -> Content
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if renderingMode == .fullColor {
                Rectangle().fill(Palette.sky(scheme))
                WaterFill(percent: percent)
                WaterlineText(percent: percent, content: content)
            } else {
                // Tinted and clear home screens use only alpha, so the water is a translucent layer.
                WaveShape(level: percent / 100, phase: 0.6)
                    .fill(.white.opacity(0.28))
                    .widgetAccentable()
                content().foregroundStyle(.white)
            }
        }
    }
}

private struct FreshnessLabel: View {
    var snapshot: Snapshot
    var now: Date

    var body: some View {
        if snapshot.isStale(at: now) {
            Label(Format.dayMonthHour(snapshot.live.observedAt), systemImage: "exclamationmark.triangle.fill")
        } else {
            Text(Format.hour(snapshot.live.observedAt))
        }
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
        let trend = Trend(change: snapshot.live.trend24hHm3)
        WidgetWater(percent: snapshot.live.percent) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(snapshot.reservoir.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    FreshnessLabel(snapshot: snapshot, now: now)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Text(Format.percent(snapshot.live.percent))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                HStack(spacing: 4) {
                    Image(systemName: trend.symbol)
                        .accessibilityLabel(trend.label)
                    Text(Format.hm3(snapshot.live.volumeHm3))
                }
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
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
        HStack(spacing: 0) {
            SmallWidgetView(snapshot: snapshot, now: now)
                .frame(width: 150)
            VStack(alignment: .leading, spacing: 8) {
                VolumeChart(points: snapshot.last7Days)
                    .frame(maxHeight: .infinity)
                WeeklyLine(weekly: snapshot.weekly)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SmallWidgetView(snapshot: snapshot, now: now)
                    .frame(width: 170)
                VStack(alignment: .leading, spacing: 10) {
                    WidgetStat(title: "Boletín semanal", value: Format.hm3(snapshot.weekly.volumeHm3, decimals: 0))
                    WidgetStat(title: "Hace un año", value: snapshot.weekly.lastYearHm3.map { Format.hm3($0, decimals: 0) } ?? "Sin dato")
                    WidgetStat(title: "Caudal al río", value: Format.optional(snapshot.live.outflowM3s, unit: "m³/s"))
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 170)
            VStack(alignment: .leading, spacing: 6) {
                Text("Últimos 90 días")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VolumeChart(points: snapshot.daily)
                    .frame(maxHeight: .infinity)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct WeeklyLine: View {
    var weekly: Snapshot.Weekly

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Boletín semanal")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(Format.hm3(weekly.volumeHm3, decimals: 0))
                    .font(.footnote.weight(.semibold))
                if let lastYear = weekly.lastYearHm3 {
                    Text("\(Format.signed(weekly.volumeHm3 - lastYear, decimals: 0)) vs. 1 año")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}

struct VolumeChart: View {
    var points: [Snapshot.DailyPoint]

    var body: some View {
        let values = points.map(\.volumeHm3)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let margin = max((high - low) * 0.2, 0.5)
        Chart(points) { point in
            AreaMark(
                x: .value("Día", point.day),
                yStart: .value("Base", low - margin),
                yEnd: .value("Volumen", point.volumeHm3)
            )
            .foregroundStyle(LinearGradient(colors: [Palette.waterTop.opacity(0.35), Palette.waterTop.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Día", point.day), y: .value("Volumen", point.volumeHm3))
                .foregroundStyle(Palette.waterTop)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
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
                            .font(.caption2)
                    }
                }
            }
        }
        .accessibilityLabel("Evolución del volumen")
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
        VStack(alignment: .leading, spacing: 2) {
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
