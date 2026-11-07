import SwiftUI
import XCTest
@testable import EmbalseKit

/// Renders the 2.0 design directions to `build/design/<direction>/<format>-<mode>.png` with `make design`, so they can
/// be compared and reviewed before any of them is built. These are prototypes, not app code: they draw from the shared
/// fixture, and approximate Liquid Glass with translucent fills because `ImageRenderer` cannot draw real glass.
@MainActor
final class DesignPrototypeTests: XCTestCase {
    private let output = Fixture.root.appending(path: "build/design")

    private struct Format2 {
        let name: String
        let size: CGSize
        let corner: CGFloat
        let scale: CGFloat
    }

    // Point sizes of the devices the audits reviewed.
    private let iphone = Format2(name: "iphone", size: CGSize(width: 402, height: 874), corner: 54, scale: 3)
    private let ipad = Format2(name: "ipad-landscape", size: CGSize(width: 1376, height: 1032), corner: 18, scale: 2)
    private let duo = Format2(name: "duo-inner", size: CGSize(width: 951, height: 669), corner: 40, scale: 2)
    private let watch = Format2(name: "watch", size: CGSize(width: 205, height: 251), corner: 52, scale: 2)
    private let small = Format2(name: "widget-small", size: CGSize(width: 170, height: 170), corner: 22, scale: 3)
    private let medium = Format2(name: "widget-medium", size: CGSize(width: 364, height: 170), corner: 22, scale: 3)
    private let large = Format2(name: "widget-large", size: CGSize(width: 364, height: 382), corner: 22, scale: 3)

    private func render(_ direction: String, _ format: Format2, _ scheme: ColorScheme, @ViewBuilder _ content: () -> some View) throws {
        let folder = output.appending(path: direction)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let view = content()
            .frame(width: format.size.width, height: format.size.height)
            .clipShape(RoundedRectangle(cornerRadius: format.corner, style: .continuous))
            .padding(10)
            .background(Color(white: scheme == .dark ? 0.12 : 0.88))
            .environment(\.colorScheme, scheme)
            .environment(\.locale, Locale(identifier: "es_ES"))
        let renderer = ImageRenderer(content: view)
        renderer.scale = format.scale
        let image = try XCTUnwrap(renderer.uiImage)
        try XCTUnwrap(image.pngData()).write(to: folder.appending(path: "\(format.name)-\(scheme == .dark ? "dark" : "light").png"))
    }

    private func demo() throws -> Demo { Demo(try Fixture.snapshot()) }

    func testSurface() throws {
        let d = try demo()
        for scheme in [ColorScheme.light, .dark] {
            try render("A-superficie", iphone, scheme) { SurfacePhone(d: d) }
            try render("A-superficie", ipad, scheme) { SurfaceWide(d: d, fold: false) }
        }
        try render("A-superficie", duo, .light) { SurfaceWide(d: d, fold: true) }
        try render("A-superficie", watch, .dark) { SurfaceWatch(d: d) }
        try render("A-superficie", small, .light) { SurfaceWidget(d: d, family: .small) }
        try render("A-superficie", medium, .light) { SurfaceWidget(d: d, family: .medium) }
        try render("A-superficie", large, .light) { SurfaceWidget(d: d, family: .large) }
    }

    func testVessel() throws {
        let d = try demo()
        for scheme in [ColorScheme.light, .dark] {
            try render("B-vaso", iphone, scheme) { VesselPhone(d: d) }
            try render("B-vaso", ipad, scheme) { VesselWide(d: d, fold: false) }
        }
        try render("B-vaso", duo, .light) { VesselWide(d: d, fold: true) }
        try render("B-vaso", watch, .dark) { VesselWatch(d: d) }
        try render("B-vaso", small, .light) { VesselWidget(d: d, family: .small) }
        try render("B-vaso", medium, .light) { VesselWidget(d: d, family: .medium) }
        try render("B-vaso", large, .light) { VesselWidget(d: d, family: .large) }
    }

