import Foundation
import StoreKit

enum TipProduct: String, CaseIterable {
    case small = "com.openshelf.tip.small"
    case medium = "com.openshelf.tip.medium"
    case large = "com.openshelf.tip.large"

    var displayName: String {
        switch self {
        case .small: "Buy me a coffee"
        case .medium: "Buy me a book"
        case .large: "Support indie development"
        }
    }

    var icon: String {
        switch self {
        case .small: "cup.and.saucer.fill"
        case .medium: "book.fill"
        case .large: "heart.fill"
        }
    }
}

@MainActor
@Observable
final class TipJarStore {
    private(set) var products: [Product] = []
    private(set) var isLoading = true
    var purchaseState: PurchaseState = .ready

    enum PurchaseState: Equatable {
        case ready
        case purchasing
        case thanked
        case error(String)
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ids = TipProduct.allCases.map(\.rawValue)
            products = try await Product.products(for: Set(ids))
                .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    purchaseState = .thanked
                    UserDefaults.standard.set(true, forKey: "hasTipped")
                } else {
                    purchaseState = .error("Purchase could not be verified. Please try again.")
                }
            case .pending:
                purchaseState = .ready
            case .userCancelled:
                purchaseState = .ready
            @unknown default:
                purchaseState = .ready
            }
        } catch {
            purchaseState = .error("Purchase failed. Please try again.")
        }
    }
}
