import Testing
import Foundation
import StoreKitTest
import StoreKit
@testable import Alertivity

@MainActor
private final class FakeProClient: ProPurchasing {
    var access = false
    var available = true
    var failure = false
    var purchaseError: Error?
    var result: ProPurchaseResult = .cancelled
    var calls = 0
    var finishes = 0
    var restoreCalls = 0
    var continuation: AsyncStream<ProDelivery>.Continuation?
    var suspendAccess = false
    var accessContinuation: CheckedContinuation<Bool, Never>?
    var suspendPurchase = false
    var purchaseContinuation: CheckedContinuation<ProPurchaseResult, Never>?

    func loadProduct() async throws -> ProProduct? {
        calls += 1
        if failure { throw Failure.expected }
        return available ? ProProduct(displayPrice: "$1.00") : nil
    }
    func currentAccess() async -> Bool {
        calls += 1
        if suspendAccess { return await withCheckedContinuation { accessContinuation = $0 } }
        return access
    }
    func purchase() async throws -> ProPurchaseResult {
        calls += 1
        if let purchaseError { throw purchaseError }
        if failure { throw Failure.expected }
        if suspendPurchase { return await withCheckedContinuation { purchaseContinuation = $0 } }
        return result
    }
    func restore() async throws {
        calls += 1
        restoreCalls += 1
        if failure { throw Failure.expected }
    }
    func updates() -> AsyncStream<ProDelivery> {
        calls += 1
        return AsyncStream { continuation = $0 }
    }
    func delivery(_ granted: Bool, afterFinish: (() -> Void)? = nil) -> ProDelivery {
        ProDelivery(isGranted: granted, finish: { self.finishes += 1; afterFinish?() })
    }
    enum Failure: Error { case expected }
}

@Suite @MainActor struct ProStoreTests {
    @Test
    func openSourceNeverContactsPurchaseService() async {
        let client = FakeProClient()
        let store = ProStore(distribution: .openSource, client: client)
        await store.start()
        await store.loadProduct()
        await store.refreshAccess()
        await store.purchase()
        await store.restore()
        #expect(client.calls == 0)
    }