    func testHorizon() throws {
        let d = try demo()
        for scheme in [ColorScheme.light, .dark] {
            try render("C-horizonte", iphone, scheme) { HorizonPhone(d: d) }
            try render("C-horizonte", ipad, scheme) { HorizonWide(d: d, fold: false) }
        }
        try render("C-horizonte", duo, .light) { HorizonWide(d: d, fold: true) }
        try render("C-horizonte", watch, .dark) { HorizonWatch(d: d) }
        try render("C-horizonte", small, .light) { HorizonWidget(d: d, family: .small) }
        try render("C-horizonte", medium, .light) { HorizonWidget(d: d, family: .medium) }
        try render("C-horizonte", large, .light) { HorizonWidget(d: d, family: .large) }
    }
}

// MARK: - Data and shared pieces

private enum Family { case small, medium, large }

/// The figures every direction shows, with the 2.0 number style the audits ask for: a no-break space before each unit,
/// SAIH volume with 1 decimal, MITECO with 0, the percentage with 1.
private struct Demo {
    let percent: Double
    let volume: Double
    let capacity: Double
    let trend: Double
    let observed: Date
    let weekly: Snapshot.Weekly
    let neighbours: [(name: String, percent: Double, volume: Double)]
    /// 90 days of SAIH volume, oldest first, ending at today's value.
    let daily: [Double]
    /// MITECO weekly volume this year so far, last year, and the 10-year average, by week of the year.
    let thisYear: [Double]
    let lastYear: [Double]
    let average: [Double]

    init(_ s: Snapshot) {
        percent = s.live.percent
        volume = s.live.volumeHm3
        capacity = s.weekly.capacityHm3
        trend = s.live.trend24hHm3
        observed = s.live.observedAt
        weekly = s.weekly
        let upstream = s.neighbours.filter { $0.position == .upstream }.map { ($0.name, $0.percent, $0.volumeHm3) }
        let downstream = s.neighbours.filter { $0.position == .downstream }.map { ($0.name, $0.percent, $0.volumeHm3) }
        neighbours = upstream + [(s.reservoir.name, s.live.percent, s.live.volumeHm3)] + downstream
        // The fixture spans two days, so the prototypes get believable curves that end at today's real figures.
        let today = s.live.volumeHm3
        daily = (0..<90).map { i in today + Double(89 - i) * 0.19 + sin(Double(i) / 6) * 0.8 - sin(89.0 / 6) * 0.8 }
        let week = 44
        func curve(_ base: Double, _ swing: Double, _ shift: Double) -> [Double] {
            (0..<52).map { w in base + swing * cos((Double(w) - 14 + shift) / 52 * 2 * .pi) }
        }
        lastYear = curve(98, 24, 0)
        average = curve(84, 22, 2)
        let raw = curve(92, 26, -1)
        let offset = s.weekly.volumeHm3 - raw[week]
        thisYear = Array(raw.prefix(week + 1)).map { $0 + offset * 0.4 }.enumerated().map { $0.offset == week ? s.weekly.volumeHm3 : $0.element }
    }

    var percentText: String { "\(Format.number(percent, decimals: 1))\u{00A0}%" }
    var volumeText: String { "\(Format.number(volume, decimals: 1))\u{00A0}hm³ de \(Format.number(capacity, decimals: 0))\u{00A0}hm³" }
    var trendWord: String { abs(trend) < 0.2 ? "Estable" : trend > 0 ? "Subiendo" : "Bajando" }
    var trendSymbol: String { abs(trend) < 0.2 ? "arrow.right" : trend > 0 ? "arrow.up.right" : "arrow.down.right" }
    var trendText: String { "\(trendWord) · \(Format.signed(trend, decimals: 2))\u{00A0}hm³ en 24\u{00A0}h" }
    var sourceText: String { "SAIH Tajo · \(Format.dayMonthHour(observed))" }
    var weekText: String { "MITECO · semana del \(Format.dayMonth(weekly.day))" }
    func hm3(_ value: Double, decimals: Int = 0) -> String { "\(Format.number(value, decimals: decimals))\u{00A0}hm³" }
}

