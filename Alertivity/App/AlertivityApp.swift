import SwiftUI
import AppKit
import OSLog
import ServiceManagement
import UserNotifications

private var dockVisibilityObserverTokens: [NSObjectProtocol] = []

@main
struct AlertivityApp: App {
    @NSApplicationDelegateAdaptor(AlertivityAppDelegate.self) private var appDelegate
    @StateObject private var monitor = ActivityMonitor()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var settings = AlertivityApp.makeSettingsStore()
    @StateObject private var reviewStore = ReviewRequestStore()
    @StateObject private var proStore = ProStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var isMenuBarInserted = true
    @State private var hasInitialized = false

#if DEBUG
    private var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("UITests")
    }
#endif

    var body: some Scene {
        MenuBarExtra(
            isInserted: $isMenuBarInserted
        ) {
            MenuExtraContainer {
                VStack(alignment: .leading, spacing: 5) {
                    MenuStatusView(
                        metrics: monitor.metrics,
                        onAddToWhitelist: { path in
                            settings.ignoreProcess(at: path)
                        }
                    )
                    .padding(6)

                    Divider()
                    SettingsMenuLinkRow()
                }
                .frame(minWidth: 220, alignment: .leading)
                .padding(6)
            }
            
        } label: {
            MenuBarLabelLifecycleView(
                monitor: monitor,
                isMenuIconEnabled: settingsBinding(\.isMenuIconEnabled),
                menuIconOnlyWhenHigh: settingsBinding(\.menuIconOnlyWhenHigh),
                menuIconType: settingsBinding(\.menuIconType),
                showMetricIcon: settingsBinding(\.showMetricIcon),
                autoSwitchEnabled: settingsBinding(\.isMenuIconAutoSwitchEnabled),
                autoSwitchPriority: settingsBinding(\.menuIconAutoSwitchPriority),
                initialize: performInitialSetup
            )
            .background(OnboardingLauncher(settings: settings))
            .task { await proStore.start() }
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .help) {
                OnboardingLink(settings: settings)
                Divider()
                FeedbackLink()
            }
        }
        .onChange(of: proStore.hasProAccess, initial: true) { _, granted in
            settings.setProAccess(granted)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await proStore.refreshAccess() } }
        }
        .onChange(of: settings.monitoringConfiguration) { _, configuration in
            applyMonitoringConfiguration(configuration)
        }
        .onChange(of: settings.highActivityCPUThresholdPercent) { _, value in
            applyHighActivityCPUThresholdUpdate(for: value)
        }
        .onChange(of: settings.highActivityMemoryThresholdPercent) { _, value in
            applyHighActivityMemoryThresholdUpdate(for: value)
        }
        .onChange(of: settings.ignoredProcessPaths) { _, paths in
            applyIgnoredProcessPathsUpdate(for: paths)
        }
        .onChange(of: settings.hideDockIcon) { _, value in
            applyDockVisibility(for: value)
        }
        .onChange(of: settings.launchAtLogin) { _, value in
            applyLaunchAtLogin(for: value)
        }
        .onChange(of: settings.isMenuIconEnabled) {
            updateMenuBarInsertion(for: ActivityStatus(metrics: monitor.metrics))
        }
        .onChange(of: settings.menuIconOnlyWhenHigh) {
            updateMenuBarInsertion(for: ActivityStatus(metrics: monitor.metrics))
        }
        .onChange(of: settings.notificationsEnabled) { _, newValue in
            if newValue {
                notificationManager.requestAuthorizationIfNeeded()
            }
        }
        .onChange(of: settings.isMenuIconAutoSwitchEnabled) { _, value in
            enforceAutoSwitchDependencies(isEnabled: value)
        }
        .onChange(of: monitor.status) { _, status in handleStatusChange(status) }
        .onChange(of: monitor.metrics) { _, metrics in handleMetricsChange(metrics) }

        onboardingWindow

        Settings {
            SettingsView(
                settings: settings,
                processSamplingAvailable: settings.distribution == .openSource && monitor.processSamplingAvailable,
                notificationManager: notificationManager,
                reviewStore: reviewStore,
                proStore: proStore,
                metrics: monitor.metrics
            )
                .frame(width: 400)
                .background(SettingsWindowAccessor())
                .task { await proStore.start() }
                .onAppear {
                    // SwiftUI may show a retained Settings window without attaching a new view.
                    DispatchQueue.main.async {
                        SettingsWindowCoordinator.focusExistingWindow()
                    }
                }
        }
        .commands {
            CommandGroup(after: .appSettings) {
                WriteReviewButton(store: reviewStore)
            }
        }

