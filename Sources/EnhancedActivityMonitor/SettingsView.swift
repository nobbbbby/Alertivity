import SwiftUI

struct SettingsView: View {
    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $isMenuIconEnabled)
                if isMenuIconEnabled {
                    Toggle("Only show when activity is critical", isOn: $menuIconOnlyWhenHigh)
                }
            }

            Section("System Notifications") {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                    .toggleStyle(.switch)
                Text("Notifications are sent when the system detects critically high CPU usage.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