/// One figure style everywhere: SF Rounded, tabular digits.
private extension View {
    func figure(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> some View {
        font(.system(size: size, weight: weight, design: .rounded)).monospacedDigit()
    }
}

/// Liquid Glass, approximated: `ImageRenderer` can't draw real glass, so a translucent fill with a hairline edge.
private struct Glass: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var corner: CGFloat = 26
    var onWater = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(onWater ? Color.white.opacity(scheme == .dark ? 0.12 : 0.18)
                                  : (scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.72)))
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(onWater ? 0.35 : (scheme == .dark ? 0.14 : 0.9)), lineWidth: 1)
            }
            .shadow(color: .black.opacity(onWater ? 0 : 0.08), radius: 12, y: 6)
    }
}

private extension View {
    func glass(corner: CGFloat = 26, onWater: Bool = false) -> some View { modifier(Glass(corner: corner, onWater: onWater)) }
}

/// The palette follows how full the reservoir is: deep blue when full, a lighter teal when low. Text on it is always
/// white, and stays above 4.5:1 at every level.
private func water(_ percent: Double) -> LinearGradient {
    let t = min(max(percent / 100, 0), 1)
    let top = Color(red: 0.10 + (1 - t) * 0.06, green: 0.50 + (1 - t) * 0.12, blue: 0.86 - (1 - t) * 0.16)
    let bottom = Color(red: 0.02, green: 0.20 + (1 - t) * 0.10, blue: 0.52 - (1 - t) * 0.10)
    return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
}

private struct Sky: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View { Rectangle().fill(Palette.sky(scheme)) }
}

/// Two layers of water whose surface follows `surface`, values from 0 (empty) to 1 (full) across the width.
private struct SurfaceShape: Shape {
    var surface: [Double]
    var wave: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let count = max(surface.count, 2)
        for x in stride(from: rect.minX, through: rect.maxX, by: 2) {
            let f = Double((x - rect.minX) / rect.width) * Double(count - 1)
            let i = min(Int(f), count - 2)
            let level = surface.count < 2 ? surface.first ?? 0 : surface[i] + (surface[i + 1] - surface[i]) * (f - Double(i))
            let y = rect.maxY - rect.height * level + sin(x / 60) * wave
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Water: View {
    var surface: [Double]
    var percent: Double
    var wave: CGFloat = 5
    var body: some View {
        ZStack {
            SurfaceShape(surface: surface.map { $0 + 0.012 }, wave: wave * 0.8).fill(Palette.waterBack.opacity(0.45)).offset(x: -30)
            SurfaceShape(surface: surface, wave: wave).fill(water(percent))
        }
    }
}

private struct Sparkline: View {
    var values: [Double]
    var range: ClosedRange<Double>
    var color: Color = .white
    var width: CGFloat = 2
    var dashed = false

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for (i, v) in values.enumerated() {
                    let x = proxy.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                    let y = proxy.size.height * (1 - CGFloat((v - range.lowerBound) / (range.upperBound - range.lowerBound)))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dashed ? [4, 4] : []))
        }
    }
}

/// "Este año": this year, last year and the 10-year average, one MITECO series per line. 52 weeks share the width, so
/// this year's line stops at today.
private struct YearChart: View {
    let d: Demo
    var onWater = false
    var body: some View {
        let range = 0.0...d.capacity
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                Sparkline(values: d.average, range: range, color: onWater ? .white.opacity(0.55) : .secondary.opacity(0.6), width: 1.5, dashed: true)
                Sparkline(values: d.lastYear, range: range, color: onWater ? .white.opacity(0.7) : Color.orange.opacity(0.85), width: 2)
                GeometryReader { proxy in
                    Sparkline(values: d.thisYear, range: range, color: onWater ? .white : Palette.waterTop, width: 3)
                        .frame(width: proxy.size.width * CGFloat(d.thisYear.count - 1) / 51)
                }
            }
            HStack(spacing: 12) {
                Label("Este año", systemImage: "circle.fill").foregroundStyle(onWater ? .white : Palette.waterTop)
                Label("Año pasado", systemImage: "circle.fill").foregroundStyle(onWater ? .white.opacity(0.75) : .orange)
                Label("Media 10 años", systemImage: "circle.dotted").foregroundStyle(onWater ? .white.opacity(0.6) : .secondary)
            }
            .labelStyle(.titleAndIcon).font(.caption2.weight(.medium)).imageScale(.small)
        }
    }
}

