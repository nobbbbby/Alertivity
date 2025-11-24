import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications

private var dockVisibilityObserverTokens: [NSObjectProtocol] = []

@main
struct AlertivityApp: App {
    @StateObject private var monitor = ActivityMonitor()
    @StateObject private var notificationManager = NotificationManager()

    @AppStorage("app.hideDockIcon") private var hideDockIcon = false {
        didSet { applyDockVisibility(for: hideDockIcon) }
    }
    @AppStorage("app.launchAtLogin") private var launchAtLogin = false {
        didSet { applyLaunchAtLogin(for: launchAtLogin) }
    }
    @AppStorage("notice.menu.enabled") private var isMenuIconEnabled = true {
        didSet { updateMenuBarInsertion(for: monitor.status) }
    }
    @AppStorage("notice.menu.onlyHigh") private var menuIconOnlyWhenHigh = false {
        didSet { updateMenuBarInsertion(for: monitor.status) }
    }
    @AppStorage("notice.notifications.enabled") private var notificationsEnabled = false {
        didSet {
            if notificationsEnabled {
                notificationManager.requestAuthorizationIfNeeded()
            }
        }
    }
    @AppStorage("notice.menu.iconType") private var menuIconType = MenuIconType.status
    @AppStorage("notice.menu.showMetricIcon") private var showMetricIcon = false
    @AppStorage("notice.menu.autoSwitch") private var isMenuIconAutoSwitchEnabled = false {
        didSet { enforceAutoSwitchDependencies(isEnabled: isMenuIconAutoSwitchEnabled) }
    }
    @AppStorage("monitor.topProcesses.duration") private var highActivityDurationSeconds = 120 {
        didSet { applyHighActivityDurationUpdate(for: highActivityDurationSeconds) }
    }
    @AppStorage("monitor.topProcesses.cpuThresholdPercent") private var highActivityCPUThresholdPercent = 20 {
        didSet { applyHighActivityCPUThresholdUpdate(for: highActivityCPUThresholdPercent) }
    }

    @State private var isMenuBarInserted = true
    @State private var hasInitialized = false

    var body: some Scene {
        MenuBarExtra(
            isInserted: $isMenuBarInserted
        ) {
            VStack(alignment: .leading, spacing: 5) {
                MenuStatusView(metrics: monitor.metrics, status: monitor.status).padding(6)

                if let selection = menuIconType.metricSelection {
                    Divider().padding(.horizontal,6)
                    MetricMenuDetailView(metrics: monitor.metrics, selection: selection).padding(.horizontal,6)
                }

                Divider()
                if #available(macOS 14.0, *) {
                    SettingsMenuLinkRow()
                } else {
                    // Fallback on earlier versions
                }
            }
            .frame(minWidth: 220, alignment: .leading)
            .padding(6)
            
        } label: {
            MenuBarLabelLifecycleView(
                monitor: monitor,
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                menuIconType: $menuIconType,
                showMetricIcon: $showMetricIcon,
                autoSwitchEnabled: $isMenuIconAutoSwitchEnabled,
                initialize: performInitialSetup,
                onStatusChange: handleStatusChange,
                onMetricsChange: handleMetricsChange
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().frame(width: 400)
        }
    }

    private func performInitialSetup() {
        guard !hasInitialized else { return }
        hasInitialized = true

        startDockVisibilityObservers()
        applyDockVisibility(for: hideDockIcon)
        applyLaunchAtLogin(for: launchAtLogin)
        updateMenuBarInsertion(for: monitor.status)
        applyHighActivityDurationUpdate(for: highActivityDurationSeconds)
        applyHighActivityCPUThresholdUpdate(for: highActivityCPUThresholdPercent)
        enforceAutoSwitchDependencies(isEnabled: isMenuIconAutoSwitchEnabled)
    }

    private func handleStatusChange(_ newValue: ActivityStatus) {
        updateMenuBarInsertion(for: newValue)
        if notificationsEnabled {
            notificationManager.postNotificationIfNeeded(for: newValue, metrics: monitor.metrics)
        }
    }

    private func handleMetricsChange(_ newMetrics: ActivityMetrics) {
        if notificationsEnabled {
            notificationManager.postNotificationIfNeeded(for: monitor.status, metrics: newMetrics)
        }
    }

    private func applyHighActivityDurationUpdate(for value: Int) {
        let normalized = normalizedHighActivityDurationSeconds(value)
        if normalized != value {
            highActivityDurationSeconds = normalized
        } else {
            monitor.highActivityDuration = TimeInterval(normalized)
        }
    }

    private func applyHighActivityCPUThresholdUpdate(for value: Int) {
        let normalized = normalizedCPUThresholdPercent(value)
        if normalized != value {
            highActivityCPUThresholdPercent = normalized
        } else {
            monitor.highActivityCPUThreshold = Double(normalized) / 100.0
        }
    }

