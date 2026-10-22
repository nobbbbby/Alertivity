import Combine
import Foundation
import StoreKit

struct ProProduct {
    let displayPrice: String
}

/// A verified delivery retains its StoreKit completion until access has been applied.
struct ProDelivery {
    let isGranted: Bool
    let finish: () async -> Void
}

enum ProPurchaseResult {
    case purchased(ProDelivery), pending, cancelled
}

@MainActor
protocol ProPurchasing {
    func loadProduct() async throws -> ProProduct?
    func currentAccess() async -> Bool
    func purchase() async throws -> ProPurchaseResult
    func restore() async throws
    func updates() -> AsyncStream<ProDelivery>
}

/// StoreKit is the sole authority for App Store access; no entitlement is trusted from UserDefaults.
@MainActor
final class ProStore: ObservableObject {
    static let productID = "com.Nobby.Alertivity.pro"

    @Published private(set) var hasProAccess = false
    @Published private(set) var product: ProProduct?
    @Published private(set) var isBusy = false
    @Published private(set) var messageKey: String?
    private let distribution: AppDistribution
    private let client: any ProPurchasing
    private var updatesTask: Task<Void, Never>?
    private var refreshGeneration = 0

    init(distribution: AppDistribution = .current, client: (any ProPurchasing)? = nil) {
        self.distribution = distribution
        self.client = client ?? StoreKitProClient()
    }

    deinit { updatesTask?.cancel() }

    func start() async {
        guard distribution == .appStore else { return }
        if updatesTask == nil {
            let updates = client.updates()
            updatesTask = Task { [weak self] in
                for await delivery in updates {
                    guard !Task.isCancelled, let self else { break }
                    // A verified update is authoritative; a separate lookup may still return cached
                    // pre-refund data. Invalidate older lookups before delivering this transaction.
                    self.refreshGeneration += 1
                    self.applyAccess(delivery.isGranted)
                    await delivery.finish()
                }
            }
        }
        await refreshAccess()
        if product == nil { await loadProduct() }
    }

    func refreshAccess() async {
        guard distribution == .appStore else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        let granted = await client.currentAccess()
        guard generation == refreshGeneration else { return }
        applyAccess(granted)
    }

    func loadProduct() async {
        guard distribution == .appStore, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        messageKey = nil
        do {
            product = try await client.loadProduct()
            if product == nil { messageKey = "pro.unavailable" }
            AppLogger.purchases.info("Pro product lookup completed; available: \(self.product != nil, privacy: .public)")
        } catch {
            messageKey = "pro.loadError"
            log(error, operation: "product lookup")
        }
    }

    func purchase() async {
        guard distribution == .appStore, !isBusy, !hasProAccess, product != nil else { return }
        isBusy = true
        messageKey = nil
        defer { isBusy = false }
        AppLogger.purchases.info("Pro purchase started")
        do {
            switch try await client.purchase() {
            case .purchased(let delivery):
                refreshGeneration += 1 // Invalidate any older entitlement query still in flight.
                applyAccess(delivery.isGranted)
                await delivery.finish()
            case .pending:
                messageKey = "pro.pending"
                AppLogger.purchases.info("Pro purchase pending approval")
            case .cancelled:
                AppLogger.purchases.info("Pro purchase cancelled")
            }
        } catch {
            if Self.isUserCancellation(error) {
                AppLogger.purchases.info("Pro purchase cancelled")
            } else {
                messageKey = "pro.purchaseError"
                log(error, operation: "purchase")
            }
        }
    }

    /// Explicit user action only: StoreKit sync may prompt for App Store authentication.
    func restore() async {
        guard distribution == .appStore, !isBusy else { return }
        isBusy = true
        messageKey = nil
        defer { isBusy = false }
        AppLogger.purchases.info("Pro restore started")
        do {
            try await client.restore()
            await refreshAccess()
            messageKey = hasProAccess ? "pro.restored" : "pro.noPurchase"
        } catch {
            messageKey = "pro.restoreError"
            log(error, operation: "restore")
        }
    }

