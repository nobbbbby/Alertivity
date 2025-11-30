import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications

private var dockVisibilityObserverTokens: [NSObjectProtocol] = []

@main
struct AlertivityApp: App {
    @StateObject private var monitor = ActivityMonitor()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var settings = SettingsStore()

    @State private var isMenuBarInserted = true
    @State private var hasInitialized = false

    var body: some Scene {
        MenuBarExtra(
            isInserted: $isMenuBarInserted
        ) {
            VStack(alignment: .leading, spacing: 5) {
                MenuStatusView(metrics: monitor.metrics).padding(6)

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
                isMenuIconEnabled: settingsBinding(\.isMenuIconEnabled),
                menuIconOnlyWhenHigh: settingsBinding(\.menuIconOnlyWhenHigh),
                menuIconType: settingsBinding(\.menuIconType),
                showMetricIcon: settingsBinding(\.showMetricIcon),
                autoSwitchEnabled: settingsBinding(\.isMenuIconAutoSwitchEnabled),
                initialize: performInitialSetup,
                onStatusChange: handleStatusChange,
                onMetricsChange: handleMetricsChange
            )
            .onChange(of: settings.highActivityDurationSeconds, perform: applyHighActivityDurationUpdate)
            .onChange(of: settings.highActivityCPUThresholdPercent, perform: applyHighActivityCPUThresholdUpdate)
            .onChange(of: settings.highActivityMemoryThresholdPercent, perform: applyHighActivityMemoryThresholdUpdate)
            .onChange(of: settings.hideDockIcon, perform: applyDockVisibility)
            .onChange(of: settings.launchAtLogin, perform: applyLaunchAtLogin)
            .onChange(of: settings.isMenuIconEnabled) { _ in updateMenuBarInsertion(for: ActivityStatus(metrics: monitor.metrics)) }
            .onChange(of: settings.menuIconOnlyWhenHigh) { _ in updateMenuBarInsertion(for: ActivityStatus(metrics: monitor.metrics)) }
            .onChange(of: settings.notificationsEnabled) { newValue in
                if newValue {
                    notificationManager.requestAuthorizationIfNeeded()
                }
            }
            .onChange(of: settings.isMenuIconAutoSwitchEnabled, perform: enforceAutoSwitchDependencies)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
                .frame(width: 400)
                .background(SettingsWindowAccessor())
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }

    private func performInitialSetup() {
        guard !hasInitialized else { return }
        hasInitialized = true

        startDockVisibilityObservers()
        applyDockVisibility(for: settings.hideDockIcon)
        applyLaunchAtLogin(for: settings.launchAtLogin)
        updateMenuBarInsertion(for: monitor.status)
        applyHighActivityDurationUpdate(for: settings.highActivityDurationSeconds)
        applyHighActivityCPUThresholdUpdate(for: settings.highActivityCPUThresholdPercent)
        applyHighActivityMemoryThresholdUpdate(for: settings.highActivityMemoryThresholdPercent)
        enforceAutoSwitchDependencies(isEnabled: settings.isMenuIconAutoSwitchEnabled)
        sanitizeMenuIconType()
        if settings.notificationsEnabled {
            notificationManager.requestAuthorizationIfNeeded()
        }
    }

    private func handleStatusChange(_ newValue: ActivityStatus) {
        updateMenuBarInsertion(for: newValue)
        if settings.notificationsEnabled {
            notificationManager.postNotificationIfNeeded(for: newValue, metrics: monitor.metrics)
        }
    }

    private func handleMetricsChange(_ newMetrics: ActivityMetrics) {
        if settings.notificationsEnabled {
            notificationManager.postNotificationIfNeeded(for: monitor.status, metrics: newMetrics)
        }
        updateMenuBarInsertion(for: ActivityStatus(metrics: newMetrics))
    }

    private func applyHighActivityDurationUpdate(for value: Int) {
        let normalized = normalizedHighActivityDurationSeconds(value)
        if normalized != value {
            settings.highActivityDurationSeconds = normalized
        } else {
            monitor.highActivityDuration = TimeInterval(normalized)
            notificationManager.highActivityDuration = TimeInterval(normalized)
        }
    }

    private func applyHighActivityCPUThresholdUpdate(for value: Int) {
        let normalized = normalizedCPUThresholdPercent(value)
        if normalized != value {
            settings.highActivityCPUThresholdPercent = normalized
        } else {
            monitor.highActivityCPUThreshold = Double(normalized) / 100.0
        }
    }

    private func applyHighActivityMemoryThresholdUpdate(for value: Int) {
        let normalized = normalizedMemoryThresholdPercent(value)
        if normalized != value {
            settings.highActivityMemoryThresholdPercent = normalized
        } else {
            monitor.highActivityMemoryThreshold = Double(normalized) / 100.0
        }
    }

    private func updateMenuBarInsertion(for status: ActivityStatus) {
        isMenuBarInserted = shouldShowMenuIcon(for: status)
    }

    private func shouldShowMenuIcon(for status: ActivityStatus) -> Bool {
        guard settings.isMenuIconEnabled else { return false }
        return settings.menuIconOnlyWhenHigh ? status.level == .critical : true
    }

    private func normalizedHighActivityDurationSeconds(_ value: Int) -> Int {
        min(max(value, 10), 600)
    }

    private func normalizedCPUThresholdPercent(_ value: Int) -> Int {
        min(max(value, 1), 100)
    }

    private func normalizedMemoryThresholdPercent(_ value: Int) -> Int {
        min(max(value, 5), 50)
    }

    private func applyDockVisibility(for isHidden: Bool) {
        DispatchQueue.main.async {
            let hasVisibleWindow = self.hasVisibleUserWindow()
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
                if settings.launchAtLogin != resolvedValue {
                    settings.launchAtLogin = resolvedValue
                }
            }
            return
        }
    }

