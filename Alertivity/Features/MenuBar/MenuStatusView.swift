import AppKit
import SwiftUI

struct MenuStatusView: View {
    let metrics: ActivityMetrics
    let onAddToWhitelist: (String) -> Void

    init(
        metrics: ActivityMetrics,
        onAddToWhitelist: @escaping (String) -> Void = { _ in }
    ) {
        self.metrics = metrics
        self.onAddToWhitelist = onAddToWhitelist
    }

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

                            Button("", systemImage: "checkmark.shield") {
                                onAddToWhitelist(process.command)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .help(Text("notifications.action.ignoreProcess"))
                            .accessibilityLabel(Text("notifications.action.ignoreProcess"))

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
        HStack(alignment: .center, spacing: 10) {
            Image(nsImage: processIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(process.displayName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(.none)
                    .fixedSize(horizontal: false, vertical: true)

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var processIcon: NSImage {
        let executablePath = process.command
        guard let appBundleMarker = executablePath.range(of: ".app/") else {
            return NSWorkspace.shared.icon(forFile: executablePath)
        }

        let appBundlePath = String(executablePath[..<appBundleMarker.lowerBound]) + ".app"
        return NSWorkspace.shared.icon(forFile: appBundlePath)
    }
}

// MARK: - Previews

#if DEBUG && !DISABLE_PREVIEWS
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

#Preview("High Activity Process Actions") {
    MenuStatusView(
        metrics: .previewCritical,
        onAddToWhitelist: { _ in }
    )
    .frame(width: 280)
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

// Worst-case summary at the compact width: all four critical thresholds are visible.
#Preview("Menu Status – All Four Critical") {
    var metrics = ActivityMetrics.previewMultiCritical
    metrics.memoryUsed = Measurement(value: 29, unit: .gigabytes)
    return MenuStatusView(metrics: metrics)
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
