import Observation
import StoreKit

/// 「広告を消す」(非消耗型の買い切り)。購入状態は StoreKit 2 が端末にキャッシュするので、オフラインでも判定できる。
@MainActor
@Observable
final class PurchaseStore {
    static let removeAdsID = "com.taiki.StockNote.removeads"

    /// nil は「まだ確認中」。購入済みの人に広告が一瞬出ないよう、広告は false と確定してから出す。
    private(set) var adsRemoved: Bool?
    private(set) var product: Product?
    private(set) var isWorking = false
    var message: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates { await self?.handle(result) }
        }
        Task {
            await refreshEntitlement()
            await loadProduct()
        }
    }

    deinit { updatesTask?.cancel() }

    var priceText: String { product?.displayPrice ?? "" }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.removeAdsID]).first
    }

    func purchase() async {
        guard let product else {
            message = "商品情報を取得できませんでした。通信の状態を確認して、もう一度お試しください。"
            await loadProduct()
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await handle(result)
            case .pending:
                message = "購入は承認待ちです。承認されると、広告が消えます。"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "購入を完了できませんでした。しばらくしてからお試しください。"
        }
    }

    /// 機種変更や再インストールのあとに、購入済みの状態を戻す
    func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            message = adsRemoved == true ? "購入を復元しました。" : "復元できる購入が見つかりませんでした。"
        } catch {
            message = "復元できませんでした。Apple ID でサインインしているか確認してください。"
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            message = "購入を確認できませんでした。"
            return
        }
        await transaction.finish()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.removeAdsID, t.revocationDate == nil {
                owned = true
            }
        }
        adsRemoved = owned
    }
}
