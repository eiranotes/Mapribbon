import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class StoreService {
    static let lifetimeProductID = "com.eiraworks.mapribbon.lifetime"

    private(set) var lifetimeProduct: Product?
    private(set) var isUnlocked = false
    private(set) var isLoading = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }


    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            lifetimeProduct = try await Product.products(for: [Self.lifetimeProductID]).first
        } catch {
            errorMessage = "구매 정보를 불러오지 못했습니다."
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.lifetimeProductID,
               transaction.revocationDate == nil {
                unlocked = true
                break
            }
        }
        isUnlocked = unlocked
    }

    func purchaseLifetime() async {
        guard let product = lifetimeProduct else {
            await loadProducts()
            guard let product = lifetimeProduct else {
                errorMessage = "App Store Connect에 영구 구매 상품을 등록한 뒤 테스트할 수 있습니다."
                return
            }
            await purchase(product)
            return
        }
        await purchase(product)
    }

    private func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "구매 확인에 실패했습니다."
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                errorMessage = "구매 승인을 기다리고 있습니다."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "구매 복원에 실패했습니다."
        }
    }
}
