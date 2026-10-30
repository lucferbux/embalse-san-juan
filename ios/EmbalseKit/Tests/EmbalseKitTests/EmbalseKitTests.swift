import XCTest
@testable import EmbalseKit

/// `contract/fixtures/snapshot.json` is built and validated by the backend, so decoding it here
/// proves both sides agree on the contract.
enum Fixture {
    static let root = URL(filePath: #filePath)
        .deletingLastPathComponent() // EmbalseKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // EmbalseKit
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // project root

    static func snapshotData() throws -> Data {
        try Data(contentsOf: root.appending(path: "contract/fixtures/snapshot.json"))
    }

    static func snapshot() throws -> Snapshot {
        try FirestoreClient.makeDecoder().decode(Snapshot.self, from: snapshotData())
    }
}

final class ContractTests: XCTestCase {
    func testDecodesTheSharedFixture() throws {
        let snapshot = try Fixture.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.live.volumeHm3, 67.03)
        XCTAssertEqual(snapshot.live.percent, 48.66)
        XCTAssertEqual(snapshot.recent.count, 24)
        XCTAssertEqual(snapshot.weekly.lastYearHm3, 75)
        XCTAssertEqual(snapshot.neighbours.first?.name, "Burguillo")
        XCTAssertEqual(snapshot.rainGauges.first?.code, "P_37")
    }

    func testDecodesAFirestoreEnvelope() throws {
        let payload = String(decoding: try Fixture.snapshotData(), as: UTF8.self)
        let envelope = ["fields": ["payload": ["stringValue": payload]]]
        let snapshot: Snapshot = try FirestoreClient.decodePayload(JSONEncoder().encode(envelope))
        XCTAssertEqual(snapshot.live.volumeHm3, 67.03)
    }

    func testReportsAMissingPayload() {
        let data = Data(#"{"fields":{}}"#.utf8)
        XCTAssertThrowsError(try FirestoreClient.decodePayload(data) as Snapshot) { error in
            XCTAssertEqual(error as? FirestoreClient.ClientError, .missingPayload)
        }
    }

    func testDecodesCompactHistoryRows() throws {
        let json = #"{"schemaVersion":1,"generatedAt":"2026-10-30T15:30:00Z","weekly":[["1988-01-05",131,146]],"daily":[["2026-10-29",66.99]]}"#
        let history = try FirestoreClient.makeDecoder().decode(History.self, from: Data(json.utf8))
        XCTAssertEqual(history.weekly.first?.capacityHm3, 146)
        XCTAssertEqual(history.daily.first?.volumeHm3, 66.99)
    }
}

final class BehaviourTests: XCTestCase {
    func testFormatsInSpanish() {
        XCTAssertEqual(Format.percent(48.66), "48,7 %")
        XCTAssertEqual(Format.hm3(67.03), "67,0 hm³")
        XCTAssertEqual(Format.signed(0.12), "+0,12")
        XCTAssertEqual(Format.signed(-5, decimals: 0), "−5")
        XCTAssertEqual(Format.optional(nil, unit: "m"), "Sin dato")
    }

    func testCompassWrapsAround() {
        XCTAssertEqual(Format.compass(0), "N")
        XCTAssertEqual(Format.compass(147.1), "SSE")
        XCTAssertEqual(Format.compass(359), "N")
    }

    func testTrendIgnoresSensorNoise() {
        XCTAssertEqual(Trend(change: 0.3), .rising)
        XCTAssertEqual(Trend(change: -0.5), .falling)
        XCTAssertEqual(Trend(change: 0.12), .steady)
    }

    func testStaleAfterSixHours() throws {
        let snapshot = try Fixture.snapshot()
        XCTAssertFalse(snapshot.isStale(at: snapshot.live.observedAt.addingTimeInterval(5 * 3600)))
        XCTAssertTrue(snapshot.isStale(at: snapshot.live.observedAt.addingTimeInterval(7 * 3600)))
    }

    func testMadridDayKeepsItsDateInAnyZone() {
        let date = Day.date(from: "2026-10-27")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: date), DateComponents(year: 2026, month: 10, day: 27))
    }

    func testValuesSurviveTheCache() throws {
        let cache = SnapshotCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        try FileManager.default.createDirectory(at: cache.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let snapshot = try Fixture.snapshot()
        cache.save(snapshot)
        XCTAssertEqual(cache.load(), snapshot)
    }

    func testFallsBackToTheCacheWhenOffline() async throws {
        let cache = SnapshotCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        try FileManager.default.createDirectory(at: cache.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let snapshot = try Fixture.snapshot()

        let online = try await SnapshotRepository(fetch: { snapshot }, cache: cache).load()
        XCTAssertEqual(online.origin, .network)

        let offline = try await SnapshotRepository(fetch: { throw URLError(.notConnectedToInternet) }, cache: cache).load()
        XCTAssertEqual(offline.origin, .cache)
        XCTAssertEqual(offline.snapshot, snapshot)
    }

    func testThrowsWhenOfflineWithNothingSaved() async throws {
        let cache = SnapshotCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        do {
            _ = try await SnapshotRepository(fetch: { throw URLError(.notConnectedToInternet) }, cache: cache).load()
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }
}
