import SwiftUI

public enum Palette {
    public static let waterTop = Color(red: 0.16, green: 0.56, blue: 0.96)
    public static let waterBottom = Color(red: 0.02, green: 0.25, blue: 0.62)
    public static let waterBack = Color(red: 0.36, green: 0.70, blue: 0.99)

    public static func sky(_ scheme: ColorScheme) -> LinearGradient {
        let colors = scheme == .dark
            ? [Color(red: 0.05, green: 0.08, blue: 0.14), Color(red: 0.09, green: 0.14, blue: 0.23)]
            : [Color(red: 0.91, green: 0.96, blue: 1.0), Color(red: 0.97, green: 0.99, blue: 1.0)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

/// The water, or with `invert` the air above it. `level` is the fraction of the height that is full.
public struct WaveShape: Shape {
    public var level: Double
    public var phase: Double
    public var amplitude: CGFloat
    public var invert: Bool

    public init(level: Double, phase: Double = 0, amplitude: CGFloat = 4, invert: Bool = false) {
        self.level = level
        self.phase = phase
        self.amplitude = amplitude
        self.invert = invert
    }

    public var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, phase) }
        set {
            level = newValue.first
            phase = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        let clamped = min(max(level, 0), 1)
        let baseline = rect.maxY - rect.height * clamped
        let wavelength = max(rect.width, 1)
        var path = Path()
        let closingY = invert ? rect.minY : rect.maxY
        path.move(to: CGPoint(x: rect.minX, y: closingY))
        for x in stride(from: rect.minX, through: rect.maxX, by: 2) {
            let angle = (x / wavelength) * 2 * .pi + phase
            path.addLine(to: CGPoint(x: x, y: baseline + sin(angle) * amplitude))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: baseline + sin(2 * .pi + phase) * amplitude))
        path.addLine(to: CGPoint(x: rect.maxX, y: closingY))
        path.closeSubpath()
        return path
    }
}

/// Two layers of water filling their space up to `percent`.
public struct WaterFill: View {
    var percent: Double
    var phase: Double
    var amplitude: CGFloat

    public init(percent: Double, phase: Double = 0.6, amplitude: CGFloat = 4) {
        self.percent = percent
        self.phase = phase
        self.amplitude = amplitude
    }

    public var body: some View {
        ZStack {
            WaveShape(level: percent / 100, phase: phase + 2.1, amplitude: amplitude)
                .fill(Palette.waterBack.opacity(0.5))
            WaveShape(level: percent / 100, phase: phase, amplitude: amplitude)
                .fill(LinearGradient(colors: [Palette.waterTop, Palette.waterBottom], startPoint: .top, endPoint: .bottom))
        }
    }
}

/// Text that stays readable as it crosses the waterline: white in the water, primary above it.
public struct WaterlineText<Content: View>: View {
    var percent: Double
    var phase: Double
    var amplitude: CGFloat
    @ViewBuilder var content: () -> Content

    public init(percent: Double, phase: Double = 0.6, amplitude: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.percent = percent
        self.phase = phase
        self.amplitude = amplitude
        self.content = content
    }

    public var body: some View {
        ZStack {
            content()
                .foregroundStyle(.primary)
                .mask(WaveShape(level: percent / 100, phase: phase, amplitude: amplitude, invert: true))
            content()
                .foregroundStyle(.white)
                .mask(WaveShape(level: percent / 100, phase: phase, amplitude: amplitude))
        }
    }
}

/// Moving water for the app. Widgets can't animate, so they use `WaterFill` directly.
public struct AnimatedWater<Overlay: View>: View {
    var percent: Double
    @ViewBuilder var overlay: (_ phase: Double) -> Overlay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    public init(percent: Double, @ViewBuilder overlay: @escaping (_ phase: Double) -> Overlay) {
        self.percent = percent
        self.overlay = overlay
    }

    public var body: some View {
        if reduceMotion {
            frame(phase: 0.6)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                frame(phase: context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 2 * .pi)
            }
        }
    }

    private func frame(phase: Double) -> some View {
        ZStack {
            Rectangle().fill(Palette.sky(scheme))
            WaterFill(percent: percent, phase: phase, amplitude: 6)
            overlay(phase)
        }
    }
}
