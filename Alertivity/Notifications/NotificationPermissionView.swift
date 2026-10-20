import AppKit
import SwiftUI
import UserNotifications

/// Shared recovery guidance stays available after onboarding, including after a system-level denial.
struct NotificationPermissionView: View {
    @ObservedObject var manager: NotificationManager
    /// Settings omits the success message; onboarding keeps explicit permission feedback.
    var showsAuthorizedStatus = true
    var onEnable: () -> Void = {}
    @Environment(\.scenePhase) private var scenePhase
    @State private var settingsOpenFailed = false

    var body: some View {
        Group {
            // Omit the container too, so the parent adds no spacing for an empty permission section.
            if statusKey != nil || manager.authorizationFailed || settingsOpenFailed {
                VStack(alignment: .leading, spacing: 10) {
                    if let statusKey {
                        Text(statusKey).font(.headline)
                            .accessibilityIdentifier("onboarding.notificationStatus")
                    }
                    if manager.authorizationStatus == .notDetermined {
                        Text("onboarding.notifications.requestHelp")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("onboarding.notifications.allow") {
                            onEnable()
                            manager.requestAuthorizationIfNeeded()
                        }
                        .disabled(manager.isRequestingAuthorization)
                        .accessibilityIdentifier("onboarding.allowNotifications")
                    } else if manager.authorizationStatus == .denied {
                        Text("onboarding.notifications.denied.help")
                        Button("onboarding.systemSettings") { openSystemSettings() }
                    }
                    if manager.authorizationFailed {
                        Text("onboarding.notifications.error")
                            .foregroundStyle(.red)
                    }
                    if settingsOpenFailed {
                        Text("onboarding.systemSettings.error")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .task { await manager.refreshAuthorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await manager.refreshAuthorizationStatus() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await manager.refreshAuthorizationStatus() }
        }
    }

    private var statusKey: LocalizedStringKey? {
        switch manager.authorizationStatus {
        case .notDetermined: "onboarding.notifications.pending"
        case .denied: "onboarding.notifications.denied"
        case .authorized, .provisional, .ephemeral:
            showsAuthorizedStatus ? "onboarding.notifications.authorized" : nil
        @unknown default: "onboarding.notifications.unknown"
        }
    }

    private func openSystemSettings() {
        // Launch the system app using its bundle identifier; avoid undocumented preference-pane URLs.
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") else {
            settingsOpenFailed = true
            AppLogger.lifecycle.error("System Settings application could not be located")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            Task { @MainActor in
                settingsOpenFailed = error != nil
                if let error {
                    AppLogger.lifecycle.error("Opening System Settings failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}
