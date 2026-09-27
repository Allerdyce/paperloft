import XCTest
import StoreKit
import StoreKitTest
@testable import Paperloft_Receipts

@MainActor final class StoreControllerTests: XCTestCase {
    private func session() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Paperloft", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }
    private func controller() async -> StoreController {
        let store = StoreController(mock: false)
        await store.start()
        return store
    }
    func testYearlyTrialPricePurchaseAndExpiry() async throws {
        let session = try session()
        let store = await controller()
        let product = try XCTUnwrap(store.products.first { $0.id == StoreController.yearlyID })
        XCTAssertEqual(product.price, Decimal(string: "29.99"))
        XCTAssertEqual(product.subscription?.introductoryOffer?.period.unit, .day)
        XCTAssertEqual(product.subscription?.introductoryOffer?.period.value, 7)
        XCTAssertFalse(store.isPro)
        await store.purchase(productID: product.id)
        XCTAssertTrue(store.isPro)
        try session.expireSubscription(productIdentifier: product.id)
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPro)
    }
    func testLifetimeRestoreAndRevocation() async throws {
        let session = try session()
        let store = await controller()
        let product = try XCTUnwrap(store.products.first { $0.id == StoreController.lifetimeID })
        XCTAssertEqual(product.price, Decimal(string: "69.99"))
        await store.purchase(productID: product.id)
        XCTAssertTrue(store.isPro)
        let fresh = await controller()
        XCTAssertTrue(fresh.isPro)
        await fresh.restore()
        XCTAssertTrue(fresh.isPro)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == product.id })
        try session.refundTransaction(identifier: transaction.identifier)
        await fresh.refreshEntitlements()
        XCTAssertFalse(fresh.isPro)
    }
    func testCancelledPurchaseDoesNotGrantPro() async throws {
        let session = try session()
        let store = await controller()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: StoreKitPurchaseAPI())
        await store.purchase(productID: StoreController.yearlyID)
        XCTAssertFalse(store.isPro)
        XCTAssertTrue(store.status.localizedCaseInsensitiveContains("cancelled"))
    }
    func testPendingThenApprovedPurchase() async throws {
        let session = try session()
        session.askToBuyEnabled = true
        let store = await controller()
        await store.purchase(productID: StoreController.yearlyID)
        XCTAssertFalse(store.isPro)
        XCTAssertTrue(store.status.localizedCaseInsensitiveContains("pending"))
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        await store.refreshEntitlements()
        XCTAssertTrue(store.isPro)
    }
    func testCachedEntitlementSurvivesStoreNetworkFailures() async throws {
        let session = try session()
        let store = await controller()
        await store.purchase(productID: StoreController.lifetimeID)
        XCTAssertTrue(store.isPro)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitLoadProductsAPI())
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: StoreKitAppStoreSyncAPI())
        let offline = StoreController(mock: false)
        await offline.refreshEntitlements()
        XCTAssertTrue(offline.isPro)
    }
    func testMockPurchaseCancelPendingRestoreExpiry() async {
        let store = StoreController(mock: true)
        await store.start()
        XCTAssertFalse(store.isPro)
        store.mockOutcome = .cancelled
        await store.purchase(productID: StoreController.yearlyID)
        XCTAssertFalse(store.isPro)
        store.mockOutcome = .pending
        await store.purchase(productID: StoreController.yearlyID)
        XCTAssertFalse(store.isPro)
        store.mockApprovePending()
        XCTAssertTrue(store.isPro)
        store.mockHideEntitlement()
        XCTAssertFalse(store.isPro)
        await store.restore()
        XCTAssertTrue(store.isPro)
        store.mockExpire()
        await store.restore()
        XCTAssertFalse(store.isPro)
        store.mockOutcome = .success
        await store.purchase(productID: StoreController.lifetimeID)
        XCTAssertTrue(store.isPro)
    }
}
