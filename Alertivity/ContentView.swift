import SwiftUI
import AppKit

private let highActivityDurationOptions: [Int] = [30, 60, 120,  240, 600]
private let highActivityCPUThresholdOptions: [Int] = Array(stride(from: 20, through: 100, by: 15))
    
private let tabPadding: EdgeInsets = EdgeInsets(top: 24, leading: 45, bottom: 28, trailing: 45)

struct SettingsView: View {
    @AppStorage("app.hideDockIcon") private var hideDockIcon = false
    @AppStorage("app.launchAtLogin") private var launchAtLogin = false
    @AppStorage("notice.menu.enabled") private var isMenuIconEnabled = true
    @AppStorage("notice.menu.onlyHigh") private var menuIconOnlyWhenHigh = false
    @AppStorage("notice.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("notice.menu.iconType") private var menuIconType = MenuIconType.status
    @AppStorage("notice.menu.showMetricIcon") private var showMetricIcon = false
    @AppStorage("notice.menu.autoSwitch") private var isMenuIconAutoSwitchEnabled = false
    @AppStorage("monitor.topProcesses.duration") private var highActivityDurationSeconds = 120
    @AppStorage("monitor.topProcesses.cpuThresholdPercent") private var highActivityCPUThresholdPercent = 20

    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Hide app icon in Dock", isOn: $hideDockIcon)
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(tabPadding)
            .tabItem { Label("General", systemImage: "switch.2") }

            VStack(alignment: .leading, spacing: 12) {
                MenuBarSettingsFields(
                    isMenuIconEnabled: $isMenuIconEnabled,
                    menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                    menuIconType: $menuIconType,
                    showMetricIcon: $showMetricIcon,
                    autoSwitchEnabled: $isMenuIconAutoSwitchEnabled
                )

                Text("Choose when the indicator appears and what it shows.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(tabPadding)
            .tabItem { Label("Menu Bar", systemImage: "waveform") }

            VStack(alignment: .leading, spacing: 12) {
                NotificationSettingsFields(notificationsEnabled: $notificationsEnabled)

                Text("Notifications fire when status is critical or a process crosses the high-activity rule.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(tabPadding)
            .tabItem { Label("Notifications", systemImage: "bell") }

            VStack(alignment: .leading, spacing: 12) {
                DetectionSettingsFields(
                    highActivityDurationSeconds: $highActivityDurationSeconds,
                    highActivityCPUThresholdPercent: $highActivityCPUThresholdPercent
                )

                Text("Flags processes over \(highActivityCPUThresholdPercent)% for \(highActivityDurationSeconds) seconds.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(tabPadding)
            .tabItem { Label("Detection", systemImage: "gearshape") }
        }
        .frame(minWidth: 420)
    }
}
struct NoticePreferencesView: View {
    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var menuIconType: MenuIconType
    @Binding var showMetricIcon: Bool
    @Binding var menuIconAutoSwitchEnabled: Bool
    @Binding var highActivityDurationSeconds: Int
    @Binding var highActivityCPUThresholdPercent: Int

    @ViewBuilder
    var body: some View {
        Section("Menu Bar") {
            MenuBarSettingsFields(
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                menuIconType: $menuIconType,
                showMetricIcon: $showMetricIcon,
                autoSwitchEnabled: $menuIconAutoSwitchEnabled
            )
        }

        Section("Notifications") {
            NotificationSettingsFields(notificationsEnabled: $notificationsEnabled)

            Text("Notifications fire when status is critical or a process crosses the high-activity rule.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        Section("Detection") {
            DetectionSettingsFields(
                highActivityDurationSeconds: $highActivityDurationSeconds,
                highActivityCPUThresholdPercent: $highActivityCPUThresholdPercent
            )

            Text("Flags processes over \(highActivityCPUThresholdPercent)% for \(highActivityDurationSeconds) seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MenuStatusView: View {
    let metrics: ActivityMetrics
    let status: ActivityStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: status.symbolName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(status.accentColor, .secondary)
                    .font(.system(size: 18, weight: .medium))

                Text(status.title)
                    .font(.system(size: 15, weight: .semibold))

                Spacer(minLength: 0)
            }

            Text(status.message(for: metrics))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            if metrics.hasLiveData {
                MenuMetricRow(
                    systemImage: "cpu",
                    value: metrics.cpuUsage.formatted(.percent.precision(.fractionLength(0)))
                )

                MenuMetricRow(
                    systemImage: "memorychip",
                    value: metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
                )

                MenuMetricRow(
                    systemImage: "internaldrive",
                    value: metrics.disk.usage.formatted(.percent.precision(.fractionLength(0)))
                )

                MenuMetricRow(
                    systemImage: "arrow.up.arrow.down",
                    value: "↓ \(metrics.network.formattedDownload)/s • ↑ \(metrics.network.formattedUpload)/s"
                )
                
                if status.trigger != .disk && !metrics.highActivityProcesses.isEmpty {
                    Divider()
                    Text("High-activity processes")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    ForEach(Array(metrics.highActivityProcesses)) { process in
                        HStack {
                            Button {
                                ProcessActions.revealInActivityMonitor(process)
                            } label: {
                                MenuProcessRow(process: process)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button("", systemImage: "xmark.circle") {
                                ProcessActions.terminate(process)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressView()
                    Text("Metrics will appear once the first sample is available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 220, alignment: .leading)
    }
}

private struct MenuMetricRow: View {
    let systemImage: String
    let title: String?
    let value: String

    init(systemImage: String, title: String? = nil, value: String) {
        self.systemImage = systemImage
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20, alignment: .center)

            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

private struct MenuProcessRow: View {
    let process: ProcessUsage
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 12) {
                let path = process.command
                let appPath: String = {
                    if let range = path.range(of: ".app/") {
                        return String(path[..<range.lowerBound]) + ".app"
                    } else {
                        return path
                    }
                }()
                let nsImage = NSWorkspace.shared.icon(forFile: appPath)
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 16, height: 16)
                
                Text(process.displayName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(.none)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Text("CPU \(process.cpuDescription) • Mem \(process.memoryDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(.none)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(.vertical, 6)
//        .padding(.horizontal, )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(isHovering ? 0.14 : 0))
        )
        .contentShape(Rectangle())
        .onHover { over in
            isHovering = over
        }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}

// MARK: - Previews

#if DEBUG
private struct NoticePreferencesPreviewContainer: View {
    @State private var isMenuIconEnabled = true
    @State private var menuIconOnlyWhenHigh = false
    @State private var notificationsEnabled = true
    @State private var menuIconType: MenuIconType = .status
    @State private var showMetricIcon = true
    @State private var menuIconAutoSwitchEnabled = false
    @State private var highActivityDurationSeconds = highActivityDurationOptions[3]
    @State private var highActivityCPUThresholdPercent = highActivityCPUThresholdOptions[3]

    var body: some View {
        Form {
            NoticePreferencesView(
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled,
                menuIconType: $menuIconType,
                showMetricIcon: $showMetricIcon,
                menuIconAutoSwitchEnabled: $menuIconAutoSwitchEnabled,
                highActivityDurationSeconds: $highActivityDurationSeconds,
                highActivityCPUThresholdPercent: $highActivityCPUThresholdPercent
            )
        }
    }
}

#Preview("Settings") {
    SettingsView()
        .frame(width: 520)
}

#Preview("Notice Preferences") {
    NoticePreferencesPreviewContainer()
        .frame(width: 420)
}


#Preview("Menu Status – Normal") {
    MenuStatusView(metrics: .previewNormal, status: .normal)
        .frame(width: 240)
        .padding()
}

#Preview("Menu Status – Elevated") {
    MenuStatusView(metrics: .previewElevated, status: .elevated)
        .frame(width: 240)
        .padding()
}

#Preview("Menu Status – Critical") {
    MenuStatusView(metrics: .previewCritical, status: .critical)
        .frame(width: 240)
        .padding()
}



#Preview("Process Row") {
    let sample = ProcessUsage.preview.first ?? ProcessUsage(
        pid: 4242,
        command: "/Applications/Preview.app/Contents/MacOS/Preview",
        cpuPercent: 0.42,
        memoryPercent: 0.08
    )

    MenuProcessRow(process: sample)
        .frame(width: 260)
        .padding()
}
#endif

// MARK: - Shared Settings Controls

private struct MenuBarSettingsFields: View {
    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var menuIconType: MenuIconType
    @Binding var showMetricIcon: Bool
    @Binding var autoSwitchEnabled: Bool

    var body: some View {
        Toggle("Show indicator", isOn: $isMenuIconEnabled)
        Picker("Default icon type:", selection: $menuIconType) {
            ForEach(MenuIconType.allCases) { iconType in
                Label(iconType.title, systemImage: iconType.symbolName)
                    .tag(iconType)
            }
        }
        .disabled(!isMenuIconEnabled)
        .pickerStyle(.menu)

        let autoSwitchBinding = Binding<Bool>(
            get: { autoSwitchEnabled },
            set: { newValue in
                autoSwitchEnabled = newValue
                if newValue && !showMetricIcon {
                    showMetricIcon = true
                }
            }
        )

        Toggle("Auto switch to busiest metric", isOn: autoSwitchBinding)
            .disabled(!isMenuIconEnabled)

        Text("Auto switch shows the busiest metric; when activity is normal it uses your Default icon type.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 18)
            .padding(.bottom, 2)

        Toggle("Only show on high activity", isOn: $menuIconOnlyWhenHigh)
            .disabled(!isMenuIconEnabled)

        if menuIconType.metricSelection != nil || autoSwitchEnabled {
            Toggle("Show metric icon", isOn: $showMetricIcon)
                .disabled(!isMenuIconEnabled || autoSwitchEnabled)
        }
    }
}

private struct NotificationSettingsFields: View {
    @Binding var notificationsEnabled: Bool

    var body: some View {
        Toggle("Enable system notifications", isOn: $notificationsEnabled)
    }
}

private struct DetectionSettingsFields: View {
    @Binding var highActivityDurationSeconds: Int
    @Binding var highActivityCPUThresholdPercent: Int

    var body: some View {
        Picker("High activity duration:", selection: $highActivityDurationSeconds) {
            ForEach(highActivityDurationOptions, id: \.self) { value in
                Text("\(value) seconds").tag(value)
            }
        }
        .pickerStyle(.menu)

        Picker("CPU threshold:", selection: $highActivityCPUThresholdPercent) {
            ForEach(highActivityCPUThresholdOptions, id: \.self) { value in
                Text("\(value)%").tag(value)
            }
        }
        .pickerStyle(.menu)
    }
}
