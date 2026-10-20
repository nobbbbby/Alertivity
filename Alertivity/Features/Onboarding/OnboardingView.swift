import AppKit
import SwiftUI

/// An auxiliary singleton scene keeps guidance independent of the menu bar's visibility.
struct OnboardingView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var notificationManager: NotificationManager
    @ObservedObject var monitor: ActivityMonitor
    let processSamplingAvailable: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var showsMenuOptions = false
    @State private var showsNotificationOptions = false
    // Exploration never mutates the saved menu-bar configuration.
    @State private var previewIconType = MenuIconType.status

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(stepTitle, systemImage: stepSymbol)
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            Text(L10n.format("onboarding.step", step + 1, stepCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("onboarding.step")

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch step {
                    case 0: introduction
                    case 1: preferences
                    default: proIntroduction
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 280)

            Divider()
            HStack {
                Button("onboarding.skip") { finish(.skipped) }
                    .accessibilityIdentifier("onboarding.skip")
                Spacer()
                if step > 0 {
                    Button("onboarding.back") { step -= 1 }
                        .accessibilityIdentifier("onboarding.back")
                }
                Button(isLastStep ? "onboarding.done" : "onboarding.continue") {
                    if isLastStep { finish(.completed) } else { step += 1 }
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("onboarding.next")
            }
        }
        .padding(28)
        .frame(width: 520)
        .background(OnboardingWindowRestoration())
        .onAppear {
            // SwiftUI can instantiate the first Window scene at launch; suppress an unsolicited replay.
            guard !OnboardingRuntime.isHostedUnitTest,
                  settings.onboardingOutcome == .pending || settings.isOnboardingRequested else {
                dismiss()
                return
            }
            step = 0
            showsMenuOptions = false
            showsNotificationOptions = false
            previewIconType = settings.menuIconType
            AppLogger.lifecycle.info("Onboarding opened")
            NSApp.activate(ignoringOtherApps: true)
        }
        .onChange(of: step) { _, value in
            AppLogger.lifecycle.info("Onboarding step changed; step: \(value + 1, privacy: .public)")
        }
        .onChange(of: previewIconType) { _, type in
            AppLogger.lifecycle.info("Onboarding preview changed; style: \(type.rawValue, privacy: .public)")
        }
        .onDisappear {
            guard !OnboardingRuntime.isHostedUnitTest else { return }
            settings.isOnboardingRequested = false
            if settings.onboardingOutcome == .pending { settings.finishOnboarding(.skipped) }
        }
    }

    private var stepCount: Int { settings.distribution == .appStore ? 3 : 2 }
    private var isLastStep: Bool { step == stepCount - 1 }

    private var stepTitle: LocalizedStringKey {
        switch step {
        case 0: "onboarding.overview.title"
        case 1: "onboarding.alerts.title"
        default: "pro.title"
        }
    }

    private var stepSymbol: String {
        switch step {
        case 0: "waveform.path.ecg"
        case 1: "bell"
        default: "star"
        }
    }

    /// Explain the boundary without interrupting setup with a purchase or permission prompt.
    private var proIntroduction: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("onboarding.pro.help")
                .accessibilityIdentifier("onboarding.pro.introduction")
            ProFeatureList()
            Text("pro.oneTime")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("onboarding.pro.settings")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("onboarding.overview.help")
            OnboardingLivePreview(
                metrics: monitor.metrics,
                iconType: $previewIconType,
                savedIconType: settings.menuIconType
            ) {
                // Applying is explicit; navigation and preview selection never save the style.
                settings.menuIconType = previewIconType
                AppLogger.lifecycle.info("Onboarding style applied; style: \(previewIconType.rawValue, privacy: .public)")
            }
            DisclosureGroup("onboarding.moreOptions", isExpanded: $showsMenuOptions) {
                autoSwitchOptions.padding(.top, 8)
            }
            .disclosureGroupStyle(OnboardingOptionsStyle())
            VStack(alignment: .leading, spacing: 4) {
                if processSamplingAvailable {
                    Text("onboarding.process.available")
                }
                Text("onboarding.local")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Auto switch belongs with the menu-bar preview; it changes the saved preference immediately.
    private var autoSwitchOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("settings.menuBar.autoSwitch", isOn: Binding(
                get: { settings.isMenuIconAutoSwitchEnabled },
                set: { enabled in
                    settings.isMenuIconAutoSwitchEnabled = enabled
                    if enabled { settings.showMetricIcon = true }
                    AppLogger.lifecycle.info("Onboarding auto switch changed; enabled: \(enabled, privacy: .public)")
                }
            ))
            .accessibilityIdentifier("onboarding.autoSwitch")
            Text("settings.menuBar.autoSwitch.help")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("onboarding.alerts.help")
            NotificationPermissionView(manager: notificationManager) {
                settings.notificationsEnabled = true
            }
            if notificationManager.authorizationStatus == .authorized
                || notificationManager.authorizationStatus == .provisional {
                Toggle("settings.notifications.enable", isOn: $settings.notificationsEnabled)
            }
            DisclosureGroup("onboarding.moreOptions", isExpanded: $showsNotificationOptions) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("settings.toggle.launchAtLogin", isOn: $settings.launchAtLogin)
                    Text("onboarding.login.help").font(.caption).foregroundStyle(.secondary)
                    SettingsLink { Text("menu.openSettings") }
                }
                .padding(.top, 8)
            }
            .disclosureGroupStyle(OnboardingOptionsStyle())
            Text("onboarding.finish.help").font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func finish(_ outcome: OnboardingOutcome) {
        settings.finishOnboarding(outcome)
        dismiss()
    }
}

