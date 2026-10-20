import AppKit
import StoreKit
import SwiftUI

/// App-wide command opening Apple's product-page deep link, independently of automatic eligibility.
struct WriteReviewButton: View {
    let store: ReviewRequestStore

    var body: some View {
        Button("menu.writeReview") {
            if NSWorkspace.shared.open(ReviewRequestStore.reviewURL) {
                store.recordManualReviewOpened(version: Bundle.main.reviewVersion)
            } else {
                AppLogger.reviews.error("Failed to open App Store review destination")
                // Commands have no content-view presentation anchor. Use a native alert for failure.
                let alert = NSAlert()
                alert.messageText = L10n.string("settings.reviews.openError")
                alert.addButton(withTitle: L10n.string("settings.reviews.dismiss"))
                NSApp.activate()
                if let window = NSApp.keyWindow {
                    alert.beginSheetModal(for: window)
                } else {
                    alert.runModal()
                }
            }
        }
    }
}

/// Limits automatic presentation to the General pane, after inactivity in a real settings window.
/// Pending onboarding and explicit replay also block requests, including while Settings is key.
/// AppKit supplies local input and window/modal state that SwiftUI does not expose directly.
struct AutomaticReviewRequest: ViewModifier {
    let store: ReviewRequestStore
    let hasLiveData: Bool
    let isCritical: Bool
    let isGeneralSelected: Bool
    let isOnboardingActive: Bool
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var interactionGeneration = 0
    @State private var inputMonitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard inputMonitor == nil else { return }
                inputMonitor = NSEvent.addLocalMonitorForEvents(
                    matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown,
                               .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                               .keyDown, .scrollWheel]
                ) { event in
                    interactionGeneration += 1
                    return event
                }
            }
            .onDisappear {
                if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
                inputMonitor = nil
            }
            .task(id: RequestContext(interaction: interactionGeneration, phase: scenePhase,
                                     live: hasLiveData, critical: isCritical, general: isGeneralSelected,
                                     onboarding: isOnboardingActive)) {
                // Debug and standalone builds must never contact StoreKit automatically.
#if !DEBUG
                guard Bundle.main.bundleIdentifier == "com.Nobby.Alertivity",
                      isGeneralSelected, !isOnboardingActive, hasLiveData, !isCritical, scenePhase == .active else { return }
                do {
                    try await Task.sleep(for: .seconds(30))
                    guard safeToPresent else { return }
                    let decision = store.decision(version: Bundle.main.reviewVersion)
                    AppLogger.reviews.debug("Review eligibility decision=\(decision.rawValue, privacy: .public)")
                    guard decision == .eligible else { return }
                    // Modern signed app-transaction verification excludes TestFlight and local builds.
                    guard case .verified(let transaction) = try await AppTransaction.shared,
                          transaction.environment == .production,
                          transaction.bundleID == "com.Nobby.Alertivity",
                          transaction.appID == 6756399719 else {
                        AppLogger.reviews.info("Review request deferred; production App Store install unverified")
                        return
                    }
                    try Task.checkCancellation()
                    guard safeToPresent else { return }
                    store.requestIfEligible(version: Bundle.main.reviewVersion) { requestReview() }
                } catch is CancellationError {
                    // Leaving General, interacting, or changing status cancels the waiting period.
                } catch {
                    let failure = error as NSError
                    AppLogger.reviews.error("Review request deferred; transaction error domain=\(failure.domain, privacy: .public) code=\(failure.code)")
                }
#endif
            }
    }

    private var safeToPresent: Bool {
        NSApp.isActive && NSApp.keyWindow != nil && NSApp.keyWindow === SettingsWindowTracker.shared.window
            && NSApp.keyWindow?.attachedSheet == nil && NSApp.modalWindow == nil
    }

    private struct RequestContext: Equatable {
        let interaction: Int
        let phase: ScenePhase
        let live: Bool
        let critical: Bool
        let general: Bool
        let onboarding: Bool
    }
}

extension Bundle {
    var reviewVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
