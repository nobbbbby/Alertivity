import SwiftUI
import AppKit

private let highActivityDurationOptions: [Int] = [30, 60, 120,  240, 600]
private let highActivityCPUThresholdOptions: [Int] = Array(stride(from: 20, through: 100, by: 15))
private let highActivityMemoryThresholdOptions: [Int] = Array(stride(from: 5, through: 50, by: 5))
    
private let tabPadding: EdgeInsets = EdgeInsets(top: 24, leading: 45, bottom: 28, trailing: 45)

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Hide app icon in Dock", isOn: $settings.hideDockIcon)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(tabPadding)
            .tabItem { Label("General", systemImage: "switch.2") }

            VStack(alignment: .leading, spacing: 12) {
                MenuBarSettingsFields(
                    isMenuIconEnabled: $settings.isMenuIconEnabled,
                    menuIconOnlyWhenHigh: $settings.menuIconOnlyWhenHigh,
                    menuIconType: $settings.menuIconType,
                    showMetricIcon: $settings.showMetricIcon,
                    autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled
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
                NotificationSettingsFields(notificationsEnabled: $settings.notificationsEnabled)

                Text("Notifications fire when status is critical or a process crosses the high-activity rule.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)


                DetectionSettingsFields(
                    highActivityDurationSeconds: $settings.highActivityDurationSeconds,
                    highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                    highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent
                )

                Text("Flags processes over \(settings.highActivityCPUThresholdPercent)% CPU or \(settings.highActivityMemoryThresholdPercent)% memory for \(settings.highActivityDurationSeconds) seconds.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(tabPadding)
            .tabItem { Label("Notifications", systemImage: "bell") }
        }
        .frame(minWidth: 420)
    }
}
struct NoticePreferencesView: View {
    @ObservedObject var settings: SettingsStore

    @ViewBuilder
    var body: some View {
        Section("Menu Bar") {
            MenuBarSettingsFields(
                isMenuIconEnabled: $settings.isMenuIconEnabled,
                menuIconOnlyWhenHigh: $settings.menuIconOnlyWhenHigh,
                menuIconType: $settings.menuIconType,
                showMetricIcon: $settings.showMetricIcon,
                autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled
            )
        }

        Section("Notifications") {
            NotificationSettingsFields(notificationsEnabled: $settings.notificationsEnabled)

            Text("Notifications fire when status is critical or a process crosses the high-activity rule.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DetectionSettingsFields(
                highActivityDurationSeconds: $settings.highActivityDurationSeconds,
                highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent
            )

            Text("Flags processes over \(settings.highActivityCPUThresholdPercent)% CPU or \(settings.highActivityMemoryThresholdPercent)% memory for \(settings.highActivityDurationSeconds) seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MenuStatusView: View {
    let metrics: ActivityMetrics

    var body: some View {
        let displayStatus = ActivityStatus(metrics: metrics)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: displayStatus.symbolName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(displayStatus.iconTint ?? .primary, .secondary)
                    .font(.system(size: 18, weight: .medium))

                Text(displayStatus.title(for: metrics))
                    .font(.system(size: 15, weight: .semibold))

                Spacer(minLength: 0)
            }

            Text(displayStatus.menuSummary(for: metrics))
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
                    value: metrics.disk.formattedReadWriteSummary
                )

                MenuMetricRow(
                    systemImage: "arrow.up.arrow.down",
                    value: "↓ \(metrics.network.formattedDownload)/s • ↑ \(metrics.network.formattedUpload)/s"
                )
                
                if displayStatus.trigger != .disk && !metrics.highActivityProcesses.isEmpty {
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
            
            let cpuText = Text("CPU \(process.cpuDescription)")
                .fontWeight(process.triggeredByCPU ? .semibold : .regular)
            let memoryText = Text("Mem \(process.memoryDescription)")
                .fontWeight(process.triggeredByMemory ? .semibold : .regular)
            
            (cpuText + Text(" • ") + memoryText)
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
    @StateObject private var settings: SettingsStore

    init() {
        let defaults = UserDefaults(suiteName: "NoticePreferencesPreview") ?? .standard
        defaults.removePersistentDomain(forName: "NoticePreferencesPreview")
        let store = SettingsStore(userDefaults: defaults)
        store.isMenuIconEnabled = true
        store.menuIconOnlyWhenHigh = false
        store.notificationsEnabled = true
        store.menuIconType = .status
        store.showMetricIcon = true
        store.isMenuIconAutoSwitchEnabled = false
        store.highActivityDurationSeconds = highActivityDurationOptions[3]
        store.highActivityCPUThresholdPercent = highActivityCPUThresholdOptions[3]
        store.highActivityMemoryThresholdPercent = highActivityMemoryThresholdOptions[2]
        _settings = StateObject(wrappedValue: store)
    }

    var body: some View {
        Form {
            NoticePreferencesView(settings: settings)
        }
    }
}

#Preview("Settings") {
    let defaults = UserDefaults(suiteName: "SettingsPreview") ?? .standard
    defaults.removePersistentDomain(forName: "SettingsPreview")
    let store = SettingsStore(userDefaults: defaults)
    store.hideDockIcon = false
    store.launchAtLogin = false
    store.isMenuIconEnabled = true
    store.menuIconOnlyWhenHigh = false
    store.showMetricIcon = true
    store.menuIconType = .status
    store.isMenuIconAutoSwitchEnabled = false
    store.highActivityDurationSeconds = highActivityDurationOptions[3]
    store.highActivityCPUThresholdPercent = highActivityCPUThresholdOptions[2]
    store.highActivityMemoryThresholdPercent = highActivityMemoryThresholdOptions[2]
    return SettingsView(settings: store)
        .frame(width: 520)
}

#Preview("Notice Preferences") {
    NoticePreferencesPreviewContainer()
        .frame(width: 420)
}


#Preview("Menu Status – Normal") {
    MenuStatusView(metrics: .previewNormal)
        .frame(width: 240)
        .padding()
}

#Preview("Menu Status – Elevated") {
    MenuStatusView(metrics: .previewElevated)
        .frame(width: 240)
        .padding()
}

