import Foundation
import Observation
import StoreKit

@Observable @MainActor final class StoreController {
    static let yearlyID = "app.paperloft.receipts.pro.yearly"
    static let lifetimeID = "app.paperloft.receipts.pro.lifetime"
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var ready = false
    private(set) var busy = false
    private(set) var status = ""
    private(set) var trialEligible = false
    /// The active Pro purchase, for "You have Paperloft Pro" details.
    enum ProPlan: Equatable { case yearly(renews: Date?, trialEnds: Date?), lifetime }
    private(set) var plan: ProPlan?
    /// Purchase and restore results are for the sheet that asked; clear them when it closes.
    func clearStatus() { status = "" }
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private(set) var started = false
    #if DEBUG || QA
    let isMock: Bool
    private var mockPurchased: String?
    enum MockOutcome: String, CaseIterable { case success, cancelled, pending, failure }
    var mockOutcome = MockOutcome.success
    /// `-PaperloftStoreMock YES` starts as Pro (lifetime) so Pro-only flows can be tested;
    /// `-PaperloftStoreMock Free` starts on Free so the paywall and purchases can be tested.
    init(mock: Bool? = nil, startPro: Bool? = nil) {
        let args = ProcessInfo.processInfo.arguments
        let value = args.firstIndex(of: "-PaperloftStoreMock").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        isMock = mock ?? (value == "YES" || value == "Free")
        if isMock && (startPro ?? (value == "YES")) { mockPurchased = Self.lifetimeID; isPro = true; plan = .lifetime }
    }
    private func mockPlan() -> ProPlan? {
        switch mockPurchased {
        case Self.lifetimeID: return .lifetime
        case Self.yearlyID:
            let end = Calendar.current.date(byAdding: .day, value: 7, to: .now)
            return .yearly(renews: end, trialEnds: end)
        default: return nil
        }
    }
    #else
    var isMock: Bool { false }
    init() {}
    #endif
    deinit { updates?.cancel(); expiryTask?.cancel() }
    /// Waits for the first entitlement check after `start()` (at most 10 s, so a slow App Store
    /// never stalls reading); returns at once if never started.
    func waitUntilReady() async {
        let deadline = Date.now.addingTimeInterval(10)
        while started && !ready && Date.now < deadline { try? await Task.sleep(for: .milliseconds(50)) }
    }
    func start() async {
        guard !started else { return }; started = true
        #if DEBUG || QA
        if isMock { ready = true; trialEligible = true; return }
        #endif
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result,
                   [Self.yearlyID, Self.lifetimeID].contains(transaction.productID) {
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
        await refreshEntitlements()
        await loadProducts()
    }
    func loadProducts() async {
        #if DEBUG || QA
        if isMock { return }
        #endif
        do {
            products = try await Product.products(for: [Self.yearlyID, Self.lifetimeID])
            if let subscription = products.first(where: { $0.id == Self.yearlyID })?.subscription {
                trialEligible = await subscription.isEligibleForIntroOffer
            }
            if products.count < 2 { status = "Purchases are temporarily unavailable. You can keep using Free or restore purchases." }
        } catch { status = "The App Store could not load prices. Try again when connected." }
    }
    /// StoreKit supplies its on-device signed transaction cache, including offline.
    /// Never trust an editable preferences Boolean to grant a paid entitlement.
    func refreshEntitlements() async {
        #if DEBUG || QA
        if isMock { ready = true; return }
        #endif
        var entitled = false
        var nextExpiry: Date?
        var activePlan: ProPlan?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  [Self.yearlyID, Self.lifetimeID].contains(transaction.productID),
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            if let expiration = transaction.expirationDate {
                guard expiration > .now else { continue }
                nextExpiry = max(nextExpiry ?? expiration, expiration)
            }
            entitled = true
            if transaction.productID == Self.lifetimeID { activePlan = .lifetime }
            else if activePlan != .lifetime {
                activePlan = .yearly(renews: transaction.expirationDate, trialEnds: transaction.offer?.type == .introductory ? transaction.expirationDate : nil)
            }
        }
        isPro = entitled; plan = activePlan; ready = true
        expiryTask?.cancel()
        if let nextExpiry {
            expiryTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(0, nextExpiry.timeIntervalSinceNow))) } catch { return }
                await self?.refreshEntitlements()
            }
        }
    }
    func purchase(productID: String) async {
        guard !busy, [Self.yearlyID, Self.lifetimeID].contains(productID) else { return }
        busy = true; defer { busy = false }
        #if DEBUG || QA
        if isMock {
            switch mockOutcome {
            case .success: mockPurchased = productID; isPro = true; plan = mockPlan(); status = ""
            case .cancelled: status = "Purchase cancelled. You have not been charged."
            case .pending: status = "Purchase pending approval. Free remains available."
            case .failure: status = "Purchase could not be completed. Try again."
            }
            return
        }
        #endif
        guard let product = products.first(where: { $0.id == productID }) else { status = "This purchase is unavailable. Reload prices and try again."; return }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { status = "The purchase could not be verified. Try Restore Purchases."; return }
                await refreshEntitlements(); await transaction.finish()
                status = isPro ? "" : "The purchase is not currently active."
            case .userCancelled: status = "Purchase cancelled. You have not been charged."
            case .pending: status = "Purchase pending approval. Free remains available."
            @unknown default: status = "The purchase has not completed. Try Restore Purchases."
            }
        } catch StoreKitError.userCancelled {
            status = "Purchase cancelled. You have not been charged."
        } catch { status = "Purchase could not be completed. Try again. " + error.localizedDescription }
    }
    func restore() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        #if DEBUG || QA
        if isMock { isPro = mockPurchased != nil; plan = mockPlan(); status = isPro ? "Purchases restored." : "No purchases found for this Apple Account. If you bought Pro on another Mac, use the same Apple Account here, then choose Restore Purchases."; return }
        #endif
        do {
            try await AppStore.sync(); await refreshEntitlements()
            status = isPro ? "Purchases restored." : "No purchases found for this Apple Account. If you bought Pro on another Mac, use the same Apple Account here, then choose Restore Purchases."
        } catch { status = "Purchases could not be restored. Try again when connected." }
    }
    #if DEBUG || QA
    func mockExpire() { guard isMock else { return }; mockPurchased = nil; isPro = false; plan = nil; status = "Mock subscription expired. Free is active." }
    func mockHideEntitlement() { guard isMock else { return }; isPro = false; plan = nil; status = "Mock entitlement cleared locally. Restore to recover it." }
    func mockApprovePending() { guard isMock else { return }; mockPurchased = Self.yearlyID; isPro = true; plan = mockPlan(); status = "Mock pending purchase approved." }
    #endif
}