private struct SectionTabs: View {
    var selected = 0
    var onWater = true
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(["Ahora", "Este año", "El río"].enumerated()), id: \.offset) { index, title in
                Text(title)
                    .font(.subheadline.weight(index == selected ? .semibold : .regular))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background { if index == selected { Capsule().fill(Color.white.opacity(onWater ? 0.28 : 0.9)) } }
            }
        }
        .foregroundStyle(onWater ? .white : .primary)
        .padding(5)
        .glass(corner: 30, onWater: onWater)
    }
}

private struct Fold: View {
    var body: some View {
        Rectangle().fill(Color.red.opacity(0.55)).frame(width: 1.5)
            .overlay(alignment: .top) { Text("pliegue").font(.caption2).foregroundStyle(.red).padding(.top, 4).fixedSize() }
    }
}

// MARK: - A · Superficie: the screen is the reservoir

private struct SurfacePhone: View {
    let d: Demo
    var body: some View {
        GeometryReader { proxy in
            let waterline = proxy.size.height * (1 - d.percent / 100)
            ZStack(alignment: .top) {
                Sky()
                Water(surface: [d.percent / 100], percent: d.percent, wave: 6)
                // Above the water: what this is and where the figure comes from.
                VStack(alignment: .leading, spacing: 6) {
                    Text("San Juan").font(.largeTitle.bold())
                    Text("Río Alberche · Madrid").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Label(d.sourceText, systemImage: "clock").font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24).padding(.top, 70)
                .frame(maxWidth: .infinity, maxHeight: waterline - 22, alignment: .topLeading)
                // In the water, clear of the crest: the number, its volume and its trend, all white.
                VStack(alignment: .leading, spacing: 6) {
                    Text(d.percentText).figure(92).foregroundStyle(.white).minimumScaleFactor(0.6)
                    Text(d.volumeText).font(.title3.weight(.semibold)).foregroundStyle(.white)
                    Label(d.trendText, systemImage: d.trendSymbol).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hace un año").font(.caption).foregroundStyle(.white.opacity(0.8))
                            Text(d.hm3(d.weekly.lastYearHm3 ?? 0)).figure(20).foregroundStyle(.white)
                        }
                        Divider().frame(height: 30).overlay(Color.white.opacity(0.4))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Media 10 años").font(.caption).foregroundStyle(.white.opacity(0.8))
                            Text(d.hm3(d.weekly.tenYearAvgHm3 ?? 0, decimals: 1)).figure(20).foregroundStyle(.white)
                        }
                        Spacer()
                        Text("MITECO\nsemanal").font(.caption2.weight(.semibold)).multilineTextAlignment(.trailing).foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(16).glass(corner: 22, onWater: true)
                    SectionTabs().frame(maxWidth: .infinity).padding(.top, 14)
                }
                .padding(.horizontal, 24).padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, waterline + 26)
            }
        }
    }
}

private struct SurfaceWide: View {
    let d: Demo
    var fold: Bool
    var body: some View {
        GeometryReader { proxy in
            let waterline = proxy.size.height * (1 - d.percent / 100)
            ZStack(alignment: .topLeading) {
                Sky()
                Water(surface: [d.percent / 100], percent: d.percent, wave: 7)
                HStack(alignment: .top, spacing: fold ? 60 : 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("San Juan").font(.largeTitle.bold())
                        Label(d.sourceText, systemImage: "clock").font(.subheadline).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text(d.percentText).figure(fold ? 96 : 130).foregroundStyle(.white).padding(.top, 44)
                        Text(d.volumeText).font(.title2.weight(.semibold)).foregroundStyle(.white)
                        Label(d.trendText, systemImage: d.trendSymbol).font(.headline).foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                    .frame(width: proxy.size.width * 0.5 - (fold ? 60 : 48), alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 0)
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Este año").font(.headline).foregroundStyle(.white)
                            YearChart(d: d, onWater: true).frame(height: 150)
                            Text(d.weekText).font(.caption).foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(18).glass(corner: 24, onWater: true)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("El río").font(.headline).foregroundStyle(.white)
                            ForEach(d.neighbours, id: \.name) { n in
                                HStack {
                                    Text(n.name).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Format.number(n.percent, decimals: 1))\u{00A0}%").figure(17).foregroundStyle(.white)
                                }
                            }
                            Text(d.sourceText).font(.caption).foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(18).glass(corner: 24, onWater: true)
                    }
                    .padding(.top, waterline + 24)
                }
                .padding(.horizontal, 40).padding(.top, 36)
                if fold { HStack { Spacer(); Fold(); Spacer() } }
            }
        }
    }
}

