import SwiftUI

/// The water card (docs/design/review-2.0/SYNTHESIS.md): the app's signature. It opens on today's level with moving
/// water. "Año" turns the same surface into the last 12 months of SAIH volume on a fixed 0-to-capacity scale, with last
/// year and the range of the four years before behind it. The figure block goes wholly in the water or wholly in the
/// sky, never across the waterline.
public struct WaterCard: View {
    public enum Mode: String, Hashable, Sendable, CaseIterable { case today, year }

    var reading: ReservoirReading
    var capacityHm3: Double
    var trendHm3: Double?
    var surface: YearSurface?
    @Binding var mode: Mode
    var figureSize: CGFloat
    var tilt: Double
    var animated: Bool
    var cornerRadius: CGFloat

    public init(reading: ReservoirReading, capacityHm3: Double, trendHm3: Double?, surface: YearSurface?,
                mode: Binding<Mode>, figureSize: CGFloat = 72, tilt: Double = 0, animated: Bool = true, cornerRadius: CGFloat = 30) {
        self.reading = reading
        self.capacityHm3 = capacityHm3
        self.trendHm3 = trendHm3
        self.surface = surface
        self._mode = mode
        self.figureSize = figureSize
        self.tilt = tilt
        self.animated = animated
        self.cornerRadius = cornerRadius
    }

    @State private var blockSize: CGSize = CGSize(width: 260, height: 180)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Room at the top for the switch and the legend; 100 % sits just below it, the same in both views.
    static let topPad: CGFloat = 58
    static let amplitude: CGFloat = 6

    private var showsYear: Bool { mode == .year && surface != nil }
    private var level: Double { min(max(reading.percent / 100, 0), 1) }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Palette.sky(scheme))
                if showsYear, let surface { YearExtras(surface: surface, topPad: Self.topPad).transition(.opacity) }
                water(size: size)
                if showsYear, let surface {
                    YearMarks(surface: surface, topPad: Self.topPad, avoidWidth: blockSize.width + 24)
                        .transition(.opacity)
                }
                figure(size: size)
                controls
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: Water

    @ViewBuilder
    private func water(size: CGSize) -> some View {
        let crest = surface?.levels ?? []
        let still = !animated || reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let phase = still ? 0.6 : WaterScene<EmptyView, EmptyView>.phase(at: context.date)
            ZStack {
                CardWater(level: level, crest: crest, progress: showsYear ? 1 : 0, phase: phase + 2.1,
                          amplitude: Self.amplitude * 0.8, topPad: Self.topPad, offset: -3)
                    .fill(Palette.waterCrest)
                    .opacity(showsYear ? 0 : 1)
                CardWater(level: level, crest: crest, progress: showsYear ? 1 : 0, phase: phase,
                          amplitude: Self.amplitude, topPad: Self.topPad)
                    .fill(Palette.water(reading.percent))
                CardWater(level: level, crest: crest, progress: showsYear ? 1 : 0, phase: phase,
                          amplitude: Self.amplitude, topPad: Self.topPad, strokeOnly: true)
                    .stroke(Palette.crestLine, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            .rotationEffect(.radians(showsYear || reduceMotion ? 0 : tilt))
            .scaleEffect(showsYear || tilt == 0 ? 1 : 1.12)
        }
        .accessibilityHidden(true)
    }

    // MARK: Figure

    /// The shallowest water under the block: today's level, or in the year view the lowest point of the surface
    /// under the block's width.
    private func waterUnderBlock(width: CGFloat) -> Double {
        guard showsYear, let surface, !surface.levels.isEmpty, width > 0 else { return level }
        let share = min(max((blockSize.width + 24) / width, 0), 1)
        let count = max(Int((Double(surface.levels.count - 1) * share).rounded(.up)), 1)
        return min(surface.levels.prefix(count + 1).min() ?? level, 1)
    }

    @ViewBuilder
    private func figure(size: CGSize) -> some View {
        let usable = size.height - Self.topPad
        let placement = FigurePlacement.decide(height: usable, percent: waterUnderBlock(width: size.width) * 100,
                                               amplitude: Self.amplitude, block: blockSize.height, bottomInset: 14)
        let block = FigureBlock(reading: reading, capacityHm3: capacityHm3, trendHm3: trendHm3,
                                onWater: placement.isOnWater, figureSize: showsYear ? figureSize * 0.7 : figureSize,
                                compact: showsYear)
            .padding(.horizontal, 20)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { blockSize = $0 }
            .frame(maxWidth: size.width, alignment: .leading)
        Group {
            switch placement {
            case .water(let top):
                block.padding(.top, Self.topPad + top)
            case .sky(let bottom):
                block.frame(height: Self.topPad + bottom, alignment: .bottomLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth, value: placement)
    }

    // MARK: Switch and legend

    @ViewBuilder private var controls: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsYear {
                YearLegend().transition(.opacity)
            }
            Spacer(minLength: 0)
            #if os(iOS)
            if surface != nil {
                Picker(selection: Binding(get: { mode }, set: { new in withAnimation(.smooth(duration: 0.9)) { mode = new } })) {
                    Text("Hoy", bundle: .module).tag(Mode.today)
                    Text("Año", bundle: .module).tag(Mode.year)
                } label: {
                    Text("Vista del agua", bundle: .module)
                }
                .pickerStyle(.segmented)
                .frame(width: typeSize.isAccessibilitySize ? 170 : 128)
                .accessibilityHint(Text("Cambia entre el nivel de hoy y los últimos 12 meses", bundle: .module))
            }
            #endif
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }
}

public extension Palette {
    /// The bright line along the surface.
    static let crestLine = Color(red: 0.56, green: 0.82, blue: 1.0)
    /// Last year, in both the card and the widgets.
    static let lastYear = Color(red: 0.80, green: 0.60, blue: 0.30)

    /// The range of past years, drawn in the sky.
    static func band(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.49, green: 0.76, blue: 0.96).opacity(0.18) : Color(red: 0.04, green: 0.29, blue: 0.48).opacity(0.12)
    }
}