/// A native SwiftUI disclosure style gives the entire row a keyboard-accessible hit target.
/// Keeping the chevron inside the row also avoids clipping at the scroll view's leading edge.
private struct OnboardingOptionsStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { configuration.isExpanded.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    configuration.label
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(configuration.isExpanded ? "onboarding.options.expanded" : "onboarding.options.collapsed"))
            .accessibilityIdentifier("onboarding.moreOptions")
            if configuration.isExpanded {
                configuration.content.padding(.leading, 18)
            }
        }
    }
}

/// Equal-width columns anchor the divider at the center as live values and styles change.
/// Shared by onboarding and Canvas previews; the caller owns preferences and metric collection.
struct OnboardingLivePreview: View {
    let metrics: ActivityMetrics
    @Binding var iconType: MenuIconType
    let savedIconType: MenuIconType
    let applyStyle: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("onboarding.preview.title")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    OnboardingMetricPreview(metrics: metrics, iconType: iconType)
                        .padding(.horizontal, 12)
                        .frame(minWidth: 0, maxWidth: .infinity)
                    Picker("onboarding.preview.style", selection: $iconType) {
                        ForEach(MenuIconType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityIdentifier("onboarding.previewStyle")
                    .padding(.horizontal, 12)
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
                .frame(minHeight: 48)
                .overlay {
                    HStack(spacing: 0) { Divider() }
                        .frame(width: 1, height: 44)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 8) {
                    Text("onboarding.preview.help")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Button(action: applyStyle) {
                        Text(iconType == savedIconType ? "onboarding.preview.applied" : "onboarding.preview.apply")
                    }
                    .fixedSize()
                    .disabled(iconType == savedIconType)
                    .accessibilityIdentifier("onboarding.applyStyle")
                }
                .padding(.trailing, 25)
            }
            .padding(8)
        }
    }
}

/// Native text preserves crisp throughput readings and the menu bar's shared value formatting.
private struct OnboardingMetricPreview: View {
    let metrics: ActivityMetrics
    let iconType: MenuIconType

    private var status: ActivityStatus { ActivityStatus(metrics: metrics) }
    private var selection: MetricMenuSelection? { iconType.metricSelection }
    private var value: String {
        selection?.formattedValue(for: metrics) ?? status.menuTitle(for: metrics)
    }
    private var tint: Color {
        if let selection {
            return StatusColorPalette.color(for: metrics.severity(for: selection)) ?? .primary
        }
        return status.iconTint ?? .primary
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: selection?.symbolName ?? status.symbolName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(.system(size: selection == nil ? 20 : 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selection?.title ?? L10n.string("accessibility.systemMetrics"))
        .accessibilityValue(value)
        .accessibilityIdentifier("onboarding.preview")
    }
}

/// Runs once per process, even if changing menu visibility reconstructs the label.
struct OnboardingLauncher: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.openWindow) private var openWindow
    private static var hasCheckedLaunch = false

    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onAppear {
                guard !Self.hasCheckedLaunch else { return }
                Self.hasCheckedLaunch = true
                // Hosted unit tests must not open windows or modify onboarding preferences.
                guard !OnboardingRuntime.isHostedUnitTest else { return }
                if settings.onboardingOutcome == .pending {
                    settings.isOnboardingRequested = true
                    openWindow(id: "onboarding")
                }
            }
    }
}

struct OnboardingLink: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("onboarding.open") {
            settings.isOnboardingRequested = true
            openWindow(id: "onboarding")
        }
            .accessibilityIdentifier("onboarding.open")
    }
}

/// SwiftUI's restoration modifier requires macOS 15. This per-window bridge also supports macOS 14.
/// Configure the native window when it attaches, before drawing, without retaining it globally.
private struct OnboardingWindowRestoration: NSViewRepresentable {
    final class WindowView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isRestorable = false
        }
    }

    func makeNSView(context: Context) -> WindowView { WindowView() }
    func updateNSView(_ nsView: WindowView, context: Context) {}
}

private enum OnboardingRuntime {
    static var isHostedUnitTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            && !ProcessInfo.processInfo.arguments.contains("UITests")
    }
}
