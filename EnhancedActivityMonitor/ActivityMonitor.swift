import Combine
import Foundation

final class ActivityMonitor: ObservableObject {
    @Published private(set) var metrics: ActivityMetrics = .placeholder
    @Published private(set) var status: ActivityStatus = .normal

    private let provider: SystemMetricsProvider
    private var timer: Timer?
    private let queue: DispatchQueue = DispatchQueue(label: "activity-monitor.queue")
    private var isMonitoring = false
    private let instanceID = UUID().uuidString.prefix(8)

    init(
        metrics: ActivityMetrics = .placeholder,
        status: ActivityStatus = .normal,
        autoStart: Bool = true,
        interval: TimeInterval = 5,
        provider: SystemMetricsProvider = SystemMetricsProvider(),
        highActivityDuration: TimeInterval = 120
    ) {
        print("[\(instanceID)] ActivityMonitor.init called, autoStart=\(autoStart)")
        self.provider = provider
        self.provider.highActivityDuration = highActivityDuration
        _metrics = Published(initialValue: metrics)
        _status = Published(initialValue: status)
        if autoStart {
            print("[\(instanceID)] Calling startMonitoring from init")
            startMonitoring(interval: interval)
        }
    }
    
    deinit {
        print("[\(instanceID)] ActivityMonitor.deinit - instance being deallocated")
    }

    func startMonitoring(interval: TimeInterval = 5) {
        print("[\(instanceID)] startMonitoring called, isMonitoring=\(isMonitoring)")
        guard !isMonitoring else {
            print("[\(instanceID)] Already monitoring, skipping")
            return
        }
        
        stopMonitoring()
        isMonitoring = true
        print("[\(instanceID)] Starting monitoring with interval \(interval)s")

        fetchMetricsOnce()

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchMetricsOnce()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        print("[\(instanceID)] Timer started")
    }

    func stopMonitoring() {
        print("[\(instanceID)] stopMonitoring called")
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    private func update(with metrics: ActivityMetrics) {
        self.metrics = metrics
        self.status = ActivityStatus(metrics: metrics)
    }

    private func fetchMetricsOnce() {
        print("[\(instanceID)] fetchMetricsOnce() called, Thread: \(Thread.current)")
        print("[\(instanceID)] Call stack: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n"))")
        queue.async { [weak self] in
            print("[\(self?.instanceID ?? "nil")] queue.async block started")
            guard let self else {
                print("[nil] self is nil in queue.async, returning")
                return
            }
            print("[\(instanceID)] About to call provider.fetchMetrics()")
            let metrics = self.provider.fetchMetrics()
            print("[\(instanceID)] fetchMetrics() returned, updating on main thread")
            DispatchQueue.main.async {
                print("[\(self.instanceID)] main.async block started, calling update")
                self.update(with: metrics)
                print("[\(self.instanceID)] update completed, metrics.hasLiveData=\(metrics.hasLiveData)")
            }
        }
    }

    var highActivityDuration: TimeInterval {
        get { provider.highActivityDuration }
        set { provider.highActivityDuration = newValue }
    }
}
