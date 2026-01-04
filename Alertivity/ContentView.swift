import SwiftUI
import AppKit

private let highActivityDurationOptions: [Int] = [30, 60, 120,  240, 600]
private let highActivityCPUThresholdOptions: [Int] = Array(stride(from: 20, through: 100, by: 15))
private let highActivityMemoryThresholdOptions: [Int] = Array(stride(from: 5, through: 50, by: 5))
    
private let tabPadding: EdgeInsets = EdgeInsets(top: 24, leading: 45, bottom: 28, trailing: 45)

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let processSamplingAvailable: Bool

    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("settings.toggle.hideDockIcon", isOn: $settings.hideDockIcon)
                Toggle("settings.toggle.launchAtLogin", isOn: $settings.launchAtLogin)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(tabPadding)
            .tabItem { Label("settings.tab.general", systemImage: "switch.2") }

            VStack(alignment: .leading, spacing: 12) {
                MenuBarSettingsFields(
                    isMenuIconEnabled: $settings.isMenuIconEnabled,
                    menuIconOnlyWhenHigh: $settings.menuIconOnlyWhenHigh,
                    menuIconType: $settings.menuIconType,
                    showMetricIcon: $settings.showMetricIcon,
                    autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled
                )
                
                Divider()
                
                Text("settings.menuBar.help")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(tabPadding)
            .tabItem { Label("settings.tab.menuBar", systemImage: "waveform.path.ecg") }

            VStack(alignment: .leading, spacing: 12) {
                
                    NotificationSettingsFields(
                        notificationsEnabled: $settings.notificationsEnabled,
                        highActivityDurationSeconds: $settings.highActivityDurationSeconds,
                        processSamplingAvailable: processSamplingAvailable,
                        durationSeconds: settings.highActivityDurationSeconds
                    )
                

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(tabPadding)
            .tabItem { Label("settings.tab.notifications", systemImage: "bell") }

            if processSamplingAvailable {
                VStack(alignment: .leading, spacing: 12) {
                    DetectionSettingsFields(
                        highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                        highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent
                    )

                    Divider()

                    Text(L10n.format(
                        "settings.detection.flags",
                        settings.highActivityCPUThresholdPercent,
                        settings.highActivityMemoryThresholdPercent,
                        settings.highActivityDurationSeconds
                    ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(tabPadding)
                .tabItem { Label("settings.tab.detection", systemImage: "scope") }
            }
        }
        .frame(minWidth: 420)
    }
}
struct NoticePreferencesView: View {
    @ObservedObject var settings: SettingsStore
    let processSamplingAvailable: Bool

    @ViewBuilder
    var body: some View {
        Section("settings.tab.menuBar") {
            MenuBarSettingsFields(
                isMenuIconEnabled: $settings.isMenuIconEnabled,
                menuIconOnlyWhenHigh: $settings.menuIconOnlyWhenHigh,
                menuIconType: $settings.menuIconType,
                showMetricIcon: $settings.showMetricIcon,
                autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled
            )
        }

        Section("settings.tab.notifications") {
            
                NotificationSettingsFields(
                    notificationsEnabled: $settings.notificationsEnabled,
                    highActivityDurationSeconds: $settings.highActivityDurationSeconds,
                    processSamplingAvailable: processSamplingAvailable,
                    durationSeconds: settings.highActivityDurationSeconds
                )
          
        }

        if processSamplingAvailable {
            Section("settings.tab.detection") {
                DetectionSettingsFields(
                    highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                    highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent
                )

                Divider()

                Text(L10n.format(
                    "settings.detection.flags",
                    settings.highActivityCPUThresholdPercent,
                    settings.highActivityMemoryThresholdPercent,
                    settings.highActivityDurationSeconds
                ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

                Text(displayStatus.menuTitle(for: metrics))
                    .font(.system(size: 15, weight: .semibold))

                Spacer(minLength: 0)
            }

            Text(displayStatus.menuSummary(for: metrics))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text("menu.highActivityProcesses")
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
                    Text("menu.metricsPending")
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
            
            let cpuText = Text(L10n.format("process.row.cpu.format", process.cpuDescription))
                .fontWeight(process.triggeredByCPU ? .semibold : .regular)
            let memoryText = Text(L10n.format("process.row.memory.format", process.memoryDescription))
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

#if DEBUG && !DISABLE_PREVIEWS
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
        store.isMenuIconAutoSwitchEnabled = true
        store.highActivityDurationSeconds = highActivityDurationOptions[1]
        store.highActivityCPUThresholdPercent = highActivityCPUThresholdOptions[4]
        store.highActivityMemoryThresholdPercent = highActivityMemoryThresholdOptions[4]
        _settings = StateObject(wrappedValue: store)
    }

    var body: some View {
        Form {
            NoticePreferencesView(settings: settings, processSamplingAvailable: true)
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
    store.isMenuIconAutoSwitchEnabled = true
    store.highActivityDurationSeconds = highActivityDurationOptions[1]
    store.highActivityCPUThresholdPercent = highActivityCPUThresholdOptions[4]
    store.highActivityMemoryThresholdPercent = highActivityMemoryThresholdOptions[4]
    return SettingsView(settings: store, processSamplingAvailable: true)
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
                Text(status.notificationTitle(for: sample.metrics))
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
        Toggle("settings.menuBar.showIndicator", isOn: $isMenuIconEnabled)
        Picker("settings.menuBar.defaultIconType", selection: $menuIconType) {
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

        VStack(alignment: .leading, spacing: 2) {
            Toggle("settings.menuBar.autoSwitch", isOn: autoSwitchBinding)
                .disabled(!isMenuIconEnabled)

            Text("settings.menuBar.autoSwitch.help")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
//                .padding(.leading, 18)
                .padding(.bottom, 2)
        }

        Toggle("settings.menuBar.onlyShowHigh", isOn: $menuIconOnlyWhenHigh)
            .disabled(!isMenuIconEnabled)

        if menuIconType.metricSelection != nil || autoSwitchEnabled {
            Toggle("settings.menuBar.showMetricIcon", isOn: $showMetricIcon)
                .disabled(!isMenuIconEnabled || autoSwitchEnabled)
        }
    }
}

private struct NotificationSettingsFields: View {
    @Binding var notificationsEnabled: Bool
    @Binding var highActivityDurationSeconds: Int
    let processSamplingAvailable: Bool
    let durationSeconds: Int

    var body: some View {
 
            Toggle("settings.notifications.enable", isOn: $notificationsEnabled)

            Picker("settings.detection.duration", selection: $highActivityDurationSeconds) {
                ForEach(highActivityDurationOptions, id: \.self) { value in
                    Text(L10n.format("settings.detection.durationValue", value)).tag(value)
                }
            }
            .pickerStyle(.menu)
        
            Divider()

            let noteKey = processSamplingAvailable
                ? "settings.notifications.note.direct"
                : "settings.notifications.note.sandbox"
            Text(L10n.format(noteKey, durationSeconds))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
       
    }
}

private struct DetectionSettingsFields: View {
    @Binding var highActivityCPUThresholdPercent: Int
    @Binding var highActivityMemoryThresholdPercent: Int

    var body: some View {
        Picker("settings.detection.cpuThreshold", selection: $highActivityCPUThresholdPercent) {
            ForEach(highActivityCPUThresholdOptions, id: \.self) { value in
                Text(L10n.format("settings.detection.percentValue", value)).tag(value)
            }
        }
        .pickerStyle(.menu)

        Picker("settings.detection.memoryThreshold", selection: $highActivityMemoryThresholdPercent) {
            ForEach(highActivityMemoryThresholdOptions, id: \.self) { value in
                Text(L10n.format("settings.detection.percentValue", value)).tag(value)
            }
        }
        .pickerStyle(.menu)
    }
}
