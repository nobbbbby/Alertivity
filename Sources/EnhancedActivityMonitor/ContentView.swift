import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor: ActivityMonitor

    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MetricsSummaryView(metrics: monitor.metrics, status: monitor.status)

            Divider()

            NoticePreferencesView(
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled
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

            LabeledContent("Processes") {
                Text("\(metrics.runningProcesses)")
                    .monospacedDigit()
            }
        }
        .frame(minWidth: 220, alignment: .leading)
    }
}
