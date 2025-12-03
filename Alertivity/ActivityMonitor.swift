import Combine
import Foundation

protocol SystemMetricsProviding {
    var highActivityDuration: TimeInterval { get set }
    var highActivityCPUThreshold: Double { get set }
    var highActivityMemoryThreshold: Double { get set }
    func fetchMetrics() -> ActivityMetrics
}

extension SystemMetricsProvider: SystemMetricsProviding {}

final class ActivityMonitor: ObservableObject {
    @Published private(set) var metrics: ActivityMetrics = .placeholder
    @Published private(set) var status: ActivityStatus = .normal

    private var provider: SystemMetricsProviding
    private var timer: Timer?
    private let queue: DispatchQueue = DispatchQueue(label: "activity-monitor.queue")
    private var isMonitoring = false
    private var pendingStatus: ActivityStatus?
    private var pendingStatusSamples: Int = 0

    init(
        metrics: ActivityMetrics = .placeholder,
        status: ActivityStatus = .normal,
        autoStart: Bool = true,
        interval: TimeInterval = 5,
        provider: SystemMetricsProviding = SystemMetricsProvider(),
        highActivityDuration: TimeInterval = 120
    ) {
        self.provider = provider
        self.provider.highActivityDuration = highActivityDuration
        _metrics = Published(initialValue: metrics)
        _status = Published(initialValue: status)
        if autoStart { startMonitoring(interval: interval) }
    }

    func startMonitoring(interval: TimeInterval = 5) {
        stopMonitoring()
        guard interval > 0 else { return }
        isMonitoring = true

        fetchMetricsOnce()

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchMetricsOnce()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    /// Test helper to apply a metrics snapshot without scheduling or timers.
    func ingest(metrics: ActivityMetrics) {
        update(with: metrics)
    }

    private func update(with metrics: ActivityMetrics) {
        self.metrics = metrics
        let candidateStatus = ActivityStatus(metrics: metrics)
        self.status = resolveStatusTransition(to: candidateStatus)
    }

    private func fetchMetricsOnce() {
        queue.async { [weak self] in
            guard let self else { return }
            let metrics = self.provider.fetchMetrics()
            DispatchQueue.main.async {
                self.update(with: metrics)
            }
        }
    }

    var highActivityDuration: TimeInterval {
        get { provider.highActivityDuration }
        set { provider.highActivityDuration = newValue }
    }

    var highActivityCPUThreshold: Double {
        get { provider.highActivityCPUThreshold }
        set { provider.highActivityCPUThreshold = max(0, min(1, newValue)) }
    }

    var highActivityMemoryThreshold: Double {
        get { provider.highActivityMemoryThreshold }
        set { provider.highActivityMemoryThreshold = max(0, min(1, newValue)) }
    }

    private func resolveStatusTransition(to candidate: ActivityStatus) -> ActivityStatus {
        // If the level is unchanged, accept the new status immediately (allows trigger updates without delay).
        if candidate.level == status.level {
            pendingStatus = nil
            pendingStatusSamples = 0
            return candidate
        }

        if pendingStatus == candidate {
            pendingStatusSamples += 1
        } else {
            pendingStatus = candidate
            pendingStatusSamples = 1
        }

        if pendingStatusSamples >= 2 {
            pendingStatus = nil
            pendingStatusSamples = 0
            return candidate
        } else {
            return status
        }
    }
}
