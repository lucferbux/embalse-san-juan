import XCTest
@testable import EmbalseKit

/// The 2.0 number style (docs/design/DESIGN-2.0.md, rule 2). The same cases are checked in Kotlin and in the web's tests.
final class FormatTests: XCTestCase {
    private let es = Locale(identifier: "es_ES")
    private let en = Locale(identifier: "en_GB")
    private let nbsp = "\u{00A0}"

    func testUnitsNeverWrapAway() {
        XCTAssertEqual(Format.percent(48.66, in: es), "48,7\(nbsp)%")
        XCTAssertEqual(Format.hm3(67.03, in: es), "67,0\(nbsp)hm³")
        XCTAssertEqual(Format.volumeOfCapacity(67.03, 138, in: es), "67,0\(nbsp)hm³ de 138\(nbsp)hm³")
        XCTAssertEqual(Format.volumeOfCapacity(67.03, 138, in: en), "67.0\(nbsp)hm³ of 138\(nbsp)hm³")
    }

    func testPrecisionTable() {
        XCTAssertEqual(Format.hm3(70, .mitecoVolume, in: es), "70\(nbsp)hm³")
        XCTAssertEqual(Format.hm3(57.5, .mitecoVolume, in: es), "57,5\(nbsp)hm³")
        XCTAssertEqual(Format.value(565.453, .metres, unit: "m", in: es), "565,45\(nbsp)m")
        XCTAssertEqual(Format.value(1.2, .flow, unit: "m³/s", in: en), "1.20\(nbsp)m³/s")
    }

    func testSignsUseTheRealMinus() {
        XCTAssertEqual(Format.signed(0.12, in: es), "+0,12")
        XCTAssertEqual(Format.signed(-0.32, in: es), "\u{2212}0,32")
        XCTAssertEqual(Format.signed(0.001, in: es), "0,00")
    }

    func testTrendIsAWordADirectionAndAnAmount() {
        XCTAssertEqual(Trend.sentence(0.12, in: es), "Estable · +0,12\(nbsp)hm³ en 24\(nbsp)h")
        XCTAssertEqual(Trend.sentence(-0.32, in: en), "Falling · \u{2212}0,32\(nbsp)hm³ in 24\(nbsp)h".replacingOccurrences(of: "0,32", with: "0.32"))
    }

    func testSourcesAreOnMadridTime() {
        let date = ISO8601DateFormatter().date(from: "2026-10-30T15:00:00Z")!
        XCTAssertEqual(Format.saihSource(date, in: es), "SAIH Tajo · 30 oct, 16:00")
        XCTAssertEqual(Format.mitecoWeek(Day.date(from: "2026-10-27"), in: es), "MITECO · semana del 27 oct")
        XCTAssertEqual(Format.mitecoWeek(Day.date(from: "2026-10-27"), in: en), "MITECO · week of 27 Oct")
    }

    func testMissingValues() {
        XCTAssertEqual(Format.optional(nil, unit: "m", in: es), "Sin dato")
        XCTAssertEqual(Format.optional(nil, unit: "m", in: en), "No data")
    }

    func testLocaleFollowsTheAppLanguage() {
        XCTAssertEqual(Format.resolveLocale(language: "es", current: Locale(identifier: "es_MX")).identifier, "es_MX")
        XCTAssertEqual(Format.resolveLocale(language: "es", current: Locale(identifier: "en_US")).identifier, "es_ES")
        XCTAssertEqual(Format.resolveLocale(language: "en", current: Locale(identifier: "en_US")).identifier, "en_US")
        XCTAssertEqual(Format.resolveLocale(language: "en-GB", current: Locale(identifier: "es_ES")).identifier, "en_GB")
    }

    func testCompassInBothLanguages() {
        XCTAssertEqual(Format.compass(202.5, in: es), "SSO")
        XCTAssertEqual(Format.compass(202.5, in: en), "SSW")
    }
}
