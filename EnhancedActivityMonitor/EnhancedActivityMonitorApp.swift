import SwiftUI
import UserNotifications

@main
struct EnhancedActivityMonitorApp: App {
    @StateObject private var monitor = ActivityMonitor()
    @StateObject private var notificationManager = NotificationManager()

    @AppStorage("notice.menu.enabled") private var isMenuIconEnabled = true
    @AppStorage("notice.menu.onlyHigh") private var menuIconOnlyWhenHigh = false
    @AppStorage("notice.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("notice.menu.iconType") private var menuIconType = MenuIconType.status
    @AppStorage("notice.menu.showMetricIcon") private var showMetricIcon = false
    @AppStorage("monitor.topProcesses.duration") private var highActivityDurationSeconds = 120

    @State private var isMenuBarInserted = true
    @State private var hasInitialized = false

    var body: some Scene {
        WindowGroup {
            ContentView(
                monitor: monitor,
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled,
                menuIconType: $menuIconType,
                showMetricIcon: $showMetricIcon,
                highActivityDurationSeconds: $highActivityDurationSeconds
            )
            .padding()
            .onAppear {
                print("🟢 ContentView.onAppear called, hasInitialized=\(hasInitialized)")
                guard !hasInitialized else {
                    print("🟢 Already initialized, skipping onAppear logic")
                    return
                }
                hasInitialized = true
                
                updateMenuBarInsertion(for: monitor.status)
                let normalizedDuration = normalizedHighActivityDurationSeconds(highActivityDurationSeconds)
                if normalizedDuration != highActivityDurationSeconds {
                    highActivityDurationSeconds = normalizedDuration
                }
                monitor.highActivityDuration = TimeInterval(normalizedDuration)
            }
            .onChange(of: monitor.status) { newValue in
                updateMenuBarInsertion(for: newValue)
                if notificationsEnabled {
                    notificationManager.postNotificationIfNeeded(for: newValue, metrics: monitor.metrics)
                }
            }
            .onChange(of: monitor.metrics) { newMetrics in
                if notificationsEnabled {
                    notificationManager.postNotificationIfNeeded(for: monitor.status, metrics: newMetrics)
                }
            }
            .onChange(of: notificationsEnabled) { isEnabled in
                if isEnabled {
                    notificationManager.requestAuthorizationIfNeeded()
                }
            }
            .onChange(of: isMenuIconEnabled) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: menuIconOnlyWhenHigh) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: menuIconType) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: highActivityDurationSeconds) { newValue in
                let normalized = normalizedHighActivityDurationSeconds(newValue)
                if normalized != newValue {
                    highActivityDurationSeconds = normalized
                } else {
                    monitor.highActivityDuration = TimeInterval(normalized)
                }
            }
        }
        .windowResizability(.contentSize)

        MenuBarExtra(
            isInserted: $isMenuBarInserted
        ) {
            VStack(alignment: .leading, spacing: 12) {
                MenuStatusView(metrics: monitor.metrics, status: monitor.status)

                if let selection = menuIconType.metricSelection {
                    Divider()
                    MetricMenuDetailView(metrics: monitor.metrics, selection: selection)
                }
            }
            .frame(minWidth: 220, alignment: .leading)
            .padding()
        } label: {
            MetricMenuBarLabel(
                status: monitor.status,
                metrics: monitor.metrics,
                isVisible: shouldShowMenuIcon(for: monitor.status),
                iconType: menuIconType,
                showIcon: showMetricIcon
            )
        }
        .menuBarExtraStyle(.window)
    }

    private func updateMenuBarInsertion(for status: ActivityStatus) {
        isMenuBarInserted = shouldShowMenuIcon(for: status)
    }

    private func shouldShowMenuIcon(for status: ActivityStatus) -> Bool {
        guard isMenuIconEnabled else { return false }
        return menuIconOnlyWhenHigh ? status == .critical : true
    }

    private func normalizedHighActivityDurationSeconds(_ value: Int) -> Int {
        min(max(value, 10), 600)
    }
}