#Preview("Menu Status – Critical") {
    MenuStatusView(metrics: .previewCritical)
        .frame(width: 240)
        .padding()
}

#Preview("Menu Status – Multi Elevated") {
    let metrics = ActivityMetrics.previewMultiElevated
    MenuStatusView(metrics: metrics)
        .frame(width: 240)
        .padding()
}

#Preview("Menu Status – Critical + Elevated") {
    let metrics = ActivityMetrics.previewCriticalWithMemoryElevated
    MenuStatusView(metrics: metrics)
        .frame(width: 240)
        .padding()
}

#Preview("Menu Status – Multi Critical") {
    let metrics = ActivityMetrics.previewMultiCritical
    MenuStatusView(metrics: metrics)
        .frame(width: 240)
        .padding()
}

#Preview("Menu Status – Disk Critical") {
    let metrics = ActivityMetrics.previewDiskCritical
    MenuStatusView(metrics: metrics)
        .frame(width: 240)
        .padding()
}

#Preview("Status Messages") {
    let samples: [(title: String, metrics: ActivityMetrics)] = [
        ("Normal", .previewNormal),
        ("Elevated CPU", .previewElevated),
        ("Critical CPU", .previewCritical),
        ("Critical CPU + Memory Elevated", .previewCriticalWithMemoryElevated)
    ]

    VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(samples.enumerated()), id: \.0) { _, sample in
            let status = ActivityStatus(metrics: sample.metrics)
            VStack(alignment: .leading, spacing: 4) {
                Text(sample.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(status.title(for: sample.metrics))
                    .font(.headline)
                Text(status.message(for: sample.metrics))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
    .frame(width: 420, alignment: .leading)
}



#Preview("Process Row") {
    let sample = ProcessUsage.preview.first ?? ProcessUsage(
        pid: 4242,
        command: "/Applications/Preview.app/Contents/MacOS/Preview",
        cpuPercent: 0.42,
        memoryPercent: 0.08,
        triggers: [.cpu]
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
    @Binding var highActivityMemoryThresholdPercent: Int

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

        Picker("Memory threshold:", selection: $highActivityMemoryThresholdPercent) {
            ForEach(highActivityMemoryThresholdOptions, id: \.self) { value in
                Text("\(value)%").tag(value)
            }
        }
        .pickerStyle(.menu)
    }
}
