import SwiftUI
import UserNotifications

@main
struct EnhancedActivityMonitorApp: App {
    @StateObject private var monitor = ActivityMonitor()
    @StateObject private var notificationManager = NotificationManager()

    @AppStorage("notice.menu.enabled") private var isMenuIconEnabled = true
    @AppStorage("notice.menu.onlyHigh") private var menuIconOnlyWhenHigh = false
    @AppStorage("notice.notifications.enabled") private var notificationsEnabled = false

    @State private var isMenuBarInserted = true

    var body: some Scene {
        WindowGroup {
            ContentView(
                monitor: monitor,
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled
            )
            .onAppear {
                monitor.startMonitoring()
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: monitor.status) { _, newValue in
                updateMenuBarInsertion(for: newValue)
                if notificationsEnabled {
                    notificationManager.postNotificationIfNeeded(for: newValue, metrics: monitor.metrics)
                }
            }
            .onChange(of: notificationsEnabled) { _, isEnabled in
                if isEnabled {
                    notificationManager.requestAuthorizationIfNeeded()
                }
            }
            .onChange(of: isMenuIconEnabled) { _, _ in
                updateMenuBarInsertion(for: monitor.status)
            }
            .onChange(of: menuIconOnlyWhenHigh) { _, _ in
                updateMenuBarInsertion(for: monitor.status)
            }
        }

        if isMenuIconEnabled {
            MenuBarExtra(
                "Enhanced Activity Monitor",
                systemImage: monitor.status.symbolName,
                isInserted: $isMenuBarInserted
            ) {
                MenuStatusView(metrics: monitor.metrics, status: monitor.status)
                    .padding()
            }
            .menuBarExtraStyle(.window)
            .symbolVariant(.fill)
            .accentColor(monitor.status.accentColor)
        }

        Settings {
            SettingsView(
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled
            )
        }
    }

    private func updateMenuBarInsertion(for status: ActivityStatus) {
        guard isMenuIconEnabled else {
            isMenuBarInserted = false
            return
        }

        if menuIconOnlyWhenHigh {
            isMenuBarInserted = status == .critical
        } else {
            isMenuBarInserted = true
        }
    }
}
