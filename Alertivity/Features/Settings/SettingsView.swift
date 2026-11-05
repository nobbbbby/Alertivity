import AppKit
import SwiftUI

private let settingsPaneMargin: CGFloat = 20
private let settingsGroupContentInset: CGFloat = 10

private let settingsTabPadding = EdgeInsets(top: 24, leading: 45, bottom: 28, trailing: 45)

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let processSamplingAvailable: Bool
    @ObservedObject var notificationManager: NotificationManager
    var reviewStore: ReviewRequestStore = ReviewRequestStore()
    var proStore: ProStore? = nil
    var metrics: ActivityMetrics = .placeholder
    @State private var selectedTab: SettingsTabSelection = .general
    @State private var tabWidth: CGFloat = 420

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
        .frame(width: tabWidth)
        .background(SettingsTabWidth(width: $tabWidth))
        // Report a finite vertical size so the Settings window also shrinks after collapse.
        .fixedSize(horizontal: false, vertical: true)
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
        SettingsPane(width: tabWidth) {
            Section("settings.group.appBehavior") {
                Toggle("settings.toggle.hideDockIcon", isOn: $settings.hideDockIcon)
                    .accessibilityLabel(Text("settings.toggle.hideDockIcon"))
                    .accessibilityIdentifier("settings.toggle.hideDockIcon")
                Toggle("settings.toggle.launchAtLogin", isOn: $settings.launchAtLogin)
                    .accessibilityLabel(Text("settings.toggle.launchAtLogin"))
                    .accessibilityIdentifier("settings.toggle.launchAtLogin")
            }
            Section("settings.group.monitoring") {
                SamplingIntervalSettingsView(settings: settings)
            }
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
        SettingsPane(width: tabWidth) {
            MenuBarSettingsFields(
                isMenuIconEnabled: $settings.isMenuIconEnabled,
                menuIconOnlyWhenHigh: $settings.menuIconOnlyWhenHigh,
                menuIconType: $settings.menuIconType,
                showMetricIcon: $settings.showMetricIcon,
                isMenuIconTinted: $settings.isMenuIconTinted,
                autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled,
                autoSwitchPriority: Binding(
                    get: { settings.effectiveMenuIconAutoSwitchPriority },
                    set: { if settings.canCustomizeMetricPriority { settings.menuIconAutoSwitchPriority = $0 } }
                ),
                activationLevel: Binding(
                    get: { settings.effectiveAutoSwitchActivationLevel },
                    set: { if settings.canCustomizeMonitoring { settings.autoSwitchActivationLevel = $0 } }
                ),
                canCustomizeActivation: settings.canCustomizeMonitoring,
                canCustomizeMetricPriority: settings.canCustomizeMetricPriority,
                usesGroupedSections: true
            )
        }
    }

    private var notificationsPane: some View {
        SettingsPane(width: tabWidth) {
            NotificationSettingsFields(
                settings: settings,
                processSamplingAvailable: processSamplingAvailable,
                usesGroupedRows: true,
                notificationManager: notificationManager
            )
        }
    }

    private var thresholdsPane: some View {
        SettingsContentPane(width: tabWidth) {
            SystemThresholdSettingsView(settings: settings, showsDescription: false)
        }
    }

    private var proPane: some View {
        SettingsContentPane(width: tabWidth) {
            if let proStore {
                ProSettingsPane(store: proStore)
            }
        }
    }

    private var detectionPane: some View {
        SettingsPane(width: tabWidth) {
            Section {
                DetectionSettingsFields(
                    highActivityCPUThresholdPercent: $settings.highActivityCPUThresholdPercent,
                    highActivityMemoryThresholdPercent: $settings.highActivityMemoryThresholdPercent
                )
            } header: {
                Text("settings.group.processActivity")
            } footer: {
                DetectionSettingsFooter(
                    highActivityCPUThresholdPercent: settings.highActivityCPUThresholdPercent,
                    highActivityMemoryThresholdPercent: settings.highActivityMemoryThresholdPercent,
                    highActivityDurationSeconds: settings.highActivityDurationSeconds
                )
            }

            IgnoredProcessSettingsView(settings: settings, usesGroupedRows: true)
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
        Section("settings.tab.general") {
            SamplingIntervalSettingsView(settings: settings)
        }
        Section("settings.tab.menuBar") {
            MenuBarSettingsFields(
                isMenuIconEnabled: $settings.isMenuIconEnabled,
                menuIconOnlyWhenHigh: $settings.menuIconOnlyWhenHigh,
                menuIconType: $settings.menuIconType,
                showMetricIcon: $settings.showMetricIcon,
                isMenuIconTinted: $settings.isMenuIconTinted,
                autoSwitchEnabled: $settings.isMenuIconAutoSwitchEnabled,
                autoSwitchPriority: Binding(
                    get: { settings.effectiveMenuIconAutoSwitchPriority },
                    set: { if settings.canCustomizeMetricPriority { settings.menuIconAutoSwitchPriority = $0 } }
                ),
                activationLevel: Binding(
                    get: { settings.effectiveAutoSwitchActivationLevel },
                    set: { if settings.canCustomizeMonitoring { settings.autoSwitchActivationLevel = $0 } }
                ),
                canCustomizeActivation: settings.canCustomizeMonitoring,
                canCustomizeMetricPriority: settings.canCustomizeMetricPriority
            )
        }

        Section("settings.tab.notifications") {
            NotificationSettingsFields(
                settings: settings,
                processSamplingAvailable: processSamplingAvailable
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
                    highActivityDurationSeconds: settings.highActivityDurationSeconds
                )
            }
        }
    }
}

