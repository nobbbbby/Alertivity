import SwiftUI
import AppKit

enum MenuIconType: String, CaseIterable, Identifiable, Sendable {
    case status
    case cpu
    case memory
    case disk
    case network

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status:
            return "Status icon"
        case .cpu:
            return "CPU usage"
        case .memory:
            return "Memory usage"
        case .disk:
            return "Disk throughput"
        case .network:
            return "Network throughput"
        }
    }

    var symbolName: String {
        switch self {
        case .status:
            return "waveform"
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .disk:
            return "internaldrive"
        case .network:
            return "arrow.up.arrow.down"
        }
    }

    var metricSelection: MetricMenuSelection? {
        switch self {
        case .status:
            return nil
        case .cpu:
            return .cpu
        case .memory:
            return .memory
        case .disk:
            return .disk
        case .network:
            return .network
        }
    }
}

enum MetricMenuSelection: CaseIterable, Hashable, Sendable {
    case cpu
    case memory
    case disk
    case network

    static let autoSwitchPriority: [MetricMenuSelection] = [.cpu, .memory, .disk, .network]

    static func autoSwitchPriorityIndex(_ selection: MetricMenuSelection) -> Int {
        autoSwitchPriority.firstIndex(of: selection) ?? autoSwitchPriority.count
    }

    var menuIconType: MenuIconType {
        switch self {
        case .cpu:
            return .cpu
        case .memory:
            return .memory
        case .disk:
            return .disk
        case .network:
            return .network
        }
    }

    func isHighActivity(for metrics: ActivityMetrics) -> Bool {
        metrics.severity(for: self) == .critical
    }

    static func highestPriorityHighActivity(in metrics: ActivityMetrics) -> MetricMenuSelection? {
        metrics.highestSeverityMetric(allowedSeverities: [.critical])?.0
    }

    var shortLabel: String {
        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "MEM"
        case .disk:
            return "DSK"
        case .network:
            return "NET"
        }
    }

    var title: String {
        switch self {
        case .cpu:
            return "CPU Usage"
        case .memory:
            return "Memory Usage"
        case .disk:
            return "Disk Throughput"
        case .network:
            return "Network Throughput"
        }
    }

    var symbolName: String {
        switch self {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .disk:
            return "internaldrive"
        case .network:
            return "arrow.up.arrow.down"
        }
    }

    func formattedValue(for metrics: ActivityMetrics) -> String {
        switch self {
        case .cpu:
            metrics.cpuUsage.formatted(.percent.precision(.fractionLength(0)))
        case .memory:
            metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
        case .disk:
            metrics.disk.formattedTotalPerSecond + "/s"
        case .network:
            metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond) + "/s"
        }
    }

    func accessibilityValue(for metrics: ActivityMetrics) -> String {
        switch self {
        case .cpu:
            return "CPU usage \(metrics.cpuUsage.formatted(.percent.precision(.fractionLength(1))))"
        case .memory:
            return "Memory usage \(metrics.memoryUsage.formatted(.percent.precision(.fractionLength(1))))"
        case .disk:
            return "Total disk throughput \(metrics.disk.formattedTotalPerSecond) per second"
        case .network:
            return "Total network throughput \(metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond)) per second"
        }
    }

    func detailSummary(for metrics: ActivityMetrics) -> String {
        switch self {
        case .cpu:
            return "Current CPU usage is \(metrics.cpuUsage.formatted(.percent.precision(.fractionLength(1))))"
        case .memory:
            let used = metrics.memoryUsed.converted(to: .gigabytes)
            let total = metrics.memoryTotal.converted(to: .gigabytes)
            return "Using \(Self.measurementFormatter.string(from: used)) of \(Self.measurementFormatter.string(from: total))"
        case .disk:
            return metrics.disk.formattedReadWriteSummary + " (total \(metrics.disk.formattedTotalPerSecond)/s)"
        case .network:
            return "↓ \(metrics.network.formattedDownload)/s • ↑ \(metrics.network.formattedUpload)/s"
        }
    }

    private static let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()
}

func resolveMenuIconType(autoSwitchEnabled: Bool, defaultIconType: MenuIconType, autoSwitchSelection: MetricMenuSelection?) -> MenuIconType {
    guard autoSwitchEnabled, let activeMetric = autoSwitchSelection else {
        return defaultIconType
    }
    return activeMetric.menuIconType
}

