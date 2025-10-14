import SwiftUI

struct SettingsView: View {
    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var metricMenuIconsEnabled: Bool
    @Binding var cpuMenuIconEnabled: Bool
    @Binding var memoryMenuIconEnabled: Bool
    @Binding var diskMenuIconEnabled: Bool
    @Binding var networkMenuIconEnabled: Bool
    @Binding var processMenuIconEnabled: Bool

    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $isMenuIconEnabled)
                if isMenuIconEnabled {
                    Toggle("Only show when activity is critical", isOn: $menuIconOnlyWhenHigh)
                }

                Toggle("Show metric menu icons", isOn: $metricMenuIconsEnabled)

                if metricMenuIconsEnabled {
                    Toggle("CPU usage", isOn: $cpuMenuIconEnabled)
                    Toggle("Memory usage", isOn: $memoryMenuIconEnabled)
                    Toggle("Disk usage", isOn: $diskMenuIconEnabled)
                    Toggle("Network throughput", isOn: $networkMenuIconEnabled)
                    Toggle("Running processes", isOn: $processMenuIconEnabled)
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

#Preview("Settings • Icon Visible") {
    SettingsView(
        isMenuIconEnabled: .constant(true),
        menuIconOnlyWhenHigh: .constant(false),
        notificationsEnabled: .constant(true),
        metricMenuIconsEnabled: .constant(true),
        cpuMenuIconEnabled: .constant(true),
        memoryMenuIconEnabled: .constant(true),
        diskMenuIconEnabled: .constant(true),
        networkMenuIconEnabled: .constant(true),
        processMenuIconEnabled: .constant(true)
    )
}

#Preview("Settings • Critical Only") {
    SettingsView(
        isMenuIconEnabled: .constant(true),
        menuIconOnlyWhenHigh: .constant(true),
        notificationsEnabled: .constant(false),
        metricMenuIconsEnabled: .constant(false),
        cpuMenuIconEnabled: .constant(false),
        memoryMenuIconEnabled: .constant(false),
        diskMenuIconEnabled: .constant(false),
        networkMenuIconEnabled: .constant(false),
        processMenuIconEnabled: .constant(false)
    )
}