    private func enforceAutoSwitchDependencies(isEnabled: Bool) {
        if isEnabled && !settings.showMetricIcon {
            settings.showMetricIcon = true
        }
    }

    private func sanitizeMenuIconType() {
        let stored = UserDefaults.standard.string(forKey: "notice.menu.iconType")
        if let raw = stored, MenuIconType(rawValue: raw) == nil {
            settings.menuIconType = .status
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
                applyDockVisibility(for: settings.hideDockIcon)
            }
        }
    }

    private func hasVisibleUserWindow() -> Bool {
        // Limit visibility checks to user-facing window levels so status bar windows from the menu extra don't block Dock hiding on macOS 15.7+.
        let userFacingLevels: Set<NSWindow.Level> = [.normal, .floating, .modalPanel]

        return NSApp.windows.contains { window in
            guard
                window.isVisible,
                !window.isMiniaturized,
                window.isOnActiveSpace,
                userFacingLevels.contains(window.level)
            else {
                return false
            }

            return true
        }
    }

}

private extension AlertivityApp {
    func settingsBinding<Value>(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Value>) -> Binding<Value> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { settings[keyPath: keyPath] = $0 }
        )
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
    @State private var autoSwitchSelection: MetricMenuSelection?
    @State private var pendingAutoSwitchSelection: MetricMenuSelection?
    @State private var pendingAutoSwitchSamples: Int = 0

    var body: some View {
        MetricMenuBarLabel(
            status: displayStatus,
            metrics: monitor.metrics,
            isVisible: isMenuIconVisible,
            iconType: resolvedIconType,
            showIcon: shouldShowMetricIcon
        )
        .onAppear {
            initialize()
            updateAutoSwitchSelection(for: monitor.metrics)
        }
        .onChange(of: monitor.status, perform: onStatusChange)
        .onChange(of: monitor.metrics, perform: onMetricsChange)
        .onChange(of: monitor.metrics) { metrics in
            updateAutoSwitchSelection(for: metrics)
        }
        .onChange(of: isMenuIconEnabled) { _ in
            onStatusChange(monitor.status)
        }
        .onChange(of: menuIconOnlyWhenHigh) { _ in
            onStatusChange(monitor.status)
        }
        .onChange(of: autoSwitchEnabled) { _ in
            updateAutoSwitchSelection(for: monitor.metrics)
        }
    }

    private var isMenuIconVisible: Bool {
        guard isMenuIconEnabled else { return false }
        return menuIconOnlyWhenHigh ? displayStatus.level == .critical : true
    }

    private var resolvedIconType: MenuIconType {
        resolveMenuIconType(
            autoSwitchEnabled: autoSwitchEnabled,
            defaultIconType: menuIconType,
            autoSwitchSelection: autoSwitchSelection
        )
    }

    private var shouldShowMetricIcon: Bool {
        guard resolvedIconType.metricSelection != nil else { return false }
        return showMetricIcon || autoSwitchEnabled
    }

    private func updateAutoSwitchSelection(for metrics: ActivityMetrics) {
        guard autoSwitchEnabled else {
            autoSwitchSelection = nil
            pendingAutoSwitchSelection = nil
            pendingAutoSwitchSamples = 0
            return
        }

        let candidate = metrics.highestSeverityMetric(allowedSeverities: [.critical])?.0

        if candidate == autoSwitchSelection {
            pendingAutoSwitchSelection = nil
            pendingAutoSwitchSamples = 0
            return
        }

        if pendingAutoSwitchSelection == candidate {
            pendingAutoSwitchSamples += 1
        } else {
            pendingAutoSwitchSelection = candidate
            pendingAutoSwitchSamples = 1
        }

        if pendingAutoSwitchSamples >= 2 {
            autoSwitchSelection = candidate
            pendingAutoSwitchSelection = nil
            pendingAutoSwitchSamples = 0
        }
    }

    private var displayStatus: ActivityStatus {
        ActivityStatus(metrics: monitor.metrics)
    }
}

private enum SettingsWindowCoordinator {
    @MainActor
    static func focusExistingWindow() {
        guard let window = SettingsWindowTracker.shared.window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class SettingsWindowTracker {
    static let shared = SettingsWindowTracker()
    weak var window: NSWindow?
}

private struct SettingsWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { registerWindow(for: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { registerWindow(for: nsView) }
    }

    private func registerWindow(for view: NSView) {
        if let window = view.window {
            SettingsWindowTracker.shared.window = window
        }
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
            SettingsWindowCoordinator.focusExistingWindow()
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
