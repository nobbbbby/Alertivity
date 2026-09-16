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

                Divider()

                SettingsFootnote(key: "settings.menuBar.help")
            }

            SettingsTab(title: "settings.tab.notifications", systemImage: "bell") {
                NotificationSettingsFields(
                    notificationsEnabled: $settings.notificationsEnabled,
                    highActivityDurationSeconds: $settings.highActivityDurationSeconds,
                    processSamplingAvailable: processSamplingAvailable
                )
            }

            if processSamplingAvailable {
                SettingsTab(title: "settings.tab.detection", systemImage: "scope") {
                    DetectionSettingsFields(
                        highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                        highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent,
                        highActivityDurationSeconds: settings.highActivityDurationSeconds
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
                processSamplingAvailable: processSamplingAvailable
            )
        }

        if processSamplingAvailable {
            Section("settings.tab.detection") {
                DetectionSettingsFields(
                    highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                    highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent,
                    highActivityDurationSeconds: settings.highActivityDurationSeconds
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

    var body: some View {
        Text(key)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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

    var body: some View {
        Toggle("settings.notifications.enable", isOn: $notificationsEnabled)

        Picker("settings.detection.duration", selection: $highActivityDurationSeconds) {
            ForEach(MonitoringPreferences.durationOptions, id: \.self) { value in
                Text(L10n.format("settings.detection.durationValue", value)).tag(value)
            }
        }
        .pickerStyle(.menu)

        Divider()

        Text(L10n.format(notificationNoteKey, highActivityDurationSeconds))
            .font(.footnote)
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
    let highActivityDurationSeconds: Int

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

        Divider()

        Text(L10n.format(
            "settings.detection.flags",
            highActivityCPUThresholdPercent,
            highActivityMemoryThresholdPercent,
            highActivityDurationSeconds
        ))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#if DEBUG && !DISABLE_PREVIEWS
private struct NoticePreferencesPreviewContainer: View {
    @StateObject private var settings = PreviewSettingsStore.make(suiteName: "NoticePreferencesPreview")

    var body: some View {
        Form {
            NoticePreferencesView(settings: settings, processSamplingAvailable: true)
        }
    }
}

private enum PreviewSettingsStore {
    static func make(suiteName: String) -> SettingsStore {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(userDefaults: defaults)
        store.isMenuIconEnabled = true
        store.showMetricIcon = true
        store.isMenuIconAutoSwitchEnabled = true
        store.highActivityDurationSeconds = MonitoringPreferences.durationOptions[1]
        store.highActivityCPUThresholdPercent = MonitoringPreferences.cpuThresholdOptions[4]
        store.highActivityMemoryThresholdPercent = MonitoringPreferences.memoryThresholdOptions[4]
        return store
    }
}

#Preview("Settings") {
    SettingsView(
        settings: PreviewSettingsStore.make(suiteName: "SettingsPreview"),
        processSamplingAvailable: true
    )
    .frame(width: 520)
}

#Preview("Notice Preferences") {
    NoticePreferencesPreviewContainer()
        .frame(width: 420)
}
#endif
