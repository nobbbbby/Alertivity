import AppKit
import SwiftUI

private let settingsTabPadding = EdgeInsets(top: 24, leading: 45, bottom: 28, trailing: 45)

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let processSamplingAvailable: Bool

    var body: some View {
        TabView {
            SettingsTab(title: "settings.tab.general", systemImage: "switch.2") {
                Toggle("settings.toggle.hideDockIcon", isOn: $settings.hideDockIcon)
                Toggle("settings.toggle.launchAtLogin", isOn: $settings.launchAtLogin)
            }

            SettingsTab(title: "settings.tab.menuBar", systemImage: "waveform.path.ecg") {
                MenuBarSettingsFields(
                    isMenuIconEnabled: $settings.isMenuIconEnabled,
                    menuIconOnlyWhenHigh: $settings.menuIconOnlyWhenHigh,
                    menuIconType: $settings.menuIconType,
                    showMetricIcon: $settings.showMetricIcon,
                    autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled
                )

                FooterDivider()

                SettingsFootnote(key: "settings.menuBar.help", weight: .semibold)
            }

            SettingsTab(title: "settings.tab.notifications", systemImage: "bell") {
                NotificationSettingsFields(
                    notificationsEnabled: $settings.notificationsEnabled,
                    highActivityDurationSeconds: $settings.highActivityDurationSeconds,
                    processSamplingAvailable: processSamplingAvailable,
                    emphasizesFooter: true
                )
            }

            if processSamplingAvailable {
                SettingsTab(title: "settings.tab.detection", systemImage: "scope") {
                    DetectionSettingsFields(
                        highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                        highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent
                    )

                    Divider()

                    IgnoredProcessSettingsView(settings: settings)

                    FooterDivider()

                    DetectionSettingsFooter(
                        highActivityCPUThresholdPercent: settings.highActivityCPUThresholdPercent,
                        highActivityMemoryThresholdPercent: settings.highActivityMemoryThresholdPercent,
                        highActivityDurationSeconds: settings.highActivityDurationSeconds,
                        emphasizesFooter: true
                    )
                }
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
                emphasizesFooter: false
            )
        }

        if processSamplingAvailable {
            Section("settings.tab.detection") {
                DetectionSettingsFields(
                    highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                    highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent
                )

                IgnoredProcessSettingsView(settings: settings)

                FooterDivider()

                DetectionSettingsFooter(
                    highActivityCPUThresholdPercent: settings.highActivityCPUThresholdPercent,
                    highActivityMemoryThresholdPercent: settings.highActivityMemoryThresholdPercent,
                    highActivityDurationSeconds: settings.highActivityDurationSeconds,
                    emphasizesFooter: false
                )
            }
        }
    }
}

private struct SettingsTab<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let content: Content

    init(
        title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(settingsTabPadding)
        .tabItem { Label(title, systemImage: systemImage) }
    }
}

private struct SettingsFootnote: View {
    let key: LocalizedStringKey
    var weight: Font.Weight = .regular

    var body: some View {
        Text(key)
            .font(.footnote.weight(weight))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FooterDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, -12)
    }
}

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

        VStack(alignment: .leading, spacing: 2) {
            Toggle("settings.menuBar.autoSwitch", isOn: autoSwitchBinding)
                .disabled(!isMenuIconEnabled)

            SettingsFootnote(key: "settings.menuBar.autoSwitch.help")
                .padding(.bottom, 2)
        }

        Toggle("settings.menuBar.onlyShowHigh", isOn: $menuIconOnlyWhenHigh)
            .disabled(!isMenuIconEnabled)

        if menuIconType.metricSelection != nil || autoSwitchEnabled {
            Toggle("settings.menuBar.showMetricIcon", isOn: $showMetricIcon)
                .disabled(!isMenuIconEnabled || autoSwitchEnabled)
        }
    }

    private var autoSwitchBinding: Binding<Bool> {
        Binding(
            get: { autoSwitchEnabled },
            set: { newValue in
                autoSwitchEnabled = newValue
                if newValue {
                    showMetricIcon = true
                }
            }
        )
    }
}

