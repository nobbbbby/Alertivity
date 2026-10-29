import AppKit
import SwiftUI

private let settingsTabPadding = EdgeInsets(top: 24, leading: 45, bottom: 28, trailing: 45)

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let processSamplingAvailable: Bool
    @ObservedObject var notificationManager: NotificationManager
    var reviewStore: ReviewRequestStore = ReviewRequestStore()
    var proStore: ProStore? = nil
    var metrics: ActivityMetrics = .placeholder
    @State private var selectedTab: SettingsTabSelection = .general

    var body: some View {
        Group {
            if #available(macOS 27.0, *) {
                TabView(selection: $selectedTab) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Tab(L10n.string(tab.titleKey), systemImage: tab.symbolName, value: tab) {
                            pane(for: tab)
                        }
                        .help(tabHelp(for: tab))
                    }
                }
            } else {
                TabView(selection: $selectedTab) {
                    ForEach(availableTabs, id: \.self) { tab in
                        pane(for: tab)
                            .tabItem { Label(LocalizedStringKey(tab.titleKey), systemImage: tab.symbolName) }
                            .tag(tab)
                    }
                }
                .background(SettingsTabHelp(descriptions: tabDescriptions))
            }
        }
        .frame(minWidth: 420)
    }

    private var availableTabs: [SettingsTabSelection] {
        var tabs: [SettingsTabSelection] = [.general, .menuBar, .notifications, .thresholds]
        if settings.distribution == .appStore, proStore != nil { tabs.append(.pro) }
        if processSamplingAvailable { tabs.append(.detection) }
        return tabs
    }

    private func tabHelp(for tab: SettingsTabSelection) -> String {
        tabDescriptions[L10n.string(tab.titleKey)] ?? ""
    }

    @ViewBuilder
    private func pane(for tab: SettingsTabSelection) -> some View {
        switch tab {
        case .general: generalPane
        case .menuBar: menuBarPane
        case .notifications: notificationsPane
        case .thresholds: thresholdsPane
        case .pro: proPane
        case .detection: detectionPane
        }
    }

    private var generalPane: some View {
        SettingsPane {
            Toggle("settings.toggle.hideDockIcon", isOn: $settings.hideDockIcon)
            Toggle("settings.toggle.launchAtLogin", isOn: $settings.launchAtLogin)
        }
        .modifier(AutomaticReviewRequest(
            store: reviewStore,
            hasLiveData: metrics.hasLiveData,
            isCritical: ActivityStatus(metrics: metrics).level == .critical,
            isGeneralSelected: selectedTab == .general,
            isOnboardingActive: settings.onboardingOutcome == .pending || settings.isOnboardingRequested
        ))
    }

    private var menuBarPane: some View {
        SettingsPane {
            MenuBarSettingsFields(
                isMenuIconEnabled: $settings.isMenuIconEnabled,
                menuIconOnlyWhenHigh: $settings.menuIconOnlyWhenHigh,
                menuIconType: $settings.menuIconType,
                showMetricIcon: $settings.showMetricIcon,
                isMenuIconTinted: $settings.isMenuIconTinted,
                autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled,
                autoSwitchPriority: $settings.menuIconAutoSwitchPriority
            )
        }
    }

    private var notificationsPane: some View {
        SettingsPane {
            NotificationPermissionView(manager: notificationManager, showsAuthorizedStatus: false)
            NotificationSettingsFields(
                settings: settings,
                processSamplingAvailable: processSamplingAvailable,
                emphasizesFooter: true
            )
        }
    }

    private var thresholdsPane: some View {
        SettingsPane {
            SystemThresholdSettingsView(settings: settings, showsDescription: false)
        }
    }

    private var proPane: some View {
        SettingsPane {
            if let proStore {
                ProSettingsPane(store: proStore)
            }
        }
    }

    private var detectionPane: some View {
        SettingsPane {
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

    private var tabDescriptions: [String: String] {
        var thresholds = L10n.string("settings.thresholds.help")
        if settings.distribution == .openSource {
            thresholds += "\n" + L10n.string("Process detection thresholds are configured separately.")
        }
        return [
            L10n.string("settings.tab.general"): L10n.string("settings.tab.general.help"),
            L10n.string("settings.tab.menuBar"): L10n.string("settings.menuBar.help"),
            L10n.string("settings.tab.notifications"): L10n.string("settings.tab.notifications.help"),
            L10n.string("settings.tab.thresholds"): thresholds,
            L10n.string("settings.tab.detection"): L10n.string("settings.tab.detection.help"),
            L10n.string("pro.tabTitle"): L10n.string("pro.tabHelp")
        ]
    }

    private enum SettingsTabSelection: Hashable {
        case general, menuBar, notifications, thresholds, detection, pro

        var titleKey: String {
            switch self {
            case .general: "settings.tab.general"
            case .menuBar: "settings.tab.menuBar"
            case .notifications: "settings.tab.notifications"
            case .thresholds: "settings.tab.thresholds"
            case .detection: "settings.tab.detection"
            case .pro: "pro.tabTitle"
            }
        }

        var symbolName: String {
            switch self {
            case .general: "switch.2"
            case .menuBar: "waveform.path.ecg"
            case .notifications: "bell"
            case .thresholds: "gauge.with.dots.needle.50percent"
            case .detection: "scope"
            case .pro: "star"
            }
        }
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
                isMenuIconTinted: $settings.isMenuIconTinted,
                autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled,
                autoSwitchPriority: $settings.menuIconAutoSwitchPriority
            )
        }

        Section("settings.tab.notifications") {
            NotificationSettingsFields(
                settings: settings,
                processSamplingAvailable: processSamplingAvailable,
                emphasizesFooter: false
            )
        }

        Section("settings.tab.thresholds") {
            SystemThresholdSettingsView(settings: settings)
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

private struct SettingsPane<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(settingsTabPadding)
    }
}

