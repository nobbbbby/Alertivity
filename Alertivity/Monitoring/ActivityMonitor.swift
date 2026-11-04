import Combine
import Foundation

protocol SystemMetricsProviding {
    var highActivityDuration: TimeInterval { get set }
    var highActivityCPUThreshold: Double { get set }
    var highActivityMemoryThreshold: Double { get set }
    var ignoredProcessPaths: Set<String> { get set }
    var processSamplingAvailable: Bool { get }
    func fetchMetrics() -> ActivityMetrics
}

extension SystemMetricsProvider: SystemMetricsProviding {}

final class ActivityMonitor: ObservableObject {
    @Published private(set) var metrics: ActivityMetrics = .placeholder
    @Published private(set) var status: ActivityStatus = .normal
    @Published private(set) var processSamplingAvailable: Bool = true

    private var provider: SystemMetricsProviding
    private var timer: Timer?
    private let queue: DispatchQueue = DispatchQueue(label: "activity-monitor.queue")
    private(set) var isMonitoring = false
    private(set) var samplingInterval = MonitoringPreferences.defaultSamplingInterval
    private let scheduleTimer: (TimeInterval, @escaping () -> Void) -> Timer
    private var isFetching = false
    private var monitoringGeneration = 0
    private var pendingStatus: ActivityStatus?
    private var pendingStatusSamples: Int = 0
    var activityThresholds: ActivityThresholds = .default {
        didSet { update(with: metrics) }
    }

    init(
        metrics: ActivityMetrics = .placeholder,
        status: ActivityStatus = .normal,
        autoStart: Bool = true,
        interval: TimeInterval = 5,
        provider: SystemMetricsProviding = SystemMetricsProvider(),
        highActivityDuration: TimeInterval = 60,
        scheduleTimer: @escaping (TimeInterval, @escaping () -> Void) -> Timer = { interval, action in
            let timer = Timer(timeInterval: interval, repeats: true) { _ in action() }
            RunLoop.main.add(timer, forMode: .common)
            return timer
        }
    ) {
        self.scheduleTimer = scheduleTimer
        self.samplingInterval = MonitoringPreferences.normalizedSamplingInterval(interval)
        self.provider = provider
        self.provider.highActivityDuration = highActivityDuration
        _metrics = Published(initialValue: metrics)
        _status = Published(initialValue: status)
        if autoStart { startMonitoring(interval: interval) }
    }

    func startMonitoring(interval: TimeInterval = 5) {
        stopMonitoring()
        samplingInterval = MonitoringPreferences.normalizedSamplingInterval(interval)
        isMonitoring = true
        fetchMetricsOnce()
        installTimer()
    }

    /// Replace only the schedule: retained provider snapshots keep rates based on actual elapsed time.
    func setSamplingInterval(_ interval: TimeInterval) {
        let normalized = MonitoringPreferences.normalizedSamplingInterval(interval)
        guard samplingInterval != normalized else { return }
        samplingInterval = normalized
        pendingStatus = nil
        pendingStatusSamples = 0
        if isMonitoring { installTimer() }
        AppLogger.metrics.info("Monitor sampling interval applied; seconds: \(normalized, privacy: .public)")
    }

    private func installTimer() {
        timer?.invalidate()
        timer = scheduleTimer(samplingInterval) { [weak self] in
            guard let self, self.isMonitoring else { return }
            self.fetchMetricsOnce()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        monitoringGeneration += 1
    }

    /// Test helper to apply a metrics snapshot without scheduling or timers.
    func ingest(metrics: ActivityMetrics) {
        update(with: metrics)
    }

    private func update(with metrics: ActivityMetrics) {
        var configuredMetrics = metrics
        configuredMetrics.thresholds = activityThresholds
        self.metrics = configuredMetrics
        let candidateStatus = ActivityStatus(metrics: configuredMetrics)
        self.status = resolveStatusTransition(to: candidateStatus)
        processSamplingAvailable = provider.processSamplingAvailable
    }

    private func fetchMetricsOnce() {
        // Slow samples cannot accumulate a backlog when a shorter interval is selected.
        guard isMonitoring, !isFetching else { return }
        isFetching = true
        let generation = monitoringGeneration
        queue.async { [weak self] in
            guard let self else { return }
            let metrics = self.provider.fetchMetrics()
            DispatchQueue.main.async {
                self.isFetching = false
                guard self.isMonitoring, self.monitoringGeneration == generation else { return }
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

    var ignoredProcessPaths: Set<String> {
        get { provider.ignoredProcessPaths }
        set { provider.ignoredProcessPaths = newValue }
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