/// Keep each tab at its content height without flashing scroll indicators during window resizing.
/// Native scrolling remains available when the window cannot accommodate all rows.
private struct SettingsPane<Content: View>: View {
    let width: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        SettingsFormLayout { form }
            .frame(width: width, alignment: .leading)
    }

    private var form: some View {
        Form { content }
            .formStyle(.grouped)
            // Grouped forms already supply the native 20-point outer inset.
            .contentMargins(0, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
    }
}

/// Keep table and purchase layouts inside a semantic surface matching native grouped-row insets.
private struct SettingsContentPane<Content: View>: View {
    let width: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        SettingsFormLayout {
            VStack(alignment: .leading, spacing: 20) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(settingsGroupContentInset)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                .padding(settingsPaneMargin)
        }
        .frame(width: width, alignment: .leading)
    }
}

/// Round natural pane heights up so fractional points cannot create native scroll overflow.
private struct SettingsFormLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let form = subviews.first else { return .zero }
        let size = form.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: size.width, height: ceil(size.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

struct SettingsFootnote: View {
    let key: LocalizedStringKey

    var body: some View {
        Text(key)
            .font(.footnote)
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

private struct SamplingIntervalSettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        LabeledContent {
            Picker("settings.sampling.interval", selection: Binding(
                get: { settings.monitoringConfiguration.samplingInterval },
                set: { if settings.canCustomizeMonitoring { settings.updateSamplingInterval($0) } }
            )) {
                ForEach(MonitoringPreferences.samplingIntervalOptions, id: \.self) { seconds in
                    Text(L10n.format("settings.sampling.value", Int(seconds))).tag(seconds)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(!settings.canCustomizeMonitoring)
            .accessibilityIdentifier("settings.samplingInterval")
            .help("settings.sampling.help")
        } label: {
            HStack(spacing: 6) {
                Text("settings.sampling.interval")
                if !settings.canCustomizeMonitoring {
                    ProLockHint(help: "pro.lock.sampling", identifier: "pro.lock.sampling")
                }
            }
        }
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
    @Binding var activationLevel: AutoSwitchActivationLevel
    let canCustomizeActivation: Bool
    let canCustomizeMetricPriority: Bool

    // Shared preferences keep their existing layout outside the Settings panes.
    var usesGroupedSections = false
    @State private var isPriorityExpanded = false

    var body: some View {
        if usesGroupedSections {
            Section("settings.group.visibility") { visibilityRows }
            Section("settings.group.appearance") { appearanceRows }
            Section("settings.group.autoSwitching") { autoSwitchRows }
        } else {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    visibilityRows
                    tintedIconRow
                    defaultIconRow
                    metricIconRow
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) { autoSwitchRows }
            }
        }
    }

    @ViewBuilder
    private var visibilityRows: some View {
        Toggle("settings.menuBar.showIndicator", isOn: $isMenuIconEnabled)
            .accessibilityLabel(Text("settings.menuBar.showIndicator"))
            .accessibilityIdentifier("settings.menuBar.showIndicator")

        Toggle("settings.menuBar.onlyShowHigh", isOn: $menuIconOnlyWhenHigh)
            .accessibilityLabel(Text("settings.menuBar.onlyShowHigh"))
            .accessibilityIdentifier("settings.menuBar.onlyShowHigh")
            .disabled(!isMenuIconEnabled)
    }

    private var appearanceRows: some View {
        Group {
            defaultIconRow
            tintedIconRow
            metricIconRow
        }
    }

    private var defaultIconRow: some View {
        Picker("settings.menuBar.defaultIconType", selection: $menuIconType) {
            ForEach(MenuIconType.allCases) { iconType in
                Label(iconType.title, systemImage: iconType.symbolName)
                    .tag(iconType)
            }
        }
        .disabled(!isMenuIconEnabled)
        .pickerStyle(.menu)
    }

    private var tintedIconRow: some View {
        Toggle("settings.menuBar.tintedIcon", isOn: $isMenuIconTinted)
            .accessibilityLabel(Text("settings.menuBar.tintedIcon"))
            .accessibilityIdentifier("settings.menuBar.tintedIcon")
            .disabled(!isMenuIconEnabled)
            .help("settings.menuBar.tintedIcon.help")
    }

    @ViewBuilder
    private var metricIconRow: some View {
        if menuIconType.metricSelection != nil {
            if usesGroupedSections {
                metricIconToggle
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    metricIconToggle
                    if autoSwitchEnabled {
                        SettingsFootnote(key: "settings.menuBar.showMetricIcon.autoSwitchHelp")
                    }
                }
            }
        }
    }

    private var metricIconToggle: some View {
        Toggle("settings.menuBar.showMetricIcon", isOn: $showMetricIcon)
            .accessibilityLabel(Text("settings.menuBar.showMetricIcon"))
            .accessibilityIdentifier("settings.menuBar.showMetricIcon")
            .disabled(!isMenuIconEnabled || autoSwitchEnabled)
            .help(L10n.string(autoSwitchEnabled
                ? "settings.menuBar.showMetricIcon.autoSwitchHelp"
                : "settings.menuBar.showMetricIcon.help"))
    }

    @ViewBuilder
    private var autoSwitchRows: some View {
        Toggle("settings.menuBar.autoSwitch", isOn: autoSwitchBinding)
            .accessibilityLabel(Text("settings.menuBar.autoSwitch"))
            .accessibilityIdentifier("settings.menuBar.autoSwitch")
            .help(activationHelp)
            .disabled(!isMenuIconEnabled)

        LabeledContent {
            Picker("settings.autoSwitch.activation", selection: $activationLevel) {
                ForEach(AutoSwitchActivationLevel.allCases, id: \.self) { level in
                    Text(level.title).tag(level)
                }
            }
            .labelsHidden()
            .disabled(!isMenuIconEnabled || !autoSwitchEnabled || !canCustomizeActivation)
            .accessibilityIdentifier("settings.autoSwitchActivation")
        } label: {
            HStack(spacing: 6) {
                Text("settings.autoSwitch.activation")
                if !canCustomizeActivation {
                    ProLockHint(help: "pro.lock.activation", identifier: "pro.lock.activation")
                }
            }
        }
        priorityEditor
    }

    private var activationHelp: String {
        L10n.format("settings.autoSwitch.activation.help", activationLevel.title)
    }

    private var priorityEditor: some View {
        DisclosureGroup(isExpanded: priorityExpansion) {
            VStack(alignment: .leading, spacing: 6) {
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
            .disabled(!isMenuIconEnabled || !autoSwitchEnabled || !canCustomizeMetricPriority)
        } label: {
            HStack(spacing: 6) {
                Text("settings.menuBar.autoSwitch.priority")
                if !canCustomizeMetricPriority {
                    ProLockHint(help: "pro.lock.metricPriority", identifier: "pro.lock.metricPriority")
                }
            }
        }
        .accessibilityIdentifier("settings.metricPriority")
        .help("settings.menuBar.autoSwitch.priority.help")
    }

    /// Avoid animating the measured form height while the Settings window resizes to fit it.
    private var priorityExpansion: Binding<Bool> {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return Binding(
            get: { isPriorityExpanded },
            set: { expanded in
                guard expanded != isPriorityExpanded else { return }
                if usesGroupedSections {
                    SettingsWindowTracker.shared.prepareForAdaptiveContentResize()
                }
                withTransaction(transaction) { isPriorityExpanded = expanded }
            }
        )
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

    var usesGroupedRows = false
    var notificationManager: NotificationManager? = nil

    var body: some View {
        if usesGroupedRows {
            Section {
                if let notificationManager {
                    NotificationPermissionView(manager: notificationManager, showsAuthorizedStatus: false)
                }
                enableRow
                cooldownRow
                durationRow
            } footer: {
                notificationNote
            }
        } else {
            enableRow
            VStack(alignment: .leading, spacing: 2) {
                cooldownRow
                SettingsFootnote(key: "settings.notifications.cooldown.help")
            }
            durationRow
            FooterDivider()
            notificationNote
        }
    }

    private var enableRow: some View {
        Toggle("settings.notifications.enable", isOn: $settings.notificationsEnabled)
            .accessibilityLabel(Text("settings.notifications.enable"))
            .accessibilityIdentifier("settings.notifications.enable")
    }

    private var cooldownRow: some View {
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
        .help("settings.notifications.cooldown.help")
    }

    private var durationRow: some View {
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
    }

    private var notificationNote: some View {
        Text(L10n.format(
            notificationNoteKey,
            settings.monitoringConfiguration.durationSeconds,
            L10n.format("settings.notifications.cooldownValue", settings.monitoringConfiguration.cooldownMinutes)
        ))
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

    var body: some View {
        LabeledContent("settings.detection.cpuThreshold") {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("", value: $highActivityCPUThresholdPercent, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                Text(verbatim: "%")
            }
        }

        LabeledContent("settings.detection.memoryThreshold") {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("", value: $highActivityMemoryThresholdPercent, format: .number)
                    .multilineTextAlignment(.trailing)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("settings.thresholds.elevated")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 60, alignment: .trailing)
                        .gridColumnAlignment(.trailing)
                    Text("settings.thresholds.critical")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 60, alignment: .trailing)
                        .gridColumnAlignment(.trailing)
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
            // Give surplus width to the metric column so values and units reach the trailing inset.
            .frame(maxWidth: .infinity, alignment: .leading)
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

    var body: some View {
        Text(L10n.format(
            "settings.detection.flags",
            formattedPercent(highActivityCPUThresholdPercent),
            formattedPercent(highActivityMemoryThresholdPercent),
            highActivityDurationSeconds
        ))
            .font(.footnote)
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
    var usesGroupedRows = false

    var body: some View {
        Group {
            if usesGroupedRows {
                Section {
                    if settings.ignoredProcessPaths.isEmpty {
                        Text("settings.ignoredProcesses.empty")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(settings.ignoredProcessPaths, id: \.self) { path in
                        IgnoredProcessRow(path: path) { settings.removeIgnoredProcess(at: path) }
                    }
                } header: {
                    HStack {
                        Text("settings.ignoredProcesses.title")
                        Spacer()
                        Button { chooseProcess() } label: {
                            Label("settings.ignoredProcesses.add", systemImage: "plus")
                                .labelStyle(.iconOnly)
                                .fontWeight(.bold)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .accessibilityIdentifier("settings.ignoredProcesses.add")
                        .accessibilityHint(Text("settings.ignoredProcesses.picker.message"))
                        .help("settings.ignoredProcesses.add")
                    }
                    .help("settings.ignoredProcesses.help")
                }
            } else {
                legacyContent
            }
        }
        .alert("settings.ignoredProcesses.invalid.title", isPresented: $isShowingInvalidSelectionAlert) {
            Button("general.ok", role: .cancel) {}
        } message: {
            Text("settings.ignoredProcesses.invalid.message")
        }
    }

    private var legacyContent: some View {
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