    private func updateMenuBarInsertion(for status: ActivityStatus) {
        isMenuBarInserted = shouldShowMenuIcon(for: status)
    }

    private func shouldShowMenuIcon(for status: ActivityStatus) -> Bool {
        guard isMenuIconEnabled else { return false }
        return menuIconOnlyWhenHigh ? status.level == .critical : true
    }

    private func resolvedMenuIconType(for metrics: ActivityMetrics) -> MenuIconType {
        resolveMenuIconType(
            autoSwitchEnabled: isMenuIconAutoSwitchEnabled,
            defaultIconType: menuIconType,
            metrics: metrics
        )
    }

    private func normalizedHighActivityDurationSeconds(_ value: Int) -> Int {
        min(max(value, 10), 600)
    }

    private func normalizedCPUThresholdPercent(_ value: Int) -> Int {
        min(max(value, 1), 100)
    }

    private func applyDockVisibility(for isHidden: Bool) {
        DispatchQueue.main.async {
            let hasVisibleWindow = NSApp.windows.contains { window in
                window.isVisible && !window.isMiniaturized && window.isOnActiveSpace
            }

            let shouldHideDockIcon = isHidden && !hasVisibleWindow
            let desiredPolicy: NSApplication.ActivationPolicy = shouldHideDockIcon ? .accessory : .regular

            if NSApp.activationPolicy() != desiredPolicy {
                NSApp.setActivationPolicy(desiredPolicy)

                if desiredPolicy == .regular {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func applyLaunchAtLogin(for shouldLaunch: Bool) {
        let wasUpdated = LaunchAtLoginManager.set(enabled: shouldLaunch)
        guard wasUpdated else {
            DispatchQueue.main.async {
                let resolvedValue = LaunchAtLoginManager.isEnabled()
                if launchAtLogin != resolvedValue {
                    launchAtLogin = resolvedValue
                }
            }
            return
        }
    }

    private func enforceAutoSwitchDependencies(isEnabled: Bool) {
        if isEnabled && !showMetricIcon {
            showMetricIcon = true
        }
    }

    private func startDockVisibilityObservers() {
        guard dockVisibilityObserverTokens.isEmpty else { return }

        let notifications: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.willCloseNotification
        ]

        dockVisibilityObserverTokens = notifications.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                applyDockVisibility(for: hideDockIcon)
            }
        }
    }

}

private enum LaunchAtLoginManager {
    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @discardableResult
    static func set(enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("LaunchAtLoginManager error: \(error.localizedDescription)")
            return false
        }
    }
}

private struct MenuBarLabelLifecycleView: View {
    @ObservedObject var monitor: ActivityMonitor
    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var menuIconType: MenuIconType
    @Binding var showMetricIcon: Bool
    @Binding var autoSwitchEnabled: Bool
    let initialize: () -> Void
    let onStatusChange: (ActivityStatus) -> Void
    let onMetricsChange: (ActivityMetrics) -> Void

    var body: some View {
        MetricMenuBarLabel(
            status: monitor.status,
            metrics: monitor.metrics,
            isVisible: isMenuIconVisible,
            iconType: resolvedIconType,
            showIcon: shouldShowMetricIcon
        )
        .onAppear(perform: initialize)
        .onChange(of: monitor.status, perform: onStatusChange)
        .onChange(of: monitor.metrics, perform: onMetricsChange)
        .onChange(of: isMenuIconEnabled) { _ in
            onStatusChange(monitor.status)
        }
        .onChange(of: menuIconOnlyWhenHigh) { _ in
            onStatusChange(monitor.status)
        }
    }

    private var isMenuIconVisible: Bool {
        guard isMenuIconEnabled else { return false }
        return menuIconOnlyWhenHigh ? monitor.status.level == .critical : true
    }

    private var resolvedIconType: MenuIconType {
        resolveMenuIconType(
            autoSwitchEnabled: autoSwitchEnabled,
            defaultIconType: menuIconType,
            metrics: monitor.metrics
        )
    }

    private var shouldShowMetricIcon: Bool {
        guard resolvedIconType.metricSelection != nil else { return false }
        return showMetricIcon || autoSwitchEnabled
    }
}

@available(macOS 14.0, *)
private struct SettingsMenuLinkRow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isHovering = false

    var body: some View {
        SettingsLink {
            Text("Open Settings…")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
//        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(isHovering ? 0.3 : 0))
        )
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .simultaneousGesture(TapGesture().onEnded {
            dismiss()
        })
    }
}

#if DEBUG
@available(macOS 14.0, *)
#Preview("Settings Link") {
    SettingsMenuLinkRow()
    .frame(width: 220)
    .padding()
}
#endif
