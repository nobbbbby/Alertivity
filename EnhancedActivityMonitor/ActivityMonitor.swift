import Combine
import Foundation

final class ActivityMonitor: ObservableObject {
    @Published private(set) var metrics: ActivityMetrics = .placeholder
    @Published private(set) var status: ActivityStatus = .normal

    private let provider = SystemMetricsProvider()
    private var cancellable: AnyCancellable?
    private let queue = DispatchQueue(label: "activity-monitor.queue")

    init(
        metrics: ActivityMetrics = .placeholder,
        status: ActivityStatus = .normal
    ) {
        _metrics = Published(initialValue: metrics)
        _status = Published(initialValue: status)
    }

    func startMonitoring(interval: TimeInterval = 5) {
        stopMonitoring()

        queue.async { [weak self] in
            guard let self else { return }
            let metrics = self.provider.fetchMetrics()
            DispatchQueue.main.async {
                self.update(with: metrics)
            }
        }

        cancellable = Timer
            .publish(every: interval, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .receive(on: queue)
            .map { [weak self] _ in self?.provider.fetchMetrics() ?? .placeholder }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.update(with: metrics)
            }
    }

    func stopMonitoring() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func update(with metrics: ActivityMetrics) {
        self.metrics = metrics
        self.status = ActivityStatus(metrics: metrics)
    }
}