/// The water's top edge: a wave at `level` that morphs into `crest` as `progress` goes from 0 to 1.
struct CardWater: Shape {
    var level: Double
    var crest: [Double]
    var progress: Double
    var phase: Double
    var amplitude: CGFloat
    var topPad: CGFloat
    var offset: CGFloat = 0
    var strokeOnly = false

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, phase) }
        set { progress = newValue.first; phase = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let usable = rect.height - topPad
        let y = { (fraction: Double) in rect.minY + topPad + usable * (1 - min(max(fraction, 0), 1.02)) }
        let eased = progress * progress * (3 - 2 * progress)
        let samples = 96
        var points: [CGPoint] = []
        for index in 0..<samples {
            let u = Double(index) / Double(samples - 1)
            let x = rect.minX + rect.width * u
            let wave = y(level) + offset + amplitude * sin(u * .pi * 2 * 1.2 + phase) + amplitude * 0.45 * sin(u * .pi * 2 * 2.6 - phase * 1.3)
            var target = wave
            if crest.count > 1 {
                let position = u * Double(crest.count - 1)
                let lower = Int(position.rounded(.down))
                let upper = min(lower + 1, crest.count - 1)
                let fraction = position - Double(lower)
                target = y(crest[lower] + (crest[upper] - crest[lower]) * fraction)
            }
            points.append(CGPoint(x: x, y: wave + (target - wave) * eased))
        }
        var path = Path()
        path.addLines(points)
        if !strokeOnly {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// Behind the water in the year view: the range of the four previous years and the 5-year record.
private struct YearExtras: View {
    var surface: YearSurface
    var topPad: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { context, size in
            let usable = size.height - topPad
            let x = { (index: Int, count: Int) in size.width * CGFloat(index) / CGFloat(max(count - 1, 1)) }
            let y = { (fraction: Double) in topPad + usable * (1 - min(max(fraction, 0), 1.02)) }
            if let band = surface.band, band.count > 1 {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y(band[0].upperBound)))
                for (index, range) in band.enumerated() { path.addLine(to: CGPoint(x: x(index, band.count), y: y(range.upperBound))) }
                for (index, range) in band.enumerated().reversed() { path.addLine(to: CGPoint(x: x(index, band.count), y: y(range.lowerBound))) }
                path.closeSubpath()
                context.fill(path, with: .color(Palette.band(scheme)))
            }
            if let record = surface.record {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y(record)))
                line.addLine(to: CGPoint(x: size.width, y: y(record)))
                context.stroke(line, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Over the water in the year view: last year's line, today's marker and the months, kept clear of the figure block.
private struct YearMarks: View {
    var surface: YearSurface
    var topPad: CGFloat
    var avoidWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let usable = size.height - topPad
            let y = { (fraction: Double) in topPad + usable * (1 - min(max(fraction, 0), 1.02)) }
            let count = surface.levels.count
            let x = { (index: Int) in size.width * CGFloat(index) / CGFloat(max(count - 1, 1)) }
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    if let lastYear = surface.lastYear, lastYear.count > 1 {
                        var path = Path()
                        for (index, value) in lastYear.enumerated() {
                            let point = CGPoint(x: size.width * CGFloat(index) / CGFloat(lastYear.count - 1), y: y(value))
                            index == 0 ? path.move(to: point) : path.addLine(to: point)
                        }
                        context.stroke(path, with: .color(Palette.lastYear), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
                    }
                    let today = CGPoint(x: x(count - 1) - 7, y: y(surface.levels.last ?? 0))
                    var marker = Path()
                    marker.move(to: today)
                    marker.addLine(to: CGPoint(x: today.x, y: size.height))
                    context.stroke(marker, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    context.fill(Path(ellipseIn: CGRect(x: today.x - 5.5, y: today.y - 5.5, width: 11, height: 11)), with: .color(.white))
                    context.stroke(Path(ellipseIn: CGRect(x: today.x - 5.5, y: today.y - 5.5, width: 11, height: 11)), with: .color(Palette.waterTop), lineWidth: 2.5)
                }
                Text(String(localized: "Hoy", bundle: .module).lowercased(with: Format.locale))
                    .font(.caption.weight(.semibold))
                    .position(x: x(count - 1) - 24, y: y(surface.levels.last ?? 0) - 16)
                ForEach(monthStarts, id: \.index) { month in
                    let mx = x(month.index)
                    if mx > avoidWidth, mx < size.width - 30 {
                        Text(month.label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .position(x: mx + 12, y: size.height - 12)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var monthStarts: [(index: Int, label: String)] {
        let calendar = Calendar.current
        var result: [(Int, String)] = []
        var previous = calendar.component(.month, from: surface.date(at: 0))
        for index in 1..<surface.levels.count {
            let date = surface.date(at: index)
            let month = calendar.component(.month, from: date)
            if month != previous, month % 2 == 1 {
                result.append((index, Format.monthShort(date)))
            }
            previous = month
        }
        return result
    }
}

private struct YearLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Últimos 12 meses · SAIH Tajo", bundle: .module).font(.caption.weight(.semibold))
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Capsule().fill(Palette.lastYear).frame(width: 14, height: 2)
                    Text(String(localized: "Hace un año", bundle: .module).lowercased(with: Format.locale))
                }
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.3)).frame(width: 12, height: 9)
                    Text("rango 5 años", bundle: .module)
                }
            }
            .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .fixedSize()
    }
}

/// The card collapsed while scrolling: the figure and the trend on a strip of water.
public struct WaterStrip: View {
    var reading: ReservoirReading
    var trendHm3: Double?

    public init(reading: ReservoirReading, trendHm3: Double?) {
        self.reading = reading
        self.trendHm3 = trendHm3
    }

    public var body: some View {
        HStack(spacing: 14) {
            Text(Format.percent(reading.percent)).figureFont(.title, weight: .bold)
            VStack(alignment: .leading, spacing: 1) {
                if let trendHm3 {
                    Label(Trend.sentence(trendHm3), systemImage: Trend(change: trendHm3).symbol).font(.footnote.weight(.semibold))
                }
                Text(Format.saihSource(reading.observedAt)).font(.caption).opacity(0.8)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.onWater)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Palette.water(reading.percent), in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