struct SettingsFootnote: View {
    let key: LocalizedStringKey
    var weight: Font.Weight = .regular

    var body: some View {
        Text(key)
            .font(.footnote.weight(weight))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct FooterDivider: View {
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
    @Binding var isMenuIconTinted: Bool
    @Binding var autoSwitchEnabled: Bool
    @Binding var autoSwitchPriority: [MetricMenuSelection]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("settings.menuBar.showIndicator", isOn: $isMenuIconEnabled)

                Toggle("settings.menuBar.onlyShowHigh", isOn: $menuIconOnlyWhenHigh)
                    .disabled(!isMenuIconEnabled)

                Toggle("settings.menuBar.tintedIcon", isOn: $isMenuIconTinted)
                    .disabled(!isMenuIconEnabled)
                    .help("settings.menuBar.tintedIcon.help")

                Picker("settings.menuBar.defaultIconType", selection: $menuIconType) {
                    ForEach(MenuIconType.allCases) { iconType in
                        Label(iconType.title, systemImage: iconType.symbolName)
                            .tag(iconType)
                    }
                }
                .disabled(!isMenuIconEnabled)
                .pickerStyle(.menu)

                if menuIconType.metricSelection != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("settings.menuBar.showMetricIcon", isOn: $showMetricIcon)
                            .disabled(!isMenuIconEnabled || autoSwitchEnabled)
                            .help("settings.menuBar.showMetricIcon.help")

                        if autoSwitchEnabled {
                            SettingsFootnote(key: "settings.menuBar.showMetricIcon.autoSwitchHelp")
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Toggle("settings.menuBar.autoSwitch", isOn: autoSwitchBinding)
                    .help("settings.menuBar.autoSwitch.help")
                    .disabled(!isMenuIconEnabled)

                priorityEditor
            }
        }
    }

