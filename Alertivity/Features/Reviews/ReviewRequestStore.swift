import Combine
import Foundation
import OSLog

/// Persists usage milestones and request attempts, never an assumed prompt display or review outcome.
@MainActor
final class ReviewRequestStore: ObservableObject {
    static let reviewURL = URL(string: "https://apps.apple.com/app/id6756399719?action=write-review")!
    static let minimumAge: TimeInterval = 7 * 24 * 60 * 60
    static let requestInterval: TimeInterval = 120 * 24 * 60 * 60

    enum Decision: String {
        case eligible, insufficientUsage, tooEarly, versionAlreadyRequested, cooldown, missingVersion
    }

    private struct State: Codable {
        var firstUse: Date?
        var monitoringDays: [Date] = []
        var lastAttempt: Date?
        var attemptedVersions: Set<String> = []
    }

    private static let key = "reviews.usageAndAttempts.v1"
    private let defaults: UserDefaults
    private var state: State
    private var monitoringSubscription: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            do {
                state = try JSONDecoder().decode(State.self, from: data)
            } catch {
                // Restart the full usage waiting period if state cannot be trusted.
                state = State()
                AppLogger.reviews.error("Review state unreadable; restarting usage qualification")
            }
        } else {
            state = State()
        }
    }

    /// Retained by the app-owned store so hiding the menu icon cannot stop usage qualification.
    /// ActivityMonitor delivers its published samples on the main thread.
    func startRecordingUsage(from monitor: ActivityMonitor) {
        guard monitoringSubscription == nil else { return }
        monitoringSubscription = monitor.$metrics.sink { [weak self] metrics in
            if metrics.hasLiveData { self?.recordMonitoring() }
        }
    }

    /// Called only for live monitoring samples, regardless of severity or notification preferences.
    /// UTC day boundaries avoid adding usage days when a customer changes their time zone.
    func recordMonitoring(at date: Date = .now) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.startOfDay(for: date)
        // A backwards clock change must not inflate usage or cause per-sample writes and logs.
        guard state.monitoringDays.last.map({ day > $0 }) ?? true else { return }
        if state.firstUse == nil { state.firstUse = date }
        state.monitoringDays = Array((state.monitoringDays + [day]).sorted().suffix(3))
        persist()
        AppLogger.reviews.info("Review usage day recorded; qualifyingDays=\(self.state.monitoringDays.count)")
    }

    func decision(version: String, at date: Date = .now) -> Decision {
        guard !version.isEmpty else { return .missingVersion }
        guard let firstUse = state.firstUse, state.monitoringDays.count >= 3 else { return .insufficientUsage }
        guard date.timeIntervalSince(firstUse) >= Self.minimumAge else { return .tooEarly }
        guard !state.attemptedVersions.contains(version) else { return .versionAlreadyRequested }
        if let last = state.lastAttempt, date.timeIntervalSince(last) < Self.requestInterval { return .cooldown }
        return .eligible
    }

    /// Save before calling StoreKit so a suppressed prompt, a relaunch, or another view cannot retry it.
    @discardableResult
    func requestIfEligible(version: String, at date: Date = .now, request: () -> Void) -> Bool {
        let decision = decision(version: version, at: date)
        AppLogger.reviews.info("Review eligibility decision=\(decision.rawValue, privacy: .public)")
        guard decision == .eligible else { return false }
        recordAttempt(version: version, at: date)
        AppLogger.reviews.info("Requesting StoreKit review; presentation and outcome are system controlled")
        request()
        return true
    }

    /// Manual access stays available at any time, but also delays the next automatic request.
    func recordManualReviewOpened(version: String, at date: Date = .now) {
        recordAttempt(version: version, at: date)
        AppLogger.reviews.info("App Store review link opened; review outcome unknown")
    }

    private func recordAttempt(version: String, at date: Date) {
        state.lastAttempt = date
        state.attemptedVersions.insert(version)
        persist()
    }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(state), forKey: Self.key)
        } catch {
            AppLogger.reviews.error("Failed to encode review state")
        }
    }
}