private struct NotificationSettingsFields: View {
    @Binding var notificationsEnabled: Bool
    @Binding var highActivityDurationSeconds: Int
    let processSamplingAvailable: Bool
    let emphasizesFooter: Bool

    var body: some View {
        Toggle("settings.notifications.enable", isOn: $notificationsEnabled)

        Picker("settings.detection.duration", selection: $highActivityDurationSeconds) {
            ForEach(MonitoringPreferences.durationOptions, id: \.self) { value in
                Text(L10n.format("settings.detection.durationValue", value)).tag(value)
            }
        }
        .pickerStyle(.menu)

        FooterDivider()

        Text(L10n.format(notificationNoteKey, highActivityDurationSeconds))
            .font(.footnote.weight(emphasizesFooter ? .semibold : .regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var notificationNoteKey: String {
        processSamplingAvailable
            ? "settings.notifications.note.direct"
            : "settings.notifications.note.sandbox"
    }
}

private struct DetectionSettingsFields: View {
    @Binding var highActivityCPUThresholdPercent: Int
    @Binding var highActivityMemoryThresholdPercent: Int

    var body: some View {
        Picker("settings.detection.cpuThreshold", selection: $highActivityCPUThresholdPercent) {
            ForEach(MonitoringPreferences.cpuThresholdOptions, id: \.self) { value in
                Text(L10n.format("settings.detection.percentValue", value)).tag(value)
            }
        }
        .pickerStyle(.menu)

        Picker("settings.detection.memoryThreshold", selection: $highActivityMemoryThresholdPercent) {
            ForEach(MonitoringPreferences.memoryThresholdOptions, id: \.self) { value in
                Text(L10n.format("settings.detection.percentValue", value)).tag(value)
            }
        }
        .pickerStyle(.menu)
    }
}

private struct DetectionSettingsFooter: View {
    let highActivityCPUThresholdPercent: Int
    let highActivityMemoryThresholdPercent: Int
    let highActivityDurationSeconds: Int
    let emphasizesFooter: Bool

    var body: some View {
        Text(L10n.format(
            "settings.detection.flags",
            highActivityCPUThresholdPercent,
            highActivityMemoryThresholdPercent,
            highActivityDurationSeconds
        ))
            .font(.footnote.weight(emphasizesFooter ? .semibold : .regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct IgnoredProcessSettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var isShowingInvalidSelectionAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("settings.ignoredProcesses.title")
                    .font(.headline)

                Spacer()

                Button {
                    chooseProcess()
                } label: {
                    Label("settings.ignoredProcesses.add", systemImage: "plus")
                }
            }

            Text("settings.ignoredProcesses.help")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !settings.ignoredProcessPaths.isEmpty {
                VStack(spacing: 0) {
                    ForEach(settings.ignoredProcessPaths, id: \.self) { path in
                        IgnoredProcessRow(path: path) {
                            settings.removeIgnoredProcess(at: path)
                        }

                        if path != settings.ignoredProcessPaths.last {
                            Divider()
                        }
                    }
                }
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert("settings.ignoredProcesses.invalid.title", isPresented: $isShowingInvalidSelectionAlert) {
            Button("general.ok", role: .cancel) {}
        } message: {
            Text("settings.ignoredProcesses.invalid.message")
        }
    }

    @MainActor
    private func chooseProcess() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.prompt = L10n.string("settings.ignoredProcesses.add")
        panel.message = L10n.string("settings.ignoredProcesses.picker.message")

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        let executableURL: URL?
        if selectedURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
            executableURL = Bundle(url: selectedURL)?.executableURL
        } else if FileManager.default.isExecutableFile(atPath: selectedURL.path) {
            executableURL = selectedURL
        } else {
            executableURL = nil
        }

        guard let executableURL else {
            isShowingInvalidSelectionAlert = true
            return
        }

        settings.ignoreProcess(at: executableURL.path)
    }
}

private struct IgnoredProcessRow: View {
    let path: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: processIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .lineLimit(1)
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(path)
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("settings.ignoredProcesses.remove"))
        }
        .padding(8)
    }

