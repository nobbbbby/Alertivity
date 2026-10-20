import Foundation
import Testing
@testable import Alertivity

@Suite @MainActor struct ReviewRequestStoreTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 86_400

    private func withStore(_ test: (ReviewRequestStore, UserDefaults) -> Void) {
        let name = "review-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        test(ReviewRequestStore(defaults: defaults), defaults)
    }

    private func qualify(_ store: ReviewRequestStore) {
        for offset in 0..<3 { store.recordMonitoring(at: start.addingTimeInterval(Double(offset) * day)) }
    }

    @Test func requiresThreeDistinctDaysAndSevenDaysOfUse() {
        withStore { store, _ in
            #expect(store.decision(version: "1", at: start) == .insufficientUsage)
            for _ in 0..<10 { store.recordMonitoring(at: start) }
            #expect(store.decision(version: "1", at: start.addingTimeInterval(8 * day)) == .insufficientUsage)
            qualify(store)
            #expect(store.decision(version: "1", at: start.addingTimeInterval(7 * day - 1)) == .tooEarly)
            #expect(store.decision(version: "1", at: start.addingTimeInterval(7 * day)) == .eligible)
            #expect(store.decision(version: "", at: start.addingTimeInterval(7 * day)) == .missingVersion)
        }
    }

    @Test func usageAndAttemptsSurviveRelaunchEvenWhenNoPromptAppears() {
        withStore { store, defaults in
            qualify(store)
            let eligibleDate = start.addingTimeInterval(7 * day)
            let reloaded = ReviewRequestStore(defaults: defaults)
            var calls = 0
            #expect(reloaded.requestIfEligible(version: "1", at: eligibleDate) { calls += 1 })
            let relaunched = ReviewRequestStore(defaults: defaults)
            #expect(!relaunched.requestIfEligible(version: "1", at: eligibleDate) { calls += 1 })
            #expect(calls == 1)
            #expect(relaunched.decision(version: "1", at: eligibleDate.addingTimeInterval(400 * day)) == .versionAlreadyRequested)
            #expect(relaunched.decision(version: "2", at: eligibleDate.addingTimeInterval(120 * day - 1)) == .cooldown)
            #expect(relaunched.decision(version: "2", at: eligibleDate.addingTimeInterval(120 * day)) == .eligible)
            #expect(relaunched.requestIfEligible(version: "2", at: eligibleDate.addingTimeInterval(120 * day)) { calls += 1 })
            // Installing an older version must not reset its per-version limit.
            #expect(ReviewRequestStore(defaults: defaults).decision(version: "1", at: eligibleDate.addingTimeInterval(240 * day)) == .versionAlreadyRequested)
        }
    }

    @Test func reservesAttemptBeforeCallingStoreKit() {
        withStore { store, defaults in
            qualify(store)
            let date = start.addingTimeInterval(7 * day)
            store.requestIfEligible(version: "1", at: date) {
                #expect(ReviewRequestStore(defaults: defaults).decision(version: "1", at: date) == .versionAlreadyRequested)
            }
        }
    }

    @Test func ineligibleRequestDoesNotCallStoreKit() {
        withStore { store, _ in
            var calls = 0
            #expect(!store.requestIfEligible(version: "1", at: start) { calls += 1 })
            #expect(calls == 0)
        }
    }

    @Test func manualReviewSuppressesAutomaticAttemptsAcrossVersions() {
        withStore { store, defaults in
            qualify(store)
            let date = start.addingTimeInterval(7 * day)
            store.recordManualReviewOpened(version: "1", at: date)
            let reloaded = ReviewRequestStore(defaults: defaults)
            #expect(reloaded.decision(version: "1", at: date) == .versionAlreadyRequested)
            #expect(reloaded.decision(version: "2", at: date.addingTimeInterval(day)) == .cooldown)
        }
    }

    @Test func clockRollbackDoesNotBypassWaitingPeriods() {
        withStore { store, _ in
            qualify(store)
            #expect(store.decision(version: "1", at: start.addingTimeInterval(-day)) == .tooEarly)
            store.recordManualReviewOpened(version: "1", at: start.addingTimeInterval(7 * day))
            #expect(store.decision(version: "2", at: start.addingTimeInterval(6 * day)) == .tooEarly)
            #expect(store.decision(version: "2", at: start.addingTimeInterval(7 * day)) == .cooldown)
        }
    }

    @Test func corruptStateRestartsQualification() {
        withStore { _, defaults in
            defaults.set(Data("invalid".utf8), forKey: "reviews.usageAndAttempts.v1")
            let store = ReviewRequestStore(defaults: defaults)
            store.recordMonitoring(at: start)
            #expect(store.decision(version: "1", at: start.addingTimeInterval(8 * day)) == .insufficientUsage)
        }
    }

    @Test func reviewDestinationMatchesPublishedProduct() {
        let parts = URLComponents(url: ReviewRequestStore.reviewURL, resolvingAgainstBaseURL: false)
        #expect(parts?.scheme == "https")
        #expect(parts?.host == "apps.apple.com")
        #expect(parts?.path == "/app/id6756399719")
        #expect(parts?.queryItems == [URLQueryItem(name: "action", value: "write-review")])
    }

    @Test func recordsLiveSamplesWithoutAMenuView() {
        withStore { store, defaults in
            let monitor = ActivityMonitor(autoStart: false)
            store.startRecordingUsage(from: monitor)
            #expect(defaults.data(forKey: "reviews.usageAndAttempts.v1") == nil)
            monitor.ingest(metrics: .previewCritical)
            #expect(defaults.data(forKey: "reviews.usageAndAttempts.v1") != nil)
            let saved = defaults.data(forKey: "reviews.usageAndAttempts.v1")
            monitor.ingest(metrics: .previewNormal)
            #expect(defaults.data(forKey: "reviews.usageAndAttempts.v1") == saved)
        }
    }

    @Test func rollbackCannotAddAnotherQualifyingDay() {
        withStore { store, _ in
            store.recordMonitoring(at: start)
            store.recordMonitoring(at: start.addingTimeInterval(day))
            store.recordMonitoring(at: start.addingTimeInterval(-day))
            #expect(store.decision(version: "1", at: start.addingTimeInterval(8 * day)) == .insufficientUsage)
        }
    }
}
