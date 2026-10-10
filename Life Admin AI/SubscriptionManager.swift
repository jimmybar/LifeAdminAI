import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    enum ProductID: String, CaseIterable {
        case proMonthly = "com.lifeadminai.pro.monthly"
    }

    private(set) var products: [Product] = []
    private(set) var isPro: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

#if DEBUG
    var isTestSubscriptionActive: Bool {
        get { UserDefaults.standard.bool(forKey: "debugForceProActive") }
        set {
            UserDefaults.standard.set(newValue, forKey: "debugForceProActive")
            Task { @MainActor in
                await updateSubscriptionStatus()
            }
        }
    }
#else
    var isTestSubscriptionActive: Bool { false }
#endif

    let freeDocumentLimit: Int = 10

    nonisolated private let transactionListenerTask: Task<Void, Never>

    init() {
        self.transactionListenerTask = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try SubscriptionManager.checkVerified(result)
                    await transaction.finish()
                    await SubscriptionManager.shared.updateSubscriptionStatus()
                } catch {
                    print("Error verificando transacción recibida: \(error)")
                }
            }
        }

        Task {
            await fetchProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListenerTask.cancel()
    }

    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
                .sorted(by: { $0.price < $1.price })
        } catch {
            errorMessage = LanguageManager.tr("sub.errFetch")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try SubscriptionManager.checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = LanguageManager.tr("sub.errRestore")
        }
    }

    func updateSubscriptionStatus() async {
#if DEBUG
        if isTestSubscriptionActive {
            isPro = true
            return
        }
#endif

        var activePro = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try SubscriptionManager.checkVerified(result)
                if ProductID.allCases.map(\.rawValue).contains(transaction.productID) {
                    if transaction.revocationDate == nil {
                        activePro = true
                        break
                    }
                }
            } catch {
                continue
            }
        }

        isPro = activePro
    }

    func toggleTestSubscription() {
#if DEBUG
        isTestSubscriptionActive.toggle()
#endif
    }

    nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    // Reglas del modelo de negocio
    func canCreateDocument(currentCount: Int) -> Bool {
        return isPro || currentCount < freeDocumentLimit
    }

    var isCloudSyncIncludedInBase: Bool { true }
    var isSecurityIncludedInBase: Bool { true }

    var isUnlimitedDocumentsAvailable: Bool { isPro }
    var isUnlimitedAIAvailable: Bool { isPro }
    var isAdvancedCategoriesAvailable: Bool { isPro }
    var isExportAndEncryptedBackupAvailable: Bool { isPro }
}
