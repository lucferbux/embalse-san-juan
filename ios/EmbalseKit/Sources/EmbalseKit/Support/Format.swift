import Foundation

/// The one number style of the app, widgets, watch and web (docs/design/DESIGN-2.0.md, rule 2):
/// a no-break space before every unit, the real minus sign, and a fixed precision per quantity.
/// It follows the app's language, Spanish or English, with the device's region when it speaks the same language.
public enum Format {
    /// The language the app is showing, with the device's region when that region speaks it.
    public static let locale: Locale = resolveLocale(language: Bundle.main.preferredLocalizations.first ?? "es", current: .current)

    static func resolveLocale(language: String, current: Locale) -> Locale {
        let language = language.hasPrefix("en") ? "en" : "es"
        if current.language.languageCode?.identifier == language { return current }
        return Locale(identifier: language == "en" ? "en_GB" : "es_ES")
    }

    /// U+00A0, so a number never wraps away from its unit.
    public static let space = "\u{00A0}"

    // MARK: Precision, one place for every quantity

    public enum Quantity: Sendable {
        /// SAIH volume: 67,0 hm³
        case saihVolume
        /// MITECO volume: 70 hm³, or 57,5 hm³ when it isn't whole (the 10-year average)
        case mitecoVolume
        /// 48,7 %
        case percent
        /// Elevation and level: 565,45 m
        case metres
        /// Flows: 1,21 m³/s
        case flow
        /// 24 h change in volume: +0,12 hm³
        case change
    }

    static func decimals(_ quantity: Quantity, _ value: Double) -> Int {
        switch quantity {
        case .saihVolume, .percent: 1
        case .mitecoVolume: value.rounded() == value ? 0 : 1
        case .metres, .flow, .change: 2
        }
    }

    // MARK: Numbers

    public static func number(_ value: Double, decimals: Int = 1, in locale: Locale = locale) -> String {
        value.formatted(.number.locale(locale).precision(.fractionLength(decimals)))
    }

    public static func percent(_ value: Double, in locale: Locale = locale) -> String {
        number(value, decimals: decimals(.percent, value), in: locale) + space + "%"
    }

    public static func hm3(_ value: Double, _ quantity: Quantity = .saihVolume, in locale: Locale = locale) -> String {
        number(value, decimals: decimals(quantity, value), in: locale) + space + "hm³"
    }

    /// An explicit precision, for the few places the table above doesn't cover.
    public static func hm3(_ value: Double, decimals: Int, in locale: Locale = locale) -> String {
        number(value, decimals: decimals, in: locale) + space + "hm³"
    }

    /// "67,0 hm³ de 138 hm³": the SAIH volume over the capacity.
    public static func volumeOfCapacity(_ volume: Double, _ capacity: Double, in locale: Locale = locale) -> String {
        let of = Words.string("de", in: locale)
        return "\(hm3(volume, in: locale)) \(of) \(number(capacity, decimals: 0, in: locale))\(space)hm³"
    }

    public static func value(_ value: Double, _ quantity: Quantity, unit: String, in locale: Locale = locale) -> String {
        number(value, decimals: decimals(quantity, value), in: locale) + space + unit
    }

    public static func signed(_ value: Double, decimals: Int = 2, in locale: Locale = locale) -> String {
        let text = number(abs(value), decimals: decimals, in: locale)
        if text == number(0, decimals: decimals, in: locale) { return text }
        return (value > 0 ? "+" : "\u{2212}") + text
    }

    public static func optional(_ value: Double?, decimals: Int = 1, unit: String, in locale: Locale = locale) -> String {
        guard let value else { return Words.string("Sin dato", in: locale) }
        return number(value, decimals: decimals, in: locale) + space + unit
    }

    // MARK: Dates, always on Madrid's clock, which is the reservoir's

    static let madrid = TimeZone(identifier: "Europe/Madrid")!

    public static func hour(_ date: Date, in locale: Locale = locale) -> String {
        var style = Date.FormatStyle(locale: locale, timeZone: madrid).hour(.twoDigits(amPM: .omitted)).minute()
        style.locale = locale
        return date.formatted(style)
    }

    public static func dayMonth(_ date: Date, in locale: Locale = locale) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: madrid).day().month(.abbreviated))
    }

    public static func dayMonthHour(_ date: Date, in locale: Locale = locale) -> String {
        "\(dayMonth(date, in: locale)), \(hour(date, in: locale))"
    }

    /// "SAIH Tajo · 30 oct, 16:00", the source line every SAIH figure carries.
    public static func saihSource(_ date: Date, in locale: Locale = locale) -> String {
        "SAIH Tajo · \(dayMonthHour(date, in: locale))"
    }

    /// "MITECO · semana del 27 oct", the header of every MITECO panel.
    public static func mitecoWeek(_ date: Date, in locale: Locale = locale) -> String {
        "MITECO · " + Words.string("semana del %@", in: locale).replacingOccurrences(of: "%@", with: dayMonth(date, in: locale))
    }

    /// 16-point compass name for a direction in degrees.
    public static func compass(_ degrees: Double, in locale: Locale = locale) -> String {
        let spanish = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
        let english = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let names = Words.language(of: locale) == "en" ? english : spanish
        let normalised = degrees.truncatingRemainder(dividingBy: 360) + (degrees < 0 ? 360 : 0)
        return names[Int((normalised / 22.5).rounded()) % names.count]
    }
}

public enum Trend: Sendable, Equatable {
    case rising, falling, steady

    /// Wind moves the gauge by around ±0.1 hm³ in a day, so smaller changes aren't real movement.
    public static let threshold = 0.2

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

    public var label: String { label() }

    public func label(in locale: Locale = Format.locale) -> String {
        switch self {
        case .rising: Words.string("Subiendo", in: locale)
        case .falling: Words.string("Bajando", in: locale)
        case .steady: Words.string("Estable", in: locale)
        }
    }

    /// "Estable · +0,12 hm³ en 24 h": a word, a direction and an amount, never an arrow alone.
    public static func sentence(_ change: Double, in locale: Locale = Format.locale) -> String {
        let amount = Format.signed(change, in: locale) + Format.space + "hm³"
        let window = Words.string("en 24 h", in: locale).replacingOccurrences(of: " h", with: Format.space + "h")
        return "\(Trend(change: change).label(in: locale)) · \(amount) \(window)"
    }
}

/// The few words `Format` and `Trend` put into figures, looked up in a given language rather than the device's, so
/// tests and previews can ask for either. Everything else on screen comes from the string catalogs.
enum Words {
    static func language(of locale: Locale) -> String {
        locale.language.languageCode?.identifier == "en" ? "en" : "es"
    }

    static func string(_ key: String, in locale: Locale) -> String {
        guard let path = Bundle.module.path(forResource: language(of: locale), ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