    private var priorityEditor: some View {
        DisclosureGroup("settings.menuBar.autoSwitch.priority") {
            VStack(alignment: .leading, spacing: 6) {
                SettingsFootnote(key: "settings.menuBar.autoSwitch.priority.help")
                ForEach(autoSwitchPriority, id: \.self) { metric in
                    HStack {
                        Label(metric.menuIconType.title, systemImage: metric.menuIconType.symbolName)
                        Spacer()
                        Button {
                            move(metric, by: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .accessibilityLabel(Text(L10n.format("settings.menuBar.autoSwitch.priority.raise", metric.menuIconType.title)))
                        .disabled(autoSwitchPriority.first == metric)
                        Button {
                            move(metric, by: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .accessibilityLabel(Text(L10n.format("settings.menuBar.autoSwitch.priority.lower", metric.menuIconType.title)))
                        .disabled(autoSwitchPriority.last == metric)
                    }
                }
                HStack {
                    Spacer()
                    Button("settings.menuBar.autoSwitch.priority.reset") {
                        autoSwitchPriority = MetricMenuSelection.autoSwitchPriority
                    }
                    .disabled(autoSwitchPriority == MetricMenuSelection.autoSwitchPriority)
                }
            }
            .padding(.top, 4)
            .padding(.leading, 16)
        }
        .disabled(!isMenuIconEnabled || !autoSwitchEnabled)
    }

    private func move(_ metric: MetricMenuSelection, by offset: Int) {
        guard let index = autoSwitchPriority.firstIndex(of: metric),
              autoSwitchPriority.indices.contains(index + offset) else { return }
        var order = autoSwitchPriority
        order.swapAt(index, index + offset)
        autoSwitchPriority = order
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
    @ObservedObject var settings: SettingsStore
    let processSamplingAvailable: Bool
    let emphasizesFooter: Bool

    var body: some View {
        Toggle("settings.notifications.enable", isOn: $settings.notificationsEnabled)

        VStack(alignment: .leading, spacing: 2) {
            LabeledContent {
                Picker("settings.notifications.cooldown", selection: Binding(
                    get: { settings.monitoringConfiguration.cooldownMinutes },
                    set: { if settings.canCustomizeMonitoring { settings.notificationCooldownMinutes = $0 } }
                )) {
                    ForEach(MonitoringPreferences.notificationCooldownOptions, id: \.self) { value in
                        Text(L10n.format("settings.notifications.cooldownValue", value)).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!settings.notificationsEnabled || !settings.canCustomizeMonitoring)
                .accessibilityIdentifier("settings.notificationCooldown")
            } label: {
                HStack(spacing: 6) {
                    Text("settings.notifications.cooldown")
                    if !settings.canCustomizeMonitoring {
                        ProLockHint(help: "pro.lock.cooldown", identifier: "pro.lock.cooldown")
                    }
                }
            }
            SettingsFootnote(key: "settings.notifications.cooldown.help")
        }

        LabeledContent {
            Picker("settings.detection.duration", selection: Binding(
                get: { settings.monitoringConfiguration.durationSeconds },
                set: { if settings.canCustomizeMonitoring { settings.highActivityDurationSeconds = $0 } }
            )) {
                ForEach(MonitoringPreferences.durationOptions, id: \.self) { value in
                    Text(L10n.format("settings.detection.durationValue", value)).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(!settings.canCustomizeMonitoring)
            .accessibilityIdentifier("settings.highActivityDuration")
        } label: {
            HStack(spacing: 6) {
                Text("settings.detection.duration")
                if !settings.canCustomizeMonitoring {
                    ProLockHint(help: "pro.lock.duration", identifier: "pro.lock.duration")
                }
            }
        }

        FooterDivider()

        Text(L10n.format(
            notificationNoteKey,
            settings.monitoringConfiguration.durationSeconds,
            L10n.format("settings.notifications.cooldownValue", settings.monitoringConfiguration.cooldownMinutes)
        ))
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
        LabeledContent("settings.detection.cpuThreshold") {
            HStack(spacing: 4) {
                TextField("", value: $highActivityCPUThresholdPercent, format: .number)
                    .frame(width: 64)
                Text(verbatim: "%")
            }
        }

        LabeledContent("settings.detection.memoryThreshold") {
            HStack(spacing: 4) {
                TextField("", value: $highActivityMemoryThresholdPercent, format: .number)
                    .frame(width: 64)
                Text(verbatim: "%")
            }
        }
    }
}

private struct SystemThresholdSettingsView: View {
    private struct Draft: Equatable {
        var cpuElevated: Double
        var cpuCritical: Double
        var memoryElevated: Double
        var memoryCritical: Double
        var diskElevated: Double
        var diskCritical: Double
        var networkElevated: Double
        var networkCritical: Double

        init(_ thresholds: ActivityThresholds) {
            cpuElevated = thresholds.cpuElevatedPercent
            cpuCritical = thresholds.cpuCriticalPercent
            memoryElevated = thresholds.memoryElevatedPercent
            memoryCritical = thresholds.memoryCriticalPercent
            diskElevated = thresholds.diskElevatedMegabytesPerSecond
            diskCritical = thresholds.diskCriticalMegabytesPerSecond
            networkElevated = thresholds.networkElevatedMegabytesPerSecond
            networkCritical = thresholds.networkCriticalMegabytesPerSecond
        }
    }

    @ObservedObject var settings: SettingsStore
    let showsDescription: Bool
    @State private var draft: Draft

    init(settings: SettingsStore, showsDescription: Bool = true) {
        self.settings = settings
        self.showsDescription = showsDescription
        _draft = State(initialValue: Draft(settings.monitoringConfiguration.thresholds))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("")
                    Text("settings.thresholds.elevated")
                        .frame(width: 60, alignment: .trailing)
                    Text("settings.thresholds.critical")
                        .frame(width: 60, alignment: .trailing)
                    Text("")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                thresholdRow(
                    "settings.thresholds.cpu",
                    lockIdentifier: "pro.lock.thresholds.cpu",
                    help: "CPU thresholds use total system processor utilization.",
                    elevated: $draft.cpuElevated,
                    critical: $draft.cpuCritical,
                    unit: "%"
                )
                thresholdRow(
                    "settings.thresholds.memory",
                    lockIdentifier: "pro.lock.thresholds.memory",
                    help: "Memory thresholds use the percentage of physical memory in use.",
                    elevated: $draft.memoryElevated,
                    critical: $draft.memoryCritical,
                    unit: "%"
                )
                thresholdRow(
                    "settings.thresholds.disk",
                    lockIdentifier: "pro.lock.thresholds.disk",
                    help: "Disk thresholds use combined read and write throughput.",
                    elevated: $draft.diskElevated,
                    critical: $draft.diskCritical,
                    unit: "MB/s"
                )
                thresholdRow(
                    "settings.thresholds.network",
                    lockIdentifier: "pro.lock.thresholds.network",
                    help: "Network thresholds use combined download and upload throughput.",
                    elevated: $draft.networkElevated,
                    critical: $draft.networkCritical,
                    unit: "MB/s"
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.systemThresholds")

            if let validationError {
                Label(validationMessage(for: validationError), systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("settings.thresholds.reset") {
                    settings.resetActivityThresholds()
                    draft = Draft(.default)
                }
                .disabled(!settings.canCustomizeMonitoring)
            }

            if showsDescription {
                FooterDivider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.thresholds.help")
                    if settings.distribution == .openSource {
                        Text("Process detection thresholds are configured separately.")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: draft) { _, _ in applyIfValid() }
        .onChange(of: settings.canCustomizeMonitoring) { _, _ in
            draft = Draft(settings.monitoringConfiguration.thresholds)
        }
        .onChange(of: settings.monitoringConfiguration.thresholds) { _, thresholds in
            if validationError == nil, Draft(thresholds) != draft {
                draft = Draft(thresholds)
            }
        }
    }

    private func thresholdRow(
        _ title: LocalizedStringKey,
        lockIdentifier: String,
        help: LocalizedStringKey,
        elevated: Binding<Double>,
        critical: Binding<Double>,
        unit: String
    ) -> some View {
        GridRow {
            HStack(spacing: 6) {
                Text(title).help(help)
                if !settings.canCustomizeMonitoring {
                    ProLockHint(help: "pro.lock.thresholds", identifier: lockIdentifier)
                }
            }
            .accessibilityElement(children: .contain)
            thresholdField(value: elevated)
                .disabled(!settings.canCustomizeMonitoring)
            thresholdField(value: critical)
                .disabled(!settings.canCustomizeMonitoring)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 30, alignment: .leading)
        }
    }

    private func thresholdField(value: Binding<Double>) -> some View {
        TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 60)
    }

    private var validationError: ActivityThresholds.ValidationError? {
        ActivityThresholds.validate(
            cpuElevatedPercent: draft.cpuElevated,
            cpuCriticalPercent: draft.cpuCritical,
            memoryElevatedPercent: draft.memoryElevated,
            memoryCriticalPercent: draft.memoryCritical,
            diskElevatedMegabytesPerSecond: draft.diskElevated,
            diskCriticalMegabytesPerSecond: draft.diskCritical,
            networkElevatedMegabytesPerSecond: draft.networkElevated,
            networkCriticalMegabytesPerSecond: draft.networkCritical
        )
    }

    private func applyIfValid() {
        guard settings.canCustomizeMonitoring, validationError == nil else { return }
        settings.updateActivityThresholds(
            cpuElevatedPercent: draft.cpuElevated,
            cpuCriticalPercent: draft.cpuCritical,
            memoryElevatedPercent: draft.memoryElevated,
            memoryCriticalPercent: draft.memoryCritical,
            diskElevatedMegabytesPerSecond: draft.diskElevated,
            diskCriticalMegabytesPerSecond: draft.diskCritical,
            networkElevatedMegabytesPerSecond: draft.networkElevated,
            networkCriticalMegabytesPerSecond: draft.networkCritical
        )
    }

    private func validationMessage(for error: ActivityThresholds.ValidationError) -> LocalizedStringKey {
        switch error {
        case .cpuOutOfRange, .memoryOutOfRange:
            return "settings.thresholds.error.percentRange"
        case .diskOutOfRange, .networkOutOfRange:
            return "settings.thresholds.error.throughputRange"
        case .elevatedMustBeBelowCritical:
            return "settings.thresholds.error.order"
        }
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
            formattedPercent(highActivityCPUThresholdPercent),
            formattedPercent(highActivityMemoryThresholdPercent),
            highActivityDurationSeconds
        ))
            .font(.footnote.weight(emphasizesFooter ? .semibold : .regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func formattedPercent(_ wholePercent: Int) -> String {
    (Double(wholePercent) / 100).formatted(
        .percent.precision(.fractionLength(0))
    )
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
    @StateObject private var notificationManager = NotificationManager()
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
            processSamplingAvailable: processSamplingAvailable,
            notificationManager: notificationManager
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
