#if os(iOS)
import Foundation
import Observation
import StoreKit

/// Tips go through in-app purchase, as Guideline 3.1.1 asks. They're consumables that unlock nothing.
@MainActor
@Observable
public final class TipJar {
    public enum State: Equatable {
        case loading
        /// The App Store has no products to offer, so the screen says so instead of showing buttons.
        case unavailable
        case ready
    }

    public static let productIDs = [
        "com.lucferbux.embalsesanjuan.tip.small",
        "com.lucferbux.embalsesanjuan.tip.medium",
        "com.lucferbux.embalsesanjuan.tip.large",
    ]

    public private(set) var state: State = .loading
    public private(set) var products: [Product] = []
    public private(set) var purchasing: Product.ID?
    public private(set) var thanked = false
    public private(set) var failed = false

    public init() {}

    public func load() async {
        do {
            let found = try await Product.products(for: Self.productIDs)
            products = found.sorted { $0.price < $1.price }
            state = products.isEmpty ? .unavailable : .ready
        } catch {
            state = .unavailable
        }
    }

    /// `purchase` is SwiftUI's `purchase` environment action, which shows the sheet in this window:
    /// on iPhone Duo and iPad there can be more than one scene.
    public func buy(_ product: Product, using purchase: (Product) async throws -> Product.PurchaseResult) async {
        purchasing = product.id
        failed = false
        defer { purchasing = nil }
        do {
            switch try await purchase(product) {
            case .success(let result):
                await settle(result)
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            print("Tip purchase failed: \(error)")
            failed = true
        }
    }

    public func dismissThanks() {
        thanked = false
    }

    /// Purchases that complete away from this screen, such as one awaiting a parent's approval.
    /// Call once at launch, or StoreKit keeps redelivering them.
    public static func finishPendingTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
        }
    }

    private func settle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            failed = true
            return
        }
        await transaction.finish()
        thanked = true
    }
}
#endif
