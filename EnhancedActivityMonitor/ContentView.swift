import SwiftUI
import AppKit

private let highActivityDurationOptions: [Int] = [30, 60, 120,  240, 600]
private let highActivityCPUThresholdOptions: [Int] = Array(stride(from: 20, through: 100, by: 15))

struct SettingsView: View {
    @AppStorage("notice.menu.enabled") private var isMenuIconEnabled = true
    @AppStorage("notice.menu.onlyHigh") private var menuIconOnlyWhenHigh = false
    @AppStorage("notice.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("notice.menu.iconType") private var menuIconType = MenuIconType.status
    @AppStorage("notice.menu.showMetricIcon") private var showMetricIcon = false
    @AppStorage("monitor.topProcesses.duration") private var highActivityDurationSeconds = 120
    @AppStorage("monitor.topProcesses.cpuThresholdPercent") private var highActivityCPUThresholdPercent = 20

    var body: some View {
        TabView {
            // Menu Bar tab
            VStack(alignment: .leading, spacing: 12) {
                MenuBarSettingsFields(
                    isMenuIconEnabled: $isMenuIconEnabled,
                    menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                    menuIconType: $menuIconType,
                    showMetricIcon: $showMetricIcon
                )

                Divider()
                Text("Display an activity indicator in the menu bar and choose when it appears.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(.none)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal,50)
            .tabItem { Label("Menu Bar", systemImage: "waveform") }

            // Notifications tab
            VStack(alignment: .leading, spacing: 12) {
                NotificationSettingsFields(notificationsEnabled: $notificationsEnabled)

                Divider()
                Text("Deliver macOS notifications whenever activity is critical or a process spikes usage.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(.none)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal,50)
            .tabItem { Label("Notifications", systemImage: "bell") }

            // Detection Settings tab
            VStack(alignment: .leading, spacing: 12) {
                DetectionSettingsFields(
                    highActivityDurationSeconds: $highActivityDurationSeconds,
                    highActivityCPUThresholdPercent: $highActivityCPUThresholdPercent
                )

                Divider()
                Text("Processes must exceed the CPU threshold for the selected duration before they're marked as high activity.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal,50)
            .tabItem { Label("Detection", systemImage: "gearshape") }
        }
    .padding(.vertical, 20)
    .frame(minWidth: 420)
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
                highActivityDurationSeconds: $highActivityDurationSeconds,
                highActivityCPUThresholdPercent: $highActivityCPUThresholdPercent
            )
        }
    }
}

#Preview("Settings") {
    SettingsView()
        .frame(width: 420)
}

#Preview("Notice Preferences") {
    NoticePreferencesPreviewContainer()
        .frame(width: 360)
}

struct NoticePreferencesView: View {
    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var menuIconType: MenuIconType
    @Binding var showMetricIcon: Bool
    @Binding var highActivityDurationSeconds: Int
    @Binding var highActivityCPUThresholdPercent: Int

    @ViewBuilder
    var body: some View {
        Section {
            MenuBarSettingsFields(
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                menuIconType: $menuIconType,
                showMetricIcon: $showMetricIcon
            )
        } header: {
            Text("Menu Bar")
        } footer: {
            Text("Display an activity indicator in the menu bar and choose when it appears.")
        }

        Section {
            NotificationSettingsFields(notificationsEnabled: $notificationsEnabled)
        } header: {
            Text("Notifications")
        } footer: {
            Text("Deliver macOS notifications whenever activity is critical or a process spikes usage.")
        }

        Section {
            DetectionSettingsFields(
                highActivityDurationSeconds: $highActivityDurationSeconds,
                highActivityCPUThresholdPercent: $highActivityCPUThresholdPercent
            )
        } header: {
            Text("Detection Settings")
        } footer: {
            Text("Processes must exceed the CPU threshold for the selected duration before they're marked as high activity.")
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

                MenuMetricRow(
                    systemImage: "gearshape",
                    value: "\(metrics.runningProcesses)"
                )
                
                if !metrics.highActivityProcesses.isEmpty {
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

    var body: some View {
        Toggle("Show indicator", isOn: $isMenuIconEnabled)

        Toggle("Only show on high activity", isOn: $menuIconOnlyWhenHigh)
            .disabled(!isMenuIconEnabled)

        Picker("Icon type:", selection: $menuIconType) {
            ForEach(MenuIconType.allCases) { iconType in
                Label(iconType.title, systemImage: iconType.symbolName)
                    .tag(iconType)
            }
        }
        .disabled(!isMenuIconEnabled)
        .pickerStyle(.menu)

        if menuIconType.metricSelection != nil {
            Toggle("Show metric icon", isOn: $showMetricIcon)
                .disabled(!isMenuIconEnabled)
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