private struct SurfaceWatch: View {
    let d: Demo
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            Water(surface: [d.percent / 100], percent: d.percent, wave: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("San Juan").font(.headline).foregroundStyle(.white)
                Text("SAIH · 16:00").font(.caption2).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(d.percentText).figure(44).foregroundStyle(.white)
                Label(d.trendWord, systemImage: d.trendSymbol).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .padding(14).padding(.bottom, 8)
        }
    }
}

private struct SurfaceWidget: View {
    let d: Demo
    let family: Family
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.06, green: 0.18, blue: 0.40), Color(red: 0.08, green: 0.24, blue: 0.50)], startPoint: .top, endPoint: .bottom)
            Water(surface: [d.percent / 100], percent: d.percent, wave: 3)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("San Juan").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("16:00").font(.caption).foregroundStyle(.white.opacity(0.75))
                }
                if family == .large {
                    Sparkline(values: d.daily, range: (d.daily.min()! - 4)...(d.daily.max()! + 4)).frame(height: 90).padding(.top, 12)
                    Text("Últimos 90 días · SAIH").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text(d.percentText).figure(family == .small ? 36 : 44).minimumScaleFactor(0.7)
                Label(family == .small ? Format.signed(d.trend, decimals: 2) + "\u{00A0}hm³" : d.trendText, systemImage: d.trendSymbol)
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .foregroundStyle(.white)
            .padding(16)
        }
    }
}

// MARK: - B · Vaso: a calm page with a glass tank that holds the comparisons

private struct Tank: View {
    let d: Demo
    var compact = false
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: compact ? 20 : 34, style: .continuous).fill(Palette.sky(scheme))
                Water(surface: [d.percent / 100], percent: d.percent, wave: compact ? 2.5 : 4)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 20 : 34, style: .continuous))
                // Markers on the glass: last year and the 10-year average, both MITECO, for the same week.
                ForEach([(d.weekly.lastYearHm3 ?? 0, "Hace un año"), (d.weekly.tenYearAvgHm3 ?? 0, "Media 10 años")], id: \.1) { value, title in
                    let y = h * (1 - value / d.capacity)
                    HStack(spacing: 6) {
                        Rectangle().fill(.primary.opacity(0.55)).frame(width: compact ? 10 : 18, height: 2)
                        if !compact {
                            Text("\(title) · \(d.hm3(value, decimals: value.rounded() == value ? 0 : 1))")
                                .font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(.background.opacity(0.85)))
                        }
                    }
                    .offset(y: y - h + 1)
                }
                RoundedRectangle(cornerRadius: compact ? 20 : 34, style: .continuous)
                    .strokeBorder(.primary.opacity(0.15), lineWidth: compact ? 1 : 1.5)
            }
        }
    }
}

private struct VesselPhone: View {
    let d: Demo
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(scheme == .dark ? Color.black : Color(red: 0.95, green: 0.96, blue: 0.98))
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("San Juan").font(.largeTitle.bold())
                    Text("Río Alberche · Madrid").font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(d.percentText).figure(76)
                    Spacer()
                    Label(d.trendWord, systemImage: d.trendSymbol).font(.headline).foregroundStyle(Palette.waterTop)
                }
                Text("\(d.volumeText) · \(Format.signed(d.trend, decimals: 2))\u{00A0}hm³ en 24\u{00A0}h").font(.subheadline).foregroundStyle(.secondary)
                Tank(d: d).frame(height: 330)
                Label(d.sourceText, systemImage: "clock").font(.footnote).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Este año").font(.headline); Spacer(); Text("MITECO").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                    YearChart(d: d).frame(height: 96)
                }
                .padding(16).glass(corner: 22)
                Spacer()
            }
            .padding(.horizontal, 22).padding(.top, 64)
        }
    }
}

