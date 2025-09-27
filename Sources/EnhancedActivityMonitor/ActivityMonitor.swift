import Combine
import Foundation

final class ActivityMonitor: ObservableObject {
    @Published private(set) var metrics: ActivityMetrics = .placeholder
    @Published private(set) var status: ActivityStatus = .normal

    private let provider = SystemMetricsProvider()
    private var cancellable: AnyCancellable?
    private let queue = DispatchQueue(label: "activity-monitor.queue")

    func startMonitoring(interval: TimeInterval = 5) {
        cancellable = Timer
            .publish(every: interval, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .receive(on: queue)
            .map { [weak self] _ in self?.provider.fetchMetrics() ?? .placeholder }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.metrics = metrics
                self?.status = ActivityStatus(metrics: metrics)
            }
    }

    func stopMonitoring() {
        cancellable?.cancel()
        cancellable = nil
    }
}