    @Test
    func verifiedPurchaseDeliversBeforeFinish() async {
        let client = FakeProClient()
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        client.result = .purchased(client.delivery(true) { #expect(store.hasProAccess) })
        await store.purchase()
        #expect(store.hasProAccess)
        #expect(client.finishes == 1)
        #expect(!store.isBusy)
        client.continuation?.finish()
    }

    @Test
    func cancelledPendingAndFailedPurchasesDoNotUnlock() async {
        let client = FakeProClient()
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(store.messageKey == nil)
        client.result = .pending
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(store.messageKey == "pro.pending")
        client.failure = true
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(store.messageKey == "pro.purchaseError")
        #expect(client.finishes == 0)
        #expect(!store.isBusy)
        client.continuation?.finish()
    }

    @Test(arguments: [false, true])
    func directAndWrappedUserCancellationDoNotShowFailure(wrapped: Bool) async {
        let client = FakeProClient()
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        client.purchaseError = wrapped
            ? StoreKitError.systemError(NSError(domain: SKErrorDomain, code: SKError.paymentCancelled.rawValue))
            : StoreKitError.userCancelled
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(!store.isBusy)
        #expect(store.messageKey == nil)
        client.continuation?.finish()
    }

    @Test
    func restoresAndRevokesAccessWithoutLosingSettings() async {
        let client = FakeProClient()
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        #expect(client.restoreCalls == 0)
        client.access = true
        await store.restore()
        #expect(store.hasProAccess)
        #expect(store.messageKey == "pro.restored")
        client.access = false
        await store.refreshAccess()
        #expect(!store.hasProAccess)
        await store.restore()
        #expect(store.messageKey == "pro.noPurchase")
        client.failure = true
        await store.restore()
        #expect(store.messageKey == "pro.restoreError")
        #expect(!store.isBusy)
        client.continuation?.finish()
    }

    @Test
    func transactionUpdatesGrantAndRevokeAccess() async {
        let client = FakeProClient()
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        client.access = true
        client.continuation?.yield(client.delivery(true))
        for _ in 0..<100 where client.finishes < 1 { await Task.yield() }
        #expect(store.hasProAccess)
        #expect(client.finishes == 1)
        client.access = false
        client.continuation?.yield(client.delivery(false))
        for _ in 0..<100 where client.finishes < 2 { await Task.yield() }
        #expect(!store.hasProAccess)
        #expect(client.finishes == 2)
        client.continuation?.finish()
    }

    @Test
    func verifiedUpdatesOverrideStaleCachedLookups() async {
        let client = FakeProClient()
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        // The query deliberately remains stale for both grant and revocation deliveries.
        client.continuation?.yield(client.delivery(true))
        for _ in 0..<100 where client.finishes < 1 { await Task.yield() }
        #expect(store.hasProAccess)
        client.access = true
        client.continuation?.yield(client.delivery(false))
        for _ in 0..<100 where client.finishes < 2 { await Task.yield() }
        #expect(!store.hasProAccess)
        #expect(client.finishes == 2)
        client.continuation?.finish()
    }

    @Test
    func olderAccessQueryCannotUndoCompletedPurchase() async {
        let client = FakeProClient()
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        client.suspendAccess = true
        let oldQuery = Task { await store.refreshAccess() }
        for _ in 0..<100 where client.accessContinuation == nil { await Task.yield() }
        #expect(client.accessContinuation != nil)
        client.result = .purchased(client.delivery(true))
        await store.purchase()
        client.accessContinuation?.resume(returning: false)
        client.accessContinuation = nil
        await oldQuery.value
        #expect(store.hasProAccess)
        client.result = .cancelled
        client.continuation?.finish()
    }

    @Test
    func concurrentPurchaseAndRestoreDoNotDuplicateRequests() async {
        let client = FakeProClient()
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        client.suspendPurchase = true
        let purchase = Task { await store.purchase() }
        for _ in 0..<100 where client.purchaseContinuation == nil { await Task.yield() }
        #expect(client.purchaseContinuation != nil)
        #expect(store.isBusy)
        let calls = client.calls
        await store.purchase()
        await store.restore()
        #expect(client.calls == calls)
        client.purchaseContinuation?.resume(returning: .cancelled)
        client.purchaseContinuation = nil
        await purchase.value
        #expect(!store.isBusy)
        #expect(!store.hasProAccess)
        client.continuation?.finish()
    }

    @Test
    func unavailableProductDoesNotPreventRestoration() async {
        let client = FakeProClient()
        client.available = false
        client.access = true
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        #expect(store.hasProAccess)
        #expect(store.product == nil)
        await store.restore()
        #expect(store.hasProAccess)
        #expect(store.messageKey == "pro.restored")
        client.continuation?.finish()
    }

    @Test
    func productLookupCanRecoverAfterFailure() async {
        let client = FakeProClient()
        client.failure = true
        let store = ProStore(distribution: .appStore, client: client)
        await store.start()
        #expect(store.product == nil)
        #expect(store.messageKey == "pro.loadError")
        client.failure = false
        await store.loadProduct()
        #expect(store.product?.displayPrice == "$1.00")
        #expect(store.messageKey == nil)
        client.continuation?.finish()
    }
}

/// Uses Apple's local StoreKit environment, without App Store Connect products or real charges.
@Suite(.serialized, .timeLimit(.minutes(1))) @MainActor struct NativeProPurchaseTests {
    @Test
    func purchaseRestoreAndRefundUseVerifiedStoreKitTransactions() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Pro
            .deletingLastPathComponent() // AlertivityTests
            .deletingLastPathComponent() // Repository root
        let session = try SKTestSession(contentsOf: root.appendingPathComponent("StoreKit/Alertivity.storekit"))
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        let store = ProStore(distribution: .appStore)
        await store.start()
        #expect(!store.hasProAccess)
        try #require(store.product != nil)
        await store.purchase()
        try #require(store.hasProAccess)
        let transactions = session.allTransactions()
        #expect(transactions.count == 1)
        let reloaded = ProStore(distribution: .appStore)
        await reloaded.start()
        for _ in 0..<100 {
            await reloaded.refreshAccess()
            if reloaded.hasProAccess { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try #require(reloaded.hasProAccess)
        await reloaded.restore()
        #expect(reloaded.hasProAccess)
        let transaction = try #require(transactions.first)
        try session.refundTransaction(identifier: transaction.identifier)
        // Refund updates are asynchronous; bound the wait and explicitly refresh from StoreKit.
        for _ in 0..<100 {
            await reloaded.refreshAccess()
            if !reloaded.hasProAccess { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!reloaded.hasProAccess)
    }

    private func makeSession() throws -> SKTestSession {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Pro
            .deletingLastPathComponent() // AlertivityTests
            .deletingLastPathComponent() // Repository root
        let session = try SKTestSession(contentsOf: root.appendingPathComponent("StoreKit/Alertivity.storekit"))
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    /// Approval/interruption tests wait for actual updates; refunds also exercise activation refresh.
    private func waitForAccess(_ expected: Bool, in store: ProStore, refreshing: Bool = false) async throws {
        for _ in 0..<100 {
            if refreshing { await store.refreshAccess() }
            if store.hasProAccess == expected { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(store.hasProAccess == expected)
    }

    @Test(arguments: [true, false])
    func askToBuyRequiresApproval(approve: Bool) async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let store = ProStore(distribution: .appStore)
        await store.start()
        try #require(store.product != nil)
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(store.messageKey == "pro.pending")
        #expect(!store.isBusy)
        let transaction = try #require(session.allTransactions().first)
        if approve {
            try session.approveAskToBuyTransaction(identifier: transaction.identifier)
            try await waitForAccess(true, in: store)
        } else {
            try session.declineAskToBuyTransaction(identifier: transaction.identifier)
            await store.refreshAccess()
            #expect(!store.hasProAccess)
        }
    }

    @Test
    func cancellationInjectionDoesNotUnlockAndCanRetry() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = ProStore(distribution: .appStore)
        await store.start()
        try #require(store.product != nil)
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(!store.isBusy)
        // On macOS 27 the local service maps this injection to ASDServerErrorDomain 907,
        // which StoreKit reports as unknown. Never suppress a real unknown failure as cancellation.
        #expect(store.messageKey == nil || store.messageKey == "pro.purchaseError")
        try await session.setSimulatedError(nil, forAPI: .purchase)
        await store.purchase()
        #expect(store.hasProAccess)
    }

    @Test
    func purchaseFailureCanBeRetried() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = ProStore(distribution: .appStore)
        await store.start()
        try #require(store.product != nil)
        try await session.setSimulatedError(.purchase(.purchaseNotAllowed), forAPI: .purchase)
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(store.messageKey == "pro.purchaseError")
        #expect(!store.isBusy)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        await store.purchase()
        #expect(store.hasProAccess)
    }

    @Test
    func productLookupAndRestoreFailuresCanRecover() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let store = ProStore(distribution: .appStore)
        await store.start()
        #expect(store.product == nil)
        #expect(store.messageKey == "pro.loadError")
        #expect(!store.isBusy)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.loadProduct()
        try #require(store.product != nil)
        await store.restore()
        #expect(!store.hasProAccess)
        #expect(store.messageKey == "pro.noPurchase")
        await store.purchase()
        try #require(store.hasProAccess)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        await store.restore()
        #expect(store.hasProAccess)
        #expect(store.messageKey == "pro.restoreError")
        #expect(!store.isBusy)
        try await session.setSimulatedError(nil, forAPI: .appStoreSync)
        await store.restore()
        #expect(store.messageKey == "pro.restored")
    }

    @Test
    func invalidSignatureNeverGrantsAccess() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = ProStore(distribution: .appStore)
        await store.start()
        try #require(store.product != nil)
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(store.messageKey == "pro.purchaseError")
        await store.refreshAccess()
        #expect(!store.hasProAccess)
        try await session.setSimulatedError(nil, forAPI: .verification)
        await store.restore()
        #expect(store.hasProAccess)
    }

    @Test
    func interruptedPurchaseUnlocksAfterResolution() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.interruptedPurchasesEnabled = true
        let store = ProStore(distribution: .appStore)
        await store.start()
        try #require(store.product != nil)
        await store.purchase()
        #expect(!store.hasProAccess)
        #expect(!store.isBusy)
        let transaction = try #require(session.allTransactions().first)
        session.interruptedPurchasesEnabled = false
        try session.resolveIssueForTransaction(identifier: transaction.identifier)
        try await waitForAccess(true, in: store)
    }

    @Test
    func refundAndRepurchasePreserveCustomPreferences() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let suite = "AL79.StoreKit.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(userDefaults: defaults, distribution: .appStore)
        settings.notificationCooldownMinutes = 30
        settings.highActivityDurationSeconds = 240
        let store = ProStore(distribution: .appStore)
        await store.start()
        try #require(store.product != nil)
        await store.purchase()
        try #require(store.hasProAccess)
        settings.setProAccess(store.hasProAccess)
        #expect(settings.monitoringConfiguration.cooldownMinutes == 30)
        #expect(settings.monitoringConfiguration.durationSeconds == 240)
        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        // Model returning to the app after a refund: the local test service doesn't emit
        // a refund update here, while app activation rechecks the latest verified transaction.
        try await waitForAccess(false, in: store, refreshing: true)
        settings.setProAccess(store.hasProAccess)
        #expect(settings.monitoringConfiguration.cooldownMinutes == 10)
        #expect(settings.monitoringConfiguration.durationSeconds == 60)
        #expect(settings.notificationCooldownMinutes == 30)
        #expect(settings.highActivityDurationSeconds == 240)
        await store.purchase()
        try #require(store.hasProAccess)
        settings.setProAccess(store.hasProAccess)
        #expect(settings.monitoringConfiguration.cooldownMinutes == 30)
        #expect(settings.monitoringConfiguration.durationSeconds == 240)
    }

}
