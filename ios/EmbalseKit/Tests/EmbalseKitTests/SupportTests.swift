import XCTest
@testable import EmbalseKit

final class SuggestionTests: XCTestCase {
    func testTrimsBeforeValidating() {
        XCTAssertFalse(Suggestion(kind: .bug, text: "  \n ").isValid)
        XCTAssertFalse(Suggestion(kind: .bug, text: " ab ").isValid)
        XCTAssertTrue(Suggestion(kind: .bug, text: " abc ").isValid)
    }

    func testEnforcesTheMaximumLength() {
        XCTAssertTrue(Suggestion(kind: .other, text: String(repeating: "a", count: 1000)).isValid)
        XCTAssertFalse(Suggestion(kind: .other, text: String(repeating: "a", count: 1001)).isValid)
    }

    func testBodyHasOnlyTheFieldsTheRulesAllow() throws {
        let date = Date(timeIntervalSince1970: 1_793_000_000)
        let data = try Suggestion(kind: .suggestion, text: " Más gráficos ").firestoreBody(date: date, appVersion: "1.0")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [String: [String: String]]])
        let fields = try XCTUnwrap(body["fields"])
        XCTAssertEqual(Set(fields.keys), ["kind", "text", "appVersion", "createdAt"])
        XCTAssertEqual(fields["kind"]?["stringValue"], "suggestion")
        XCTAssertEqual(fields["text"]?["stringValue"], "Más gráficos")
        XCTAssertEqual(fields["createdAt"]?["timestampValue"], "2026-10-26T07:33:20Z")
    }

    func testRefusesToSendAnInvalidSuggestion() async {
        do {
            try await SuggestionClient().send(Suggestion(kind: .bug, text: ""))
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? SuggestionClient.ClientError, .invalid)
        }
    }
}
