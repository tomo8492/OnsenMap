import Foundation
import StoreKit
import Combine

// MARK: - Store Manager
/// StoreKit 2 を使った IAP 管理。
/// - 購入状態を `isPro` で公開
/// - Product.products / Transaction.currentEntitlements / Transaction.updates を監視
/// - Pro は買い切り (non-consumable) を想定
@MainActor
final class StoreManager: ObservableObject {

    static let shared = StoreManager()

    // MARK: - Product IDs
    /// App Store Connect で同じ ID を登録すること
    enum ProductID {
        static let lifetimePro = "com.yourcompany.OnsenMap.lifetime_pro"
        static let allIDs: Set<String> = [lifetimePro]
    }

    // MARK: - Published
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var lastError: String?

    /// Pro 購入済みか
    var isPro: Bool {
        purchasedProductIDs.contains(ProductID.lifetimePro)
    }

    /// Pro 商品（買い切り）
    var lifetimeProProduct: Product? {
        products.first(where: { $0.id == ProductID.lifetimePro })
    }

    // MARK: - Internals
    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await refreshPurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoadingProducts = true
        lastError = nil
        do {
            let fetched = try await Product.products(for: ProductID.allIDs)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            lastError = error.localizedDescription
            print("⚠️ StoreKit product load failed: \(error)")
        }
        isLoadingProducts = false
    }

    // MARK: - Purchase
    enum PurchaseResult {
        case success
        case userCancelled
        case pending
        case failed(String)
    }

    @discardableResult
    func purchase(_ product: Product) async -> PurchaseResult {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchasedProductIDs.insert(transaction.productID)
                return .success
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshPurchasedProducts()
    }

    // MARK: - Refresh entitlements
    func refreshPurchasedProducts() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                ids.insert(transaction.productID)
            }
        }
        purchasedProductIDs = ids
    }

    // MARK: - Listen for transaction updates
    /// `Task { ... }` (not detached) なので MainActor を継承する。
    /// self は弱参照で持ち、シングルトン破棄時にループを終わらせる。
    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    self?.purchasedProductIDs.insert(transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Verification helper
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification: return "購入の検証に失敗しました"
            }
        }
    }
}