private struct VesselWide: View {
    let d: Demo
    var fold: Bool
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            Rectangle().fill(scheme == .dark ? Color.black : Color(red: 0.95, green: 0.96, blue: 0.98))
            HStack(alignment: .top, spacing: fold ? 60 : 36) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("San Juan").font(.largeTitle.bold())
                    HStack(alignment: .firstTextBaseline) {
                        Text(d.percentText).figure(fold ? 70 : 96)
                        Spacer()
                        Label(d.trendWord, systemImage: d.trendSymbol).font(.title3.weight(.semibold)).foregroundStyle(Palette.waterTop)
                    }
                    Text(d.volumeText).font(.title3).foregroundStyle(.secondary)
                    Tank(d: d)
                    Label(d.sourceText, systemImage: "clock").font(.footnote).foregroundStyle(.secondary)
                }
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Este año").font(.headline); Spacer(); Text(d.weekText).font(.caption).foregroundStyle(.secondary) }
                        YearChart(d: d).frame(height: 170)
                    }
                    .padding(18).glass(corner: 24)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("El río").font(.headline)
                        HStack(alignment: .bottom, spacing: 14) {
                            ForEach(d.neighbours, id: \.name) { n in
                                VStack(spacing: 6) {
                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.sky(scheme))
                                        Water(surface: [n.percent / 100], percent: n.percent, wave: 2)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .frame(height: fold ? 70 : 110)
                                    Text(n.name).font(.subheadline.weight(.semibold))
                                    Text("\(Format.number(n.percent, decimals: 1))\u{00A0}%").figure(15).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(18).glass(corner: 24)
                }
            }
            .padding(.horizontal, 40).padding(.vertical, 36)
            if fold { HStack { Spacer(); Fold(); Spacer() } }
        }
    }
}

private struct VesselWatch: View {
    let d: Demo
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 6) {
                Text("San Juan").font(.headline).foregroundStyle(.white)
                Tank(d: d, compact: true).frame(width: 110, height: 120).environment(\.colorScheme, .dark)
                Text(d.percentText).figure(30).foregroundStyle(.white)
                Label(d.trendWord, systemImage: d.trendSymbol).font(.caption2.weight(.semibold)).foregroundStyle(Palette.waterBack)
            }
            .padding(10)
        }
    }
}

private struct VesselWidget: View {
    let d: Demo
    let family: Family
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("San Juan").font(.subheadline.weight(.semibold))
                Spacer()
                Text(d.percentText).figure(family == .small ? 30 : 38).minimumScaleFactor(0.7)
                Label(d.trendWord, systemImage: d.trendSymbol).font(.caption.weight(.semibold)).foregroundStyle(Palette.waterTop)
                if family != .small { Text("SAIH · 16:00").font(.caption2).foregroundStyle(.secondary) }
            }
            if family == .small {
                Tank(d: d, compact: true).frame(width: 34)
            } else {
                Tank(d: d, compact: family == .medium).frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(red: 0.96, green: 0.97, blue: 0.99))
    }
}

// MARK: - C · Horizonte: the water's surface is the last 90 days

