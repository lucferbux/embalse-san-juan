import Foundation

/// Spanish number and date formats, whatever the device's region.
public enum Format {
    static let locale = Locale(identifier: "es_ES")

    public static func number(_ value: Double, decimals: Int = 1) -> String {
        value.formatted(.number.locale(locale).precision(.fractionLength(decimals)))
    }

    public static func percent(_ value: Double) -> String {
        "\(number(value)) %"
    }

    public static func hm3(_ value: Double, decimals: Int = 1) -> String {
        "\(number(value, decimals: decimals)) hm³"
    }

    public static func signed(_ value: Double, decimals: Int = 2) -> String {
        let text = number(abs(value), decimals: decimals)
        if value > 0 { return "+\(text)" }
        if value < 0 { return "−\(text)" }
        return text
    }

    public static func optional(_ value: Double?, decimals: Int = 1, unit: String) -> String {
        guard let value else { return "Sin dato" }
        return "\(number(value, decimals: decimals)) \(unit)"
    }

    public static func hour(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale).hour(.twoDigits(amPM: .omitted)).minute())
    }

    public static func dayMonth(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale).day().month(.abbreviated))
    }

    public static func dayMonthHour(_ date: Date) -> String {
        "\(dayMonth(date)), \(hour(date))"
    }

    /// 16-point compass name for a direction in degrees.
    public static func compass(_ degrees: Double) -> String {
        let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
        let normalised = degrees.truncatingRemainder(dividingBy: 360) + (degrees < 0 ? 360 : 0)
        return names[Int((normalised / 22.5).rounded()) % names.count]
    }
}

public enum Trend: Sendable, Equatable {
    case rising, falling, steady

    /// Wind moves the gauge by around ±0.1 hm³ in a day, so smaller changes aren't real movement.
    static let threshold = 0.2

    public init(change: Double) {
        if change > Self.threshold {
            self = .rising
        } else if change < -Self.threshold {
            self = .falling
        } else {
            self = .steady
        }
    }

    public var symbol: String {
        switch self {
        case .rising: "arrow.up.right"
        case .falling: "arrow.down.right"
        case .steady: "arrow.right"
        }
    }

    public var label: String {
        switch self {
        case .rising: "Subiendo"
        case .falling: "Bajando"
        case .steady: "Estable"
        }
    }
}