    private var processIcon: NSImage {
        NSWorkspace.shared.icon(forFile: iconFilePath)
    }

    private var iconFilePath: String {
        var url = URL(fileURLWithPath: path)

        while url.path != "/" {
            if url.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                return url.path
            }

            url.deleteLastPathComponent()
        }

        return path
    }
}

#if DEBUG && !DISABLE_PREVIEWS
private struct SettingsPreviewContainer: View {
    @StateObject private var settings: SettingsStore
    let processSamplingAvailable: Bool

    init(suiteName: String, paths: [String] = [], processSamplingAvailable: Bool = true) {
        _settings = StateObject(
            wrappedValue: PreviewSettingsStore.make(
                suiteName: suiteName,
                ignoredProcessPaths: paths
            )
        )
        self.processSamplingAvailable = processSamplingAvailable
    }

    var body: some View {
        SettingsView(
            settings: settings,
            processSamplingAvailable: processSamplingAvailable
        )
    }
}

private struct NoticePreferencesPreviewContainer: View {
    @StateObject private var settings = PreviewSettingsStore.make(suiteName: "NoticePreferencesPreview")

    var body: some View {
        Form {
            NoticePreferencesView(settings: settings, processSamplingAvailable: true)
        }
    }
}

private struct IgnoredProcessesPreviewContainer: View {
    @StateObject private var settings: SettingsStore

    init(suiteName: String, paths: [String]) {
        _settings = StateObject(
            wrappedValue: PreviewSettingsStore.make(
                suiteName: suiteName,
                ignoredProcessPaths: paths
            )
        )
    }

    var body: some View {
        IgnoredProcessSettingsView(settings: settings)
            .padding(settingsTabPadding)
    }
}

private enum PreviewSettingsStore {
    static func make(
        suiteName: String,
        ignoredProcessPaths: [String] = []
    ) -> SettingsStore {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(userDefaults: defaults)
        store.isMenuIconEnabled = true
        store.showMetricIcon = true
        store.isMenuIconAutoSwitchEnabled = true
        store.highActivityDurationSeconds = MonitoringPreferences.durationOptions[1]
        store.highActivityCPUThresholdPercent = MonitoringPreferences.cpuThresholdOptions[4]
        store.highActivityMemoryThresholdPercent = MonitoringPreferences.memoryThresholdOptions[4]
        for path in ignoredProcessPaths {
            store.ignoreProcess(at: path)
        }
        return store
    }
}

#Preview("Settings — Empty Whitelist") {
    SettingsPreviewContainer(suiteName: "SettingsEmptyWhitelistPreview")
        .frame(width: 520)
}

#Preview("Settings — Populated Whitelist") {
    SettingsPreviewContainer(
        suiteName: "SettingsPopulatedWhitelistPreview",
        paths: [
            "/Applications/Xcode.app/Contents/MacOS/Xcode",
            "/Applications/Safari.app/Contents/MacOS/Safari"
        ]
    )
    .frame(width: 520)
}

#Preview("Settings — Limited Monitoring") {
    SettingsPreviewContainer(
        suiteName: "SettingsLimitedMonitoringPreview",
        processSamplingAvailable: false
    )
    .frame(width: 520)
}

#Preview("Notice Preferences") {
    NoticePreferencesPreviewContainer()
        .frame(width: 420)
}

#Preview("Ignored Processes — Empty") {
    IgnoredProcessesPreviewContainer(
        suiteName: "IgnoredProcessesEmptyPreview",
        paths: []
    )
    .frame(width: 520)
}

#Preview("Ignored Processes — Populated") {
    IgnoredProcessesPreviewContainer(
        suiteName: "IgnoredProcessesPopulatedPreview",
        paths: [
            "/Applications/Xcode.app/Contents/MacOS/Xcode",
            "/Applications/Safari.app/Contents/MacOS/Safari",
            "/usr/local/bin/render-worker"
        ]
    )
    .frame(width: 520)
}

#endif
