import SwiftUI
import UserNotifications

@main
struct EnhancedActivityMonitorApp: App {
    @StateObject private var monitor = ActivityMonitor()
    @StateObject private var notificationManager = NotificationManager()

    @AppStorage("notice.menu.enabled") private var isMenuIconEnabled = true
    @AppStorage("notice.menu.onlyHigh") private var menuIconOnlyWhenHigh = false
    @AppStorage("notice.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("notice.menu.metrics.enabled") private var metricMenuIconsEnabled = false
    @AppStorage("notice.menu.metrics.cpu") private var cpuMenuIconEnabled = true
    @AppStorage("notice.menu.metrics.memory") private var memoryMenuIconEnabled = false
    @AppStorage("notice.menu.metrics.disk") private var diskMenuIconEnabled = false
    @AppStorage("notice.menu.metrics.network") private var networkMenuIconEnabled = false
    @AppStorage("notice.menu.metrics.processes") private var processMenuIconEnabled = false

    @State private var isMenuBarInserted = true

    var body: some Scene {
        WindowGroup {
            ContentView(
                monitor: monitor,
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled,
                metricMenuIconsEnabled: $metricMenuIconsEnabled,
                cpuMenuIconEnabled: $cpuMenuIconEnabled,
                memoryMenuIconEnabled: $memoryMenuIconEnabled,
                diskMenuIconEnabled: $diskMenuIconEnabled,
                networkMenuIconEnabled: $networkMenuIconEnabled,
                processMenuIconEnabled: $processMenuIconEnabled
            )
            .onAppear {
                monitor.startMonitoring()
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: monitor.status) { newValue in
                updateMenuBarInsertion(for: newValue)
                if notificationsEnabled {
                    notificationManager.postNotificationIfNeeded(for: newValue, metrics: monitor.metrics)
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
            .onChange(of: metricMenuIconsEnabled) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: cpuMenuIconEnabled) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: memoryMenuIconEnabled) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: diskMenuIconEnabled) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: networkMenuIconEnabled) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: processMenuIconEnabled) { _ in
                updateMenuBarInsertion(for: monitor.status)
            }
        }

        MenuBarExtra(
            isInserted: $isMenuBarInserted
        ) {
            VStack(alignment: .leading, spacing: 12) {
                MenuStatusView(metrics: monitor.metrics, status: monitor.status)

                if metricMenuIconsEnabled && !enabledMetricSelections.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(enabledMetricSelections, id: \.self) { selection in
                            MetricMenuDetailView(metrics: monitor.metrics, selection: selection)
                        }
                    }
                }
            }
            .frame(minWidth: 220, alignment: .leading)
            .padding()
        } label: {
            MetricMenuBarLabel(
                status: monitor.status,
                metrics: monitor.metrics,
                showStatusSymbol: shouldShowStatusSymbol(for: monitor.status),
                selections: metricMenuIconsEnabled ? enabledMetricSelections : []
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled,
                metricMenuIconsEnabled: $metricMenuIconsEnabled,
                cpuMenuIconEnabled: $cpuMenuIconEnabled,
                memoryMenuIconEnabled: $memoryMenuIconEnabled,
                diskMenuIconEnabled: $diskMenuIconEnabled,
                networkMenuIconEnabled: $networkMenuIconEnabled,
                processMenuIconEnabled: $processMenuIconEnabled
            )
        }
    }

    private func updateMenuBarInsertion(for status: ActivityStatus) {
        let showStatus = shouldShowStatusSymbol(for: status)
        let showMetrics = metricMenuIconsEnabled && !enabledMetricSelections.isEmpty
        isMenuBarInserted = showStatus || showMetrics
    }

    private func shouldShowStatusSymbol(for status: ActivityStatus) -> Bool {
        guard isMenuIconEnabled else { return false }
        return menuIconOnlyWhenHigh ? status == .critical : true
    }

    private var enabledMetricSelections: [MetricMenuSelection] {
        MetricMenuSelection.enabled(
            cpu: cpuMenuIconEnabled,
            memory: memoryMenuIconEnabled,
            disk: diskMenuIconEnabled,
            network: networkMenuIconEnabled,
            processes: processMenuIconEnabled
        )
    }
}