private struct HorizonPhone: View {
    let d: Demo
    var body: some View {
        GeometryReader { proxy in
            let surface = d.daily.map { $0 / d.capacity }
            let waterlineToday = proxy.size.height * (1 - d.percent / 100)
            let highest = proxy.size.height * (1 - (surface.max() ?? 0))
            ZStack(alignment: .topLeading) {
                Sky()
                Water(surface: surface, percent: d.percent, wave: 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text("San Juan").font(.title2.bold())
                    Label(d.sourceText, systemImage: "clock").font(.footnote).foregroundStyle(.secondary)
                    Text(d.percentText).figure(86).padding(.top, 18)
                    Text(d.volumeText).font(.title3.weight(.semibold))
                    Label(d.trendText, systemImage: d.trendSymbol).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24).padding(.top, 66)
                .frame(maxHeight: highest - 16, alignment: .top)
                // The curve's two ends, named where they are.
                Text("hace 90 días · \(d.hm3(d.daily.first!, decimals: 1))").font(.caption.weight(.semibold)).foregroundStyle(.white)
                    .padding(.leading, 14).padding(.top, proxy.size.height * (1 - surface.first!) + 26)
                Text("hoy").font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 14).padding(.top, waterlineToday + 26)
                VStack(spacing: 12) {
                    Spacer()
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hace un año").font(.caption).foregroundStyle(.white.opacity(0.8))
                            Text(d.hm3(d.weekly.lastYearHm3 ?? 0)).figure(22).foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14).glass(corner: 20, onWater: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Media 10 años").font(.caption).foregroundStyle(.white.opacity(0.8))
                            Text(d.hm3(d.weekly.tenYearAvgHm3 ?? 0, decimals: 1)).figure(22).foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14).glass(corner: 20, onWater: true)
                    }
                    Text(d.weekText).font(.caption).foregroundStyle(.white.opacity(0.75))
                    SectionTabs().padding(.top, 6)
                }
                .padding(.horizontal, 22).padding(.bottom, 34)
            }
        }
    }
}

private struct HorizonWide: View {
    let d: Demo
    var fold: Bool
    var body: some View {
        GeometryReader { proxy in
            let surface = d.daily.map { $0 / d.capacity }
            let highest = proxy.size.height * (1 - (surface.max() ?? 0))
            ZStack(alignment: .topLeading) {
                Sky()
                Water(surface: surface, percent: d.percent, wave: 0)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("San Juan").font(.largeTitle.bold())
                        Label(d.sourceText, systemImage: "clock").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(d.percentText).figure(fold ? 80 : 112)
                        Text(d.volumeText).font(.title3.weight(.semibold))
                        Label(d.trendText, systemImage: d.trendSymbol).font(.headline).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 40).padding(.top, 34)
                .frame(maxHeight: highest - 16, alignment: .top)
                HStack(alignment: .bottom, spacing: fold ? 60 : 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Este año").font(.headline)
                        YearChart(d: d, onWater: true).frame(height: 130)
                        Text(d.weekText).font(.caption).opacity(0.75)
                    }
                    .padding(18).glass(corner: 24, onWater: true)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("El río").font(.headline)
                        ForEach(d.neighbours, id: \.name) { n in
                            HStack { Text(n.name); Spacer(); Text("\(Format.number(n.percent, decimals: 1))\u{00A0}%").figure(17) }
                        }
                        Text(d.sourceText).font(.caption).opacity(0.75)
                    }
                    .padding(18).glass(corner: 24, onWater: true)
                }
                .foregroundStyle(.white)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                if fold { HStack { Spacer(); Fold(); Spacer() } }
            }
        }
    }
}

private struct HorizonWatch: View {
    let d: Demo
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            Water(surface: d.daily.map { $0 / d.capacity }, percent: d.percent, wave: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text("San Juan").font(.headline)
                Text(d.percentText).figure(40)
                Label(d.trendWord, systemImage: d.trendSymbol).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("90 días").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            .padding(14)
        }
    }
}

private struct HorizonWidget: View {
    let d: Demo
    let family: Family
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.06, green: 0.18, blue: 0.40), Color(red: 0.08, green: 0.24, blue: 0.50)], startPoint: .top, endPoint: .bottom)
            Water(surface: (family == .small ? d.daily.suffix(30) : d.daily[...]).map { $0 / d.capacity }, percent: d.percent, wave: 0)
            VStack(alignment: .leading, spacing: 2) {
                HStack { Text("San Juan").font(.subheadline.weight(.semibold)); Spacer(); Text("16:00").font(.caption).opacity(0.75) }
                Text(d.percentText).figure(family == .small ? 32 : 40).minimumScaleFactor(0.7)
                Label(family == .small ? d.trendWord : d.trendText, systemImage: d.trendSymbol).font(.caption.weight(.semibold)).opacity(0.9)
                Spacer()
                if family != .small {
                    HStack {
                        Text("hace \(family == .large ? 90 : 90) días")
                        Spacer()
                        Text("hoy")
                    }
                    .font(.caption2.weight(.semibold)).opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
        }
    }
}
