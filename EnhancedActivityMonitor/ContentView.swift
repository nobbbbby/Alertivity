import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: ActivityMonitor

    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var metricMenuIconsEnabled: Bool
    @Binding var cpuMenuIconEnabled: Bool
    @Binding var memoryMenuIconEnabled: Bool
    @Binding var diskMenuIconEnabled: Bool
    @Binding var networkMenuIconEnabled: Bool
    @Binding var processMenuIconEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MetricsSummaryView(metrics: monitor.metrics, status: monitor.status)

            Divider()

            NoticePreferencesView(
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled,
                metricMenuIconsEnabled: $metricMenuIconsEnabled,
                cpuMenuIconEnabled: $cpuMenuIconEnabled,
                memoryMenuIconEnabled: $memoryMenuIconEnabled,
                diskMenuIconEnabled: $diskMenuIconEnabled,
                networkMenuIconEnabled: $networkMenuIconEnabled,
                processMenuIconEnabled: $processMenuIconEnabled
            )
        }
        .padding(32)
        .frame(minWidth: 420, alignment: .leading)
    }
}

struct MetricsSummaryView: View {
    let metrics: ActivityMetrics
    let status: ActivityStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: status.symbolName)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(status.accentColor, .secondary)
                    .font(.system(size: 48))

                VStack(alignment: .leading, spacing: 6) {
                    Text(status.title)
                        .font(.title)
                        .bold()
                    Text(status.message(for: metrics))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    Label("CPU", systemImage: "cpu")
                        .font(.headline)
                    Gauge(value: metrics.cpuUsage, in: 0...1) {
                        Text(metrics.cpuUsage.formatted(.percent.precision(.fractionLength(0))))
                    }
                    .tint(status.accentColor)
                }

                GridRow {
                    Label("Memory", systemImage: "memorychip")
                        .font(.headline)
                    Gauge(value: metrics.memoryUsage, in: 0...1) {
                        Text(metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0))))
                    }
                    .tint(.blue)
                }

                GridRow {
                    Label("Disk", systemImage: "internaldrive")
                        .font(.headline)
                    Gauge(value: metrics.disk.usage, in: 0...1) {
                        Text(metrics.disk.usage.formatted(.percent.precision(.fractionLength(0))))
                    }
                    .tint(.orange)
                }

                GridRow {
                    Label("Network", systemImage: "arrow.up.arrow.down")
                        .font(.headline)
                    Text("↓ \(metrics.network.formattedDownload)/s • ↑ \(metrics.network.formattedUpload)/s")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GridRow {
                    Label("Processes", systemImage: "gearshape")
                        .font(.headline)
                    Text("\(metrics.runningProcesses)")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct NoticePreferencesView: View {
    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var metricMenuIconsEnabled: Bool
    @Binding var cpuMenuIconEnabled: Bool
    @Binding var memoryMenuIconEnabled: Bool
    @Binding var diskMenuIconEnabled: Bool
    @Binding var networkMenuIconEnabled: Bool
    @Binding var processMenuIconEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)

            Toggle(isOn: $isMenuIconEnabled) {
                VStack(alignment: .leading) {
                    Text("Menu bar indicator")
                    Text("Show an activity icon in the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isMenuIconEnabled {
                Toggle(isOn: $menuIconOnlyWhenHigh) {
                    VStack(alignment: .leading) {
                        Text("Only display on high activity")
                        Text("Hide the menu icon until usage reaches the critical threshold.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Toggle(isOn: $metricMenuIconsEnabled) {
                VStack(alignment: .leading) {
                    Text("Metric value icons")
                    Text("Add live CPU, memory, and other values directly to the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if metricMenuIconsEnabled {
                Toggle("CPU usage", isOn: $cpuMenuIconEnabled)
                Toggle("Memory usage", isOn: $memoryMenuIconEnabled)
                Toggle("Disk usage", isOn: $diskMenuIconEnabled)
                Toggle("Network throughput", isOn: $networkMenuIconEnabled)
                Toggle("Running processes", isOn: $processMenuIconEnabled)
            }

            Toggle(isOn: $notificationsEnabled) {
                VStack(alignment: .leading) {
                    Text("System notifications")
                    Text("Deliver macOS notifications when activity is high.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct MenuStatusView: View {
    let metrics: ActivityMetrics
    let status: ActivityStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(status.title)
                .font(.headline)
            Text(status.message(for: metrics))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            LabeledContent("CPU") {
                Text(metrics.cpuUsage.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
            }

            LabeledContent("Memory") {
                Text(metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
            }

            LabeledContent("Disk") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metrics.disk.usage.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                    Text(metrics.disk.formattedUsageSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Network") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("↓ \(metrics.network.formattedDownload)/s • ↑ \(metrics.network.formattedUpload)/s")
                        .monospacedDigit()
                    Text("Total \(metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond))/s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Processes") {
                Text("\(metrics.runningProcesses)")
                    .monospacedDigit()
            }
        }
        .frame(minWidth: 220, alignment: .leading)
    }
}

#Preview("ContentView • Normal") {
    ContentView(
        monitor: ActivityMonitor(metrics: .previewNormal, status: .normal),
        isMenuIconEnabled: .constant(true),
        menuIconOnlyWhenHigh: .constant(false),
        notificationsEnabled: .constant(false),
        metricMenuIconsEnabled: .constant(true),
        cpuMenuIconEnabled: .constant(true),
        memoryMenuIconEnabled: .constant(true),
        diskMenuIconEnabled: .constant(true),
        networkMenuIconEnabled: .constant(true),
        processMenuIconEnabled: .constant(true)
    )
    .frame(minWidth: 420, alignment: .leading)
    .padding()
}

#Preview("ContentView • Critical") {
    ContentView(
        monitor: ActivityMonitor(metrics: .previewCritical, status: .critical),
        isMenuIconEnabled: .constant(true),
        menuIconOnlyWhenHigh: .constant(true),
        notificationsEnabled: .constant(true),
        metricMenuIconsEnabled: .constant(true),
        cpuMenuIconEnabled: .constant(true),
        memoryMenuIconEnabled: .constant(true),
        diskMenuIconEnabled: .constant(true),
        networkMenuIconEnabled: .constant(true),
        processMenuIconEnabled: .constant(true)
    )
    .frame(minWidth: 420, alignment: .leading)
    .padding()
}

#Preview("Metrics Summary • Elevated") {
    MetricsSummaryView(metrics: .previewElevated, status: .elevated)
        .padding()
        .frame(maxWidth: 460)
}

#Preview("Notice Preferences • Icon Enabled") {
    NoticePreferencesView(
        isMenuIconEnabled: .constant(true),
        menuIconOnlyWhenHigh: .constant(true),
        notificationsEnabled: .constant(true),
        metricMenuIconsEnabled: .constant(true),
        cpuMenuIconEnabled: .constant(true),
        memoryMenuIconEnabled: .constant(true),
        diskMenuIconEnabled: .constant(true),
        networkMenuIconEnabled: .constant(true),
        processMenuIconEnabled: .constant(true)
    )
    .padding()
    .frame(width: 360)
}

#Preview("Notice Preferences • Icon Hidden") {
    NoticePreferencesView(
        isMenuIconEnabled: .constant(false),
        menuIconOnlyWhenHigh: .constant(false),
        notificationsEnabled: .constant(false),
        metricMenuIconsEnabled: .constant(false),
        cpuMenuIconEnabled: .constant(false),
        memoryMenuIconEnabled: .constant(false),
        diskMenuIconEnabled: .constant(false),
        networkMenuIconEnabled: .constant(false),
        processMenuIconEnabled: .constant(false)
    )
    .padding()
    .frame(width: 360)
}

#Preview("Menu Status • Critical") {
    MenuStatusView(metrics: .previewCritical, status: .critical)
        .padding()
        .frame(width: 240, alignment: .leading)
}