struct MetricMenuLabel: View {
    let metrics: ActivityMetrics
    let selection: MetricMenuSelection
    let showIcon: Bool
    let tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    init(metrics: ActivityMetrics, selection: MetricMenuSelection, showIcon: Bool, tint: Color? = nil) {
        self.metrics = metrics
        self.selection = selection
        self.showIcon = showIcon
        self.tint = tint
    }

    var body: some View {
        let resolvedTint: Color = tint ?? .primary

        HStack(spacing: 4) {
            if selection == .network {
                let nsTint = MenuBarStackedRenderer.nsColor(for: tint)
                let isTemplate = nsTint == nil
                let nsImage = MenuBarStackedRenderer.makeImage(
                    topLine: "↓ " + metrics.network.formattedDownload + "/s",
                    bottomLine: "↑ " + metrics.network.formattedUpload + "/s",
                    symbolName: showIcon ? selection.symbolName : nil,
                    tint: nsTint,
                    appearance: MenuBarStackedRenderer.appearance(for: colorScheme)
                )
                if isTemplate {
                    Image(nsImage: nsImage)
                        .renderingMode(.template)
                        .foregroundStyle(.primary)
                } else {
                    Image(nsImage: nsImage)
                        .renderingMode(.original)
                }
            } else if selection == .disk {
                let nsTint = MenuBarStackedRenderer.nsColor(for: tint)
                let isTemplate = nsTint == nil
                let nsImage = MenuBarStackedRenderer.makeImage(
                    topLine: "↑ " + metrics.disk.formattedReadPerSecond + "/s",
                    bottomLine: "↓ " + metrics.disk.formattedWritePerSecond + "/s",
                    symbolName: showIcon ? selection.symbolName : nil,
                    tint: nsTint,
                    appearance: MenuBarStackedRenderer.appearance(for: colorScheme)
                )
                if isTemplate {
                    Image(nsImage: nsImage)
                        .renderingMode(.template)
                        .foregroundStyle(.primary)
                } else {
                    Image(nsImage: nsImage)
                        .renderingMode(.original)
                }
            } else {
                if showIcon {
                    Image(systemName: selection.symbolName)
                        .symbolRenderingMode(.palette)
                        .font(.system(size: 11, weight: .medium))
                        .fixedSize()
                        .layoutPriority(1)
                        .foregroundStyle(resolvedTint)
                }

                Text(selection.formattedValue(for: metrics))
                    .font(.system(size: 12, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.15))
        )
        .accessibilityLabel(selection.title)
        .accessibilityValue(selection.accessibilityValue(for: metrics))
    }
}

struct MetricMenuBarLabel: View {
    let status: ActivityStatus
    let metrics: ActivityMetrics
    let isVisible: Bool
    let iconType: MenuIconType
    let showIcon: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isVisible {
                switch iconType {
                case .status:
                    Image(systemName: displayStatus.symbolName)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(displayStatus.iconTint ?? .primary, .secondary)
                case .cpu, .memory, .disk, .network:
                    if let selection = iconType.metricSelection {
                        MetricMenuLabel(
                            metrics: metrics,
                            selection: selection,
                            showIcon: showIcon,
                            tint: tint(for: selection, metrics: metrics)
                        )
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .accessibilityLabel("System metrics")
        .accessibilityValue(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard isVisible else {
            return "Menu icon hidden"
        }

        if let selection = iconType.metricSelection {
            return "\(selection.shortLabel) \(selection.formattedValue(for: metrics))"
        }

        return displayStatus.title(for: metrics)
    }

    private func tint(for selection: MetricMenuSelection, metrics: ActivityMetrics) -> Color? {
        guard displayStatus.level != .normal else { return nil }
        return StatusColorPalette.color(for: metrics.severity(for: selection))
    }

    private var displayStatus: ActivityStatus {
        ActivityStatus(metrics: metrics)
    }
}

// Helper for rendering a compact two-line badge as an NSImage suitable for the menu bar label (no VStack support)
private enum MenuBarStackedRenderer {
    static func appearance(for colorScheme: ColorScheme) -> NSAppearance {
        switch colorScheme {
        case .dark:
            return NSAppearance(named: .darkAqua) ?? NSApp?.effectiveAppearance ?? NSAppearance(named: .aqua)!
        case .light:
            fallthrough
        @unknown default:
            return NSAppearance(named: .aqua) ?? NSApp?.effectiveAppearance ?? NSAppearance(named: .darkAqua)!
        }
    }

    static func makeImage(topLine: String, bottomLine: String, symbolName: String? = nil, tint: NSColor?, appearance: NSAppearance) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        let hasTint = tint != nil
        let textColor = NSColor.labelColor
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]

        let line1 = NSString(string: topLine)
        let line2 = NSString(string: bottomLine)

        let size1 = line1.size(withAttributes: attrs)
        let size2 = line2.size(withAttributes: attrs)
        let spacing: CGFloat = -1.0 // tighten vertical gap between lines
        let textBlockWidth = ceil(max(size1.width, size2.width))
        let textBlockHeight = ceil(size1.height + spacing + size2.height)

        // Optional SF Symbol on the left
        let iconSpacing: CGFloat = symbolName == nil ? 0 : 4
        var iconSize = NSSize(width: 0, height: 0)
        var symbolImage: NSImage?
        if let name = symbolName, let baseSymbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            let baseConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            if let tint, let colored = baseSymbol.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: tint).applying(baseConfig)) {
                symbolImage = colored
            } else if let configured = baseSymbol.withSymbolConfiguration(baseConfig) {
                symbolImage = configured
            } else {
                symbolImage = baseSymbol
            }
            if let img = symbolImage {
                iconSize = img.size
            }
        }