#if DEBUG
        WindowGroup("uiTests.window.title") {
            if isUITest {
                UITestHarnessView(settings: settings)
            } else {
                EmptyView()
            }
        }
#endif
    }

    private var onboardingWindow: some Scene {
        Window("onboarding.title", id: "onboarding") {
            OnboardingView(
                settings: settings,
                notificationManager: notificationManager,
                monitor: monitor,
                processSamplingAvailable: monitor.processSamplingAvailable
            )
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private func performInitialSetup() {
        guard !hasInitialized else { return }
        hasInitialized = true
        reviewStore.startRecordingUsage(from: monitor)

#if DEBUG
        if isUITest {
            settings.hideDockIcon = false
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
#endif

        startDockVisibilityObservers()
        applyDockVisibility(for: settings.hideDockIcon)
        applyLaunchAtLogin(for: settings.launchAtLogin)
        updateMenuBarInsertion(for: monitor.status)
        applyMonitoringConfiguration(settings.monitoringConfiguration)
        applyHighActivityCPUThresholdUpdate(for: settings.highActivityCPUThresholdPercent)
        applyHighActivityMemoryThresholdUpdate(for: settings.highActivityMemoryThresholdPercent)
        applyIgnoredProcessPathsUpdate(for: settings.ignoredProcessPaths)
        notificationManager.onIgnoreProcess = { path in
            settings.ignoreProcess(at: path)
        }
        notificationManager.processSamplingAvailable = monitor.processSamplingAvailable
        enforceAutoSwitchDependencies(isEnabled: settings.isMenuIconAutoSwitchEnabled)
        sanitizeMenuIconType()
    }

    private func handleStatusChange(_ newValue: ActivityStatus) {
        updateMenuBarInsertion(for: newValue)
        if settings.notificationsEnabled {
            notificationManager.postNotificationIfNeeded(for: newValue, metrics: monitor.metrics)
        }
    }

    private func handleMetricsChange(_ newMetrics: ActivityMetrics) {
        notificationManager.processSamplingAvailable = monitor.processSamplingAvailable
        if settings.notificationsEnabled {
            notificationManager.postNotificationIfNeeded(for: monitor.status, metrics: newMetrics)
        }
        updateMenuBarInsertion(for: ActivityStatus(metrics: newMetrics))
    }

    private func applyMonitoringConfiguration(_ configuration: MonitoringConfiguration) {
        notificationManager.notificationCooldown = TimeInterval(configuration.cooldownMinutes * 60)
        monitor.highActivityDuration = TimeInterval(configuration.durationSeconds)
        notificationManager.highActivityDuration = TimeInterval(configuration.durationSeconds)
        if monitor.activityThresholds != configuration.thresholds {
            applyActivityThresholdUpdate(for: configuration.thresholds)
        }
        AppLogger.metrics.info("Effective monitoring configuration applied; custom: \(settings.canCustomizeMonitoring, privacy: .public) cooldownMinutes: \(configuration.cooldownMinutes) durationSeconds: \(configuration.durationSeconds)")
    }

    private func applyHighActivityCPUThresholdUpdate(for value: Int) {
        let normalized = MonitoringPreferences.normalizedCPUThreshold(value)
        if normalized != value {
            settings.highActivityCPUThresholdPercent = normalized
        } else {
            monitor.highActivityCPUThreshold = Double(normalized) / 100.0
        }
    }

    private func applyHighActivityMemoryThresholdUpdate(for value: Int) {
        let normalized = MonitoringPreferences.normalizedMemoryThreshold(value)
        if normalized != value {
            settings.highActivityMemoryThresholdPercent = normalized
        } else {
            monitor.highActivityMemoryThreshold = Double(normalized) / 100.0
        }
    }

    private func applyActivityThresholdUpdate(for thresholds: ActivityThresholds) {
        monitor.activityThresholds = thresholds
        updateMenuBarInsertion(for: ActivityStatus(metrics: monitor.metrics))
    }

    private func applyIgnoredProcessPathsUpdate(for paths: [String]) {
        monitor.ignoredProcessPaths = Set(paths)
    }

    private func updateMenuBarInsertion(for status: ActivityStatus) {
        isMenuBarInserted = shouldShowMenuIcon(for: status)
    }

    private func shouldShowMenuIcon(for status: ActivityStatus) -> Bool {
        guard settings.isMenuIconEnabled else { return false }
        return settings.menuIconOnlyWhenHigh ? status.level == .critical : true
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
#if DEBUG
        // UI tests exercise preferences without changing the user's registered login item.
        if isUITest { return }
#endif
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
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            AppLogger.lifecycle.error(
                "Failed to update launch-at-login registration: \(error.localizedDescription, privacy: .public)"
            )
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
    @Binding var autoSwitchPriority: [MetricMenuSelection]
    let initialize: () -> Void
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
        .onChange(of: monitor.metrics) { _, metrics in
            updateAutoSwitchSelection(for: metrics)
        }
        .onChange(of: autoSwitchEnabled) {
            updateAutoSwitchSelection(for: monitor.metrics)
        }
        .onChange(of: autoSwitchPriority) {
            // A new order must earn two fresh matching samples.
            pendingAutoSwitchSelection = nil
            pendingAutoSwitchSamples = 0
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

        let candidate = metrics.highestSeverityMetric(allowedSeverities: [.critical], priority: autoSwitchPriority)?.0

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
    /// Promote the menu-bar app before opening Settings so activation and window ordering agree.
    @MainActor
    static func prepareForPresentation() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate()
    }

    @MainActor
    static func focusExistingWindow() {
        guard let window = SettingsWindowTracker.shared.window else { return }
        prepareForPresentation()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        AppLogger.lifecycle.debug("Requested Settings window foreground presentation")
    }
}

private struct MenuExtraContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            content
        } else {
            ZStack {
                MenuWindowBackground()
                    .ignoresSafeArea()
                content
            }
        }
    }
}

