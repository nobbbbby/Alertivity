import SwiftUI

enum MetricMenuSelection: CaseIterable, Hashable, Sendable {
    case cpu
    case memory
    case disk
    case network
    case processes

    static func enabled(
        cpu: Bool,
        memory: Bool,
        disk: Bool,
        network: Bool,
        processes: Bool
    ) -> [MetricMenuSelection] {
        var selections: [MetricMenuSelection] = []
        if cpu { selections.append(.cpu) }
        if memory { selections.append(.memory) }
        if disk { selections.append(.disk) }
        if network { selections.append(.network) }
        if processes { selections.append(.processes) }
        return selections
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
            return "arrow.up.arrow.down.circle"
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

    var body: some View {
        Text("\(selection.shortLabel) \(selection.formattedValue(for: metrics))")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
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
    let showStatusSymbol: Bool
    let selections: [MetricMenuSelection]

    var body: some View {
        HStack(spacing: 6) {
            if showStatusSymbol {
                Image(systemName: status.symbolName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(status.accentColor, .secondary)
            }

            if selections.isEmpty {
                if !showStatusSymbol {
                    Image(systemName: status.symbolName)
                        .foregroundStyle(.primary)
                }
            } else {
                ForEach(selections, id: \.self) { selection in
                    MetricMenuLabel(metrics: metrics, selection: selection)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .accessibilityLabel("System metrics")
        .accessibilityValue(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard !selections.isEmpty else {
            return status.title
        }

        return selections
            .map { "\($0.shortLabel) \($0.formattedValue(for: metrics))" }
            .joined(separator: ", ")
    }
}

struct MetricMenuDetailView: View {
    let metrics: ActivityMetrics
    let selection: MetricMenuSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(selection.title)
                    .font(.headline)
            } icon: {
                Image(systemName: selection.symbolName)
            }

            detailContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .cpu:
            let status = ActivityStatus(metrics: metrics)
            Gauge(value: metrics.cpuUsage, in: 0...1) {
                Text(metrics.cpuUsage.formatted(.percent.precision(.fractionLength(1))))
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(status.accentColor)
            Text("Status: \(status.title)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .memory:
            Gauge(value: metrics.memoryUsage, in: 0...1) {
                Text(metrics.memoryUsage.formatted(.percent.precision(.fractionLength(1))))
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(.blue)
            Text(selection.detailSummary(for: metrics))
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .disk:
            Gauge(value: metrics.disk.usage, in: 0...1) {
                Text(metrics.disk.usage.formatted(.percent.precision(.fractionLength(1))))
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(.orange)
            Text(selection.detailSummary(for: metrics))
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .network:
            VStack(alignment: .leading, spacing: 4) {
                Text("Download: \(metrics.network.formattedDownload)/s")
                Text("Upload: \(metrics.network.formattedUpload)/s")
                Text("Total: \(metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond))/s")
            }
            .monospacedDigit()
            .font(.footnote)
            .foregroundStyle(.secondary)
        case .processes:
            Text(selection.detailSummary(for: metrics))
                .font(.title3)
                .monospacedDigit()
            Text("Process count reflects the latest system sample.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
struct MetricMenuViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            MetricMenuBarLabel(
                status: .normal,
                metrics: .previewNormal,
                showStatusSymbol: true,
                selections: [.cpu, .memory, .network]
            )

            ForEach(MetricMenuSelection.allCases, id: \.self) { selection in
                MetricMenuDetailView(metrics: .previewNormal, selection: selection)
                    .padding()
                    .frame(width: 260, alignment: .leading)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .frame(width: 320, alignment: .leading)
    }
}
#endif
