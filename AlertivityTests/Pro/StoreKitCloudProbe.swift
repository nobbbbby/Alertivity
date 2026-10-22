import AppKit
import CoreGraphics
import Foundation
import OSLog
import StoreKit
import StoreKitTest
import XCTest

private final class StoreKitProbeBundle: NSObject {}

/// Opt-in reproduction that bypasses ProStore and runs alone in the StoreKitProbe test plan.
@MainActor
final class StoreKitCloudProbe: XCTestCase {
    private static let logger = Logger(subsystem: "com.Nobby.Alertivity.tests", category: "storekit-probe")

    func testDirectProductPurchase() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ALERTIVITY_STOREKIT_PROBE"] == "1")
        executionTimeAllowance = 60
        logPresentationState("before session")
        let configuration = try XCTUnwrap(
            Bundle(for: StoreKitProbeBundle.self).url(forResource: "Alertivity", withExtension: "storekit")
        )
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        XCTAssertTrue(session.disableDialogs)

        Self.logger.notice("Probe: Product.products started")
        let products = try await Product.products(for: ["com.Nobby.Alertivity.pro"])
        let product = try XCTUnwrap(products.first { $0.id == "com.Nobby.Alertivity.pro" })
        Self.logger.notice("Probe: Product.products returned")
        logPresentationState("before purchase")

        // Inspect the session while the SDK is suspended, without interacting with its UI.
        let watchdog = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(10))
                logPresentationState("purchase still pending after 10 seconds")
                try await Task.sleep(for: .seconds(30))
                logPresentationState("purchase still pending after 40 seconds")
            } catch { /* Successful completion cancels the diagnostic watchdog. */ }
        }
        defer { watchdog.cancel() }

        Self.logger.notice("Probe: Product.purchase started")
        let result = try await product.purchase()
        Self.logger.notice("Probe: Product.purchase returned")
        guard case .success(.verified(let transaction)) = result else {
            XCTFail("Direct StoreKit purchase did not return a verified transaction.")
            return
        }
        XCTAssertEqual(transaction.productID, product.id)
        let environment = String(describing: transaction.environment)
        Self.logger.notice("Probe: verified transaction environment: \(environment, privacy: .public)")
        await transaction.finish()
        Self.logger.notice("Probe: transaction finished")
    }

    /// Owner names reveal system UI without exposing window titles or account information.
    private func logPresentationState(_ stage: String) {
        let app = NSApplication.shared
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        let owners = windows.map { entries in
            Set(entries.compactMap { $0[kCGWindowOwnerName as String] as? String }).sorted().joined(separator: ",")
        } ?? "unavailable"
        let host = Bundle.main.bundleIdentifier ?? "unknown"
        Self.logger.notice("Probe state: \(stage, privacy: .public); host: \(host, privacy: .public); uid: \(getuid()); active: \(app.isActive); activationPolicy: \(app.activationPolicy().rawValue); keyWindow: \(app.keyWindow != nil); visibleAppWindows: \(app.windows.filter(\.isVisible).count); onScreenOwners: \(owners, privacy: .public)")
    }
}