private struct MenuWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .withinWindow
        view.state = .active
        view.alphaValue = 0.7
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // No-op: background view is static.
    }
}

/// Shares the actual settings window for focus restoration and safe review presentation.
final class SettingsWindowTracker {
    static let shared = SettingsWindowTracker()
    weak var window: NSWindow?
}

private struct SettingsWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowRegistrationView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowRegistrationView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            SettingsWindowTracker.shared.window = window
            // Wait until SwiftUI finishes attaching the new Settings window before ordering it.
            // Ordinary view updates must not steal focus from another application.
            DispatchQueue.main.async { [weak window] in
                guard let window, SettingsWindowTracker.shared.window === window else { return }
                SettingsWindowCoordinator.focusExistingWindow()
            }
        }
    }
}

private struct SettingsMenuLinkRow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @State private var isHovering = false

    var body: some View {
        Button {
            dismiss()
            // Close the menu extra first so its dismissal cannot take focus back from Settings.
            DispatchQueue.main.async {
                SettingsWindowCoordinator.prepareForPresentation()
                openSettings()
                DispatchQueue.main.async {
                    SettingsWindowCoordinator.focusExistingWindow()
                }
            }
        } label: {
            Text("menu.openSettings")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(isHovering ? 0.3 : 0))
        )
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}

#if DEBUG && !DISABLE_PREVIEWS
@available(macOS 14.0, *)
#Preview("Settings Link") {
    SettingsMenuLinkRow()
    .frame(width: 220)
    .padding()
}
#endif

private extension AlertivityApp {
    static func makeSettingsStore() -> SettingsStore {
        var defaults: UserDefaults = .standard
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITests") {
            let suiteName = "Alertivity.UITests"
            defaults = UserDefaults(suiteName: suiteName) ?? .standard
            if !ProcessInfo.processInfo.arguments.contains("UITestsPreserveDefaults") {
                defaults.removePersistentDomain(forName: suiteName)
            }
        }
#endif
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITests"),
           ProcessInfo.processInfo.arguments.contains("UITestsAppStoreFree") {
            return SettingsStore(userDefaults: defaults, distribution: .appStore)
        }
#endif
        return SettingsStore(userDefaults: defaults)
    }
}

#if DEBUG
private struct UITestHarnessView: View {
    @ObservedObject var settings: SettingsStore

    private let sampleMetrics = ActivityMetrics(
        cpuUsage: 0.86,
        memoryUsed: Measurement(value: 12, unit: .gigabytes),
        memoryTotal: Measurement(value: 16, unit: .gigabytes),
        runningProcesses: 96,
        network: NetworkMetrics(
            receivedBytesPerSecond: 2_400_000,
            sentBytesPerSecond: 1_200_000
        ),
        disk: DiskMetrics(readBytesPerSecond: 38_000_000, writeBytesPerSecond: 28_000_000),
        highActivityProcesses: []
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("uiTests.harness.title")
                .font(.title2.weight(.semibold))

            MenuStatusView(metrics: sampleMetrics)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Form {
                NoticePreferencesView(settings: settings, processSamplingAvailable: true)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(22)
        .frame(minWidth: 520, minHeight: 560, alignment: .topLeading)
    }
}
#endif
