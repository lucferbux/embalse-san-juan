import XCTest
@testable import EmbalseKit

final class YearComparisonTests: XCTestCase {
    /// Twelve years of Tuesday bulletins, each year's volume equal to its offset so averages are easy to check:
    /// 2015 is 15 hm³ every week, 2026 is 26 hm³, and so on. 2026 runs to 27 October.
    private func history(endingWith last: String = "2026-10-27") throws -> History {
        var rows: [String] = []
        let calendar = YearComparison.calendar
        var date = Day.date(from: "2015-01-06")
        let end = Day.date(from: last)
        while date <= end {
            let year = calendar.component(.year, from: date)
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            rows.append(String(format: "[\"%04d-%02d-%02d\",%d,138]", parts.year!, parts.month!, parts.day!, year - 2000))
            date = calendar.date(byAdding: .day, value: 7, to: date)!
        }
        let json = "{\"generatedAt\":\"2026-10-28T00:00:00Z\",\"weekly\":[\(rows.joined(separator: ","))],\"daily\":[]}"
        return try FirestoreClient.makeDecoder().decode(History.self, from: Data(json.utf8))
    }

    func testThisYearEndsAtTheLatestBulletin() throws {
        let comparison = try XCTUnwrap(YearComparison(history: history()))
        XCTAssertEqual(comparison.year, 2026)
        XCTAssertEqual(comparison.thisYear.last?.volumeHm3, 26)
        XCTAssertEqual(comparison.thisYear.last?.date, Day.date(from: "2026-10-27"))
        XCTAssertEqual(comparison.capacityHm3, 138)
    }

    func testLastYearIsMovedOntoThisYearsAxis() throws {
        let comparison = try XCTUnwrap(YearComparison(history: history()))
        XCTAssertEqual(comparison.lastYear.count, 52)
        XCTAssertTrue(comparison.lastYear.allSatisfy { $0.volumeHm3 == 25 })
        XCTAssertEqual(YearComparison.calendar.component(.year, from: comparison.lastYear[0].date), 2026)
        XCTAssertEqual(comparison.lastYearNow, 25)
    }

    func testTheAverageNeedsAllTenYears() throws {
        // Years 2016 to 2025 average to 20,5 hm³.
        let comparison = try XCTUnwrap(YearComparison(history: history()))
        XCTAssertEqual(comparison.averageNow ?? 0, 20.5, accuracy: 0.001)
        // The series starts in January 2015, so early-January 2016 weeks still have ten years only from 2016 on.
        XCTAssertFalse(comparison.average.isEmpty)
    }

    func testNoHistoryNoComparison() throws {
        let empty = try FirestoreClient.makeDecoder().decode(History.self, from: Data("{\"generatedAt\":\"2026-10-28T00:00:00Z\",\"weekly\":[],\"daily\":[]}".utf8))
        XCTAssertNil(YearComparison(history: empty))
    }
}

final class HistoryRepositoryTests: XCTestCase {
    private static func document(volume: Double) -> Data {
        let payload = "{\\\"generatedAt\\\":\\\"2026-10-28T00:00:00Z\\\",\\\"weekly\\\":[[\\\"2026-10-27\\\",\(volume),138]],\\\"daily\\\":[]}"
        return Data("{\"fields\":{\"payload\":{\"stringValue\":\"\(payload)\"}}}".utf8)
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testKeepsACopyForOfflineUse() async throws {
        let folder = try directory()
        let online = HistoryRepository(fetch: { _ in Self.document(volume: 70) }, directory: folder)
        let fresh = try await online.load(.burguillo)
        XCTAssertEqual(fresh.weekly.last?.volumeHm3, 70)

        let offline = HistoryRepository(fetch: { _ in throw URLError(.notConnectedToInternet) }, directory: folder)
        let later = Date.now.addingTimeInterval(2 * 3600)
        let cached = try await offline.load(.burguillo, now: later)
        XCTAssertEqual(cached.weekly.last?.volumeHm3, 70)
        await XCTAssertThrowsErrorAsync(try await offline.load(.picadas, now: later))
    }

    func testReusesAFreshCopyWithoutARequest() async throws {
        let folder = try directory()
        _ = try await HistoryRepository(fetch: { _ in Self.document(volume: 70) }, directory: folder).load(.sanJuan)
        let failing = HistoryRepository(fetch: { _ in XCTFail("should not fetch"); throw URLError(.badURL) }, directory: folder)
        let history = try await failing.load(.sanJuan)
        XCTAssertEqual(history.weekly.count, 1)
    }

    func testDocumentsPerReservoir() {
        XCTAssertEqual(ReservoirID.sanJuan.historyDocument, "history")
        XCTAssertEqual(ReservoirID.burguillo.historyDocument, "history-burguillo")
        XCTAssertEqual(ReservoirID.picadas.historyDocument, "history-picadas")
    }
}

final class ForecastAndChainTests: XCTestCase {
    func testTheFixtureCarriesTheForecastAndTheChain() throws {
        let snapshot = try Fixture.snapshot()
        let forecast = try XCTUnwrap(snapshot.forecast)
        XCTAssertFalse(forecast.days.isEmpty)
        XCTAssertEqual(forecast.source.name, "AEMET OpenData")
        XCTAssertEqual(snapshot.chain.first?.reservoir, .burguillo)
        XCTAssertEqual(snapshot.reading(of: .sanJuan)?.percent, snapshot.live.percent)
    }

    func testASnapshotWithoutForecastStillDecodes() throws {
        var object = try JSONSerialization.jsonObject(with: Fixture.snapshotData()) as! [String: Any]
        object.removeValue(forKey: "forecast")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNil(try FirestoreClient.makeDecoder().decode(Snapshot.self, from: data).forecast)
    }
}

func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure () async throws -> T, file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {}
}