        let width = ceil(iconSize.width + iconSpacing + textBlockWidth)
        let height = ceil(max(iconSize.height, textBlockHeight))

        let imageSize = NSSize(width: width, height: height)
        let image = NSImage(size: imageSize)
        appearance.performAsCurrentDrawingAppearance {
            image.lockFocusFlipped(false)
            defer { image.unlockFocus() }

            // Draw optional icon, vertically centered
            if let img = symbolImage {
                let iconY = (height - iconSize.height) / 2
                img.draw(in: NSRect(origin: CGPoint(x: 0, y: iconY), size: iconSize), from: .zero, operation: .sourceOver, fraction: 1.0)
            }

            // Draw stacked text on the right, right-aligned within its block
            let textBaseX = iconSize.width + iconSpacing
            let bottomY = (height - textBlockHeight) / 2

            // Bottom line (upload)
            let line2Origin = CGPoint(x: textBaseX + (textBlockWidth - size2.width), y: bottomY)
            line2.draw(at: line2Origin, withAttributes: attrs)

            // Top line (download)
            let line1Origin = CGPoint(x: textBaseX + (textBlockWidth - size1.width), y: bottomY + size2.height + spacing)
            line1.draw(at: line1Origin, withAttributes: attrs)
        }

        image.isTemplate = !hasTint
        return image
    }

    static func nsColor(for color: Color?) -> NSColor? {
        guard let color else { return nil }
        switch color {
        case .red:
            return .systemRed
        case .yellow:
            return .systemYellow
        case .green:
            return .systemGreen
        default:
            return .labelColor
        }
    }
}

#if DEBUG
#Preview("Metric Menu Components") {
    VStack(alignment: .leading, spacing: 24) {
        HStack(spacing: 16) {
            let criticalMetrics = ActivityMetrics.previewCritical
            MetricMenuBarLabel(
                status: ActivityStatus(metrics: criticalMetrics),
                metrics: criticalMetrics,
                isVisible: true,
                iconType: .status,
                showIcon: false
            )
            let normalMetrics = ActivityMetrics.previewNormal
            MetricMenuBarLabel(
                status: ActivityStatus(metrics: normalMetrics),
                metrics: normalMetrics,
                isVisible: true,
                iconType: .cpu,
                showIcon: false
            )
            let networkMetrics = ActivityMetrics.previewNormal
            MetricMenuBarLabel(
                status: ActivityStatus(metrics: networkMetrics),
                metrics: networkMetrics,
                isVisible: true,
                iconType: .network,
                showIcon: true
            )
        }

        Divider()

        ForEach(MetricMenuSelection.allCases, id: \.self) { selection in
            MetricMenuLabel(metrics: .previewNormal, selection: selection, showIcon: true, tint: nil)
                .padding(8)
                .frame(width: 260, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding(24)
    .frame(width: 340, alignment: .leading)
}
#endif