    /// StoreKit can report cancellation directly or wrap the original payment cancellation.
    private static func isUserCancellation(_ error: Error, depth: Int = 0) -> Bool {
        guard depth < 4 else { return false }
        if let storeError = error as? StoreKitError {
            switch storeError {
            case .userCancelled: return true
            case .systemError(let underlying):
                return isUserCancellation(underlying, depth: depth + 1)
            default: break
            }
        }
        let failure = error as NSError
        if failure.domain == SKErrorDomain, failure.code == SKError.paymentCancelled.rawValue { return true }
        if let underlying = failure.userInfo[NSUnderlyingErrorKey] as? Error {
            return isUserCancellation(underlying, depth: depth + 1)
        }
        return false
    }

    private func applyAccess(_ granted: Bool) {
        guard hasProAccess != granted else { return }
        hasProAccess = granted
        messageKey = nil
        AppLogger.purchases.info("Verified Pro access changed; granted: \(granted, privacy: .public)")
    }

    private func log(_ error: Error, operation: String) {
        let failure = error as NSError
        AppLogger.purchases.error("StoreKit operation failed; operation: \(operation, privacy: .public) domain: \(failure.domain, privacy: .public) code: \(failure.code)")
        if let storeError = error as? StoreKitError, case .systemError(let underlying) = storeError {
            let cause = underlying as NSError
            AppLogger.purchases.error("StoreKit system failure cause; domain: \(cause.domain, privacy: .public) code: \(cause.code)")
        }
    }
}

@MainActor
private final class StoreKitProClient: ProPurchasing {
    private var product: Product?

    func loadProduct() async throws -> ProProduct? {
        product = try await Product.products(for: [ProStore.productID])
            .first { $0.id == ProStore.productID && $0.type == .nonConsumable }
        return product.map { ProProduct(displayPrice: $0.displayPrice) }
    }

    func currentAccess() async -> Bool {
        // Pro is one permanent product. Its latest verified transaction is authoritative,
        // including after relaunch; history can include refunds, so inspect revocation explicitly.
        guard let result = await Transaction.latest(for: ProStore.productID) else { return false }
        guard case .verified(let transaction) = result else {
            AppLogger.purchases.error("Ignoring unverified Pro transaction")
            return false
        }
        return transaction.productID == ProStore.productID
            && transaction.productType == .nonConsumable
            && transaction.revocationDate == nil
    }

    func purchase() async throws -> ProPurchaseResult {
        guard let product else { throw PurchaseError.unavailable }
        // Separate the SDK wait from verification and delivery when diagnosing stalled purchases.
        let clock = ContinuousClock()
        let started = clock.now
        AppLogger.purchases.info("StoreKit Product.purchase request started")
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            let elapsed = String(describing: started.duration(to: clock.now))
            AppLogger.purchases.info("StoreKit Product.purchase request threw; elapsed: \(elapsed, privacy: .public)")
            throw error
        }
        let elapsed = String(describing: started.duration(to: clock.now))
        AppLogger.purchases.info("StoreKit Product.purchase request returned; elapsed: \(elapsed, privacy: .public)")
        switch result {
        case .success(let result):
            if case .unverified(_, let error) = result {
                let failure = error as NSError
                AppLogger.purchases.error("Transaction verification failed; domain: \(failure.domain, privacy: .public) code: \(failure.code)")
            }
            guard case .verified(let transaction) = result,
                  transaction.productID == ProStore.productID,
                  transaction.productType == .nonConsumable,
                  transaction.revocationDate == nil else {
                throw PurchaseError.unverified
            }
            return .purchased(ProDelivery(isGranted: true, finish: { await transaction.finish() }))
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw PurchaseError.unknown
        }
    }

    func restore() async throws { try await AppStore.sync() }

    func updates() -> AsyncStream<ProDelivery> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    guard case .verified(let transaction) = result else {
                        AppLogger.purchases.error("Ignoring unverified transaction update")
                        continue
                    }
                    guard transaction.productID == ProStore.productID,
                          transaction.productType == .nonConsumable else { continue }
                    AppLogger.purchases.info("Verified Pro transaction update received; revoked: \(transaction.revocationDate != nil, privacy: .public)")
                    continuation.yield(ProDelivery(
                        isGranted: transaction.revocationDate == nil,
                        finish: { await transaction.finish() }
                    ))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private enum PurchaseError: Error { case unavailable, unverified, unknown }
}
