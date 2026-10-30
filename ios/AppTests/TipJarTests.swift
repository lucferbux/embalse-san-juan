import EmbalseKit
import StoreKit
import StoreKitTest
import UIKit
import XCTest

/// Uses StoreKit's test store, which needs an app around it, so this target runs hosted in the app.
/// A successful purchase returns an unknown error there, even when signed, so it isn't covered here:
/// check it in sandbox from TestFlight.
@MainActor
final class TipJarTests: XCTestCase {
    private func inHostScene(_ product: Product) async throws -> Product.PurchaseResult {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
        return try await product.purchase(confirmIn: scene)
    }

    private func makeSession() throws -> SKTestSession {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "App/Tips.storekit")
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    func testLoadsEveryTipCheapestFirst() async throws {
        let session = try makeSession()
        defer { _ = session }
        let jar = TipJar()
        await jar.load()
        XCTAssertEqual(jar.state, .ready)
        XCTAssertEqual(jar.products.map(\.id), TipJar.productIDs)
    }

    func testReportsAFailedPurchase() async throws {
        let session = try makeSession()
        session.failTransactionsEnabled = true
        let jar = TipJar()
        await jar.load()
        await jar.buy(try XCTUnwrap(jar.products.first), using: inHostScene)
        XCTAssertTrue(jar.failed)
        XCTAssertFalse(jar.thanked)
    }
}
