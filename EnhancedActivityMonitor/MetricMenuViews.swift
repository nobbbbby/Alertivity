import SwiftUI
import AppKit

enum MenuIconType: String, CaseIterable, Identifiable, Sendable {
    case status
    case cpu
    case memory
    case disk
    case network
    case processes

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
            return "Disk activity"
        case .network:
            return "Network throughput"
        case .processes:
            return "Running processes"
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
        case .processes:
            return "gearshape"
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
        case .processes:
            return .processes
        }
    }
}

enum MetricMenuSelection: CaseIterable, Hashable, Sendable {
    case cpu
    case memory
    case disk
    case network
    case processes

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
        case .processes:
            return "PRC"
        }
    }

    var title: String {
        switch self {
        case .cpu:
            return "CPU Usage"
        case .memory:
            return "Memory Usage"
        case .disk:
            return "Disk Activity"
        case .network:
            return "Network Throughput"
        case .processes:
            return "Running Processes"
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
        case .processes:
            return "gearshape"
        }
    }

    func formattedValue(for metrics: ActivityMetrics) -> String {
        switch self {
        case .cpu:
            metrics.cpuUsage.formatted(.percent.precision(.fractionLength(0)))
        case .memory:
            metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
        case .disk:
            metrics.disk.usage.formatted(.percent.precision(.fractionLength(0)))
        case .network:
            metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond) + "/s"
        case .processes:
            "\(metrics.runningProcesses)"
        }
    }

    func accessibilityValue(for metrics: ActivityMetrics) -> String {
        switch self {
        case .cpu:
            return "CPU usage \(metrics.cpuUsage.formatted(.percent.precision(.fractionLength(1))))"
        case .memory:
            return "Memory usage \(metrics.memoryUsage.formatted(.percent.precision(.fractionLength(1))))"
        case .disk:
            return "Disk usage \(metrics.disk.usage.formatted(.percent.precision(.fractionLength(1))))"
        case .network:
            return "Total network throughput \(metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond)) per second"
        case .processes:
            return "\(metrics.runningProcesses) running processes"
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
            return metrics.disk.formattedUsageSummary
        case .network:
            return "↓ \(metrics.network.formattedDownload)/s • ↑ \(metrics.network.formattedUpload)/s"
        case .processes:
            return "Currently tracking \(metrics.runningProcesses) processes"
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

struct MetricMenuLabel: View {
    let metrics: ActivityMetrics
    let selection: MetricMenuSelection
    let showIcon: Bool

    var body: some View {
        HStack(spacing: 4) {
            if selection == .network {
                let nsImage = MenuBarNetworkStackedRenderer.makeImage(
                    download: metrics.network.formattedDownload + "/s",
                    upload: metrics.network.formattedUpload + "/s",
                    symbolName: showIcon ? selection.symbolName : nil
                )
                Image(nsImage: nsImage)
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
            } else {
                if showIcon {
                    Image(systemName: selection.symbolName)
                        .font(.system(size: 11, weight: .medium))
                        .fixedSize()
                        .layoutPriority(1)
                }

                Text(selection.formattedValue(for: metrics))
                    .font(.system(size: 12, design: .rounded))
                    .monospacedDigit()
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
                    Image(systemName: status.symbolName)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(status.accentColor, .secondary)
                case .cpu, .memory, .disk, .network, .processes:
                    if let selection = iconType.metricSelection {
                        MetricMenuLabel(metrics: metrics, selection: selection, showIcon: showIcon)
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

        return status.title
    }
}

struct MetricMenuDetailView: View {
    let metrics: ActivityMetrics
    let selection: MetricMenuSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(selection.title)
                    .font(.headline)
            } icon: {
                Image(systemName: selection.symbolName)
            }

            detailContent
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(3)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .cpu:
            let status = ActivityStatus(metrics: metrics)
            gaugeRow(
                value: metrics.cpuUsage,
                tint: status.accentColor,
                title: selection.title,
                formattedValue: metrics.cpuUsage.formatted(.percent.precision(.fractionLength(1)))
            )
            Text("Status: \(status.title)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        case .memory:
            gaugeRow(
                value: metrics.memoryUsage,
                tint: .blue,
                title: selection.title,
                formattedValue: metrics.memoryUsage.formatted(.percent.precision(.fractionLength(1)))
            )
            Text(selection.detailSummary(for: metrics))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        case .disk:
            gaugeRow(
                value: metrics.disk.usage,
                tint: .orange,
                title: selection.title,
                formattedValue: metrics.disk.usage.formatted(.percent.precision(.fractionLength(1)))
            )
            Text(selection.detailSummary(for: metrics))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        case .network:
            VStack(alignment: .leading, spacing:0) {
                Text("Download: \(metrics.network.formattedDownload)/s")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Upload: \(metrics.network.formattedUpload)/s")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Total: \(metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond))/s")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .monospacedDigit()
            .font(.footnote)
            .foregroundStyle(.secondary)
        case .processes:
            Text(selection.detailSummary(for: metrics))
                .font(.title3)
                .monospacedDigit()
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("Process count reflects the latest system sample.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func gaugeRow(value: Double, tint: Color, title: String, formattedValue: String) -> some View {
        HStack(spacing: 8) {
            Gauge(value: value, in: 0...1) {
                Text(title)
            } currentValueLabel: {
                EmptyView()
            }
            .labelsHidden()
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(tint)
            .frame(maxWidth: .infinity)

            Text(formattedValue)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .accessibilityLabel(title)
        .accessibilityValue(formattedValue)
    }
}

// Helper for rendering a compact two-line network badge as an NSImage suitable for the menu bar label
private enum MenuBarNetworkStackedRenderer {
    static func makeImage(download: String, upload: String, symbolName: String? = nil) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        // Draw in white and mark as template so the system can tint appropriately
        let color = NSColor.white
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        let line1 = NSString(string: "↓ " + download)
        let line2 = NSString(string: "↑ " + upload)

        let size1 = line1.size(withAttributes: attrs)
        let size2 = line2.size(withAttributes: attrs)
        let spacing: CGFloat = 0.0
        let textBlockWidth = ceil(max(size1.width, size2.width))
        let textBlockHeight = ceil(size1.height + spacing + size2.height)

        // Optional SF Symbol on the left
        let iconSpacing: CGFloat = symbolName == nil ? 0 : 4
        var iconSize = NSSize(width: 0, height: 0)
        var symbolImage: NSImage?
        if let name = symbolName, let baseSymbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            let baseConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            // Render symbol in white; final image will be template-tinted by SwiftUI
            if let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: .white).applying(baseConfig) as NSImage.SymbolConfiguration?,
               let tinted = baseSymbol.withSymbolConfiguration(colorConfig) {
                symbolImage = tinted
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

        image.isTemplate = true
        return image
    }
}

#if DEBUG
#Preview("Metric Menu Components") {
    VStack(alignment: .leading, spacing: 24) {
        HStack(spacing: 16) {
            MetricMenuBarLabel(
                status: .critical,
                metrics: .previewCritical,
                isVisible: true,
                iconType: .status,
                showIcon: false
            )
            MetricMenuBarLabel(
                status: .normal,
                metrics: .previewNormal,
                isVisible: true,
                iconType: .cpu,
                showIcon: false
            )
            MetricMenuBarLabel(
                status: .normal,
                metrics: .previewNormal,
                isVisible: true,
                iconType: .network,
                showIcon: true
            )
        }

        Divider()

        ForEach(MetricMenuSelection.allCases, id: \.self) { selection in
            MetricMenuDetailView(metrics: .previewNormal, selection: selection)
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
