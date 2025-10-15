import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var monitor: ActivityMonitor

    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var menuIconType: MenuIconType
    @Binding var showMetricIcon: Bool
    @Binding var highActivityDurationSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MetricsSummaryView(metrics: monitor.metrics, status: monitor.status)

            Divider()

            NoticePreferencesView(
                isMenuIconEnabled: $isMenuIconEnabled,
                menuIconOnlyWhenHigh: $menuIconOnlyWhenHigh,
                notificationsEnabled: $notificationsEnabled,
                menuIconType: $menuIconType,
                showMetricIcon: $showMetricIcon,
                highActivityDurationSeconds: $highActivityDurationSeconds
            )
        }
        .frame(minWidth: 300, alignment: .leading)
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
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if metrics.hasLiveData {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                    GridRow {
                        Label("CPU", systemImage: "cpu")
                            .font(.headline)
                        metricGauge(
                            value: metrics.cpuUsage,
                            tint: status.accentColor,
                            formattedValue: metrics.cpuUsage.formatted(.percent.precision(.fractionLength(0)))
                        )
                    }

                    GridRow {
                        Label("Memory", systemImage: "memorychip")
                            .font(.headline)
                        metricGauge(
                            value: metrics.memoryUsage,
                            tint: .blue,
                            formattedValue: metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
                        )
                    }

                    GridRow {
                        Label("Disk", systemImage: "internaldrive")
                            .font(.headline)
                        metricGauge(
                            value: metrics.disk.usage,
                            tint: .orange,
                            formattedValue: metrics.disk.usage.formatted(.percent.precision(.fractionLength(0)))
                        )
                    }

                    GridRow {
                        Label("Network", systemImage: "arrow.up.arrow.down")
                            .font(.headline)
                        Text("↓ \(metrics.network.formattedDownload)/s • ↑ \(metrics.network.formattedUpload)/s")
                            .monospacedDigit()
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
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
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressView()
                    Text("Waiting for live system metrics…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private func metricGauge(value: Double, tint: Color, formattedValue: String) -> some View {
    HStack(spacing: 12) {
        Gauge(value: value, in: 0...1) { EmptyView() }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(tint)
        
        Text(formattedValue)
            .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

struct NoticePreferencesView: View {
    @Binding var isMenuIconEnabled: Bool
    @Binding var menuIconOnlyWhenHigh: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var menuIconType: MenuIconType
    @Binding var showMetricIcon: Bool
    @Binding var highActivityDurationSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Menu Bar Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Menu Bar")
                    .font(.headline)
                
                Toggle(isOn: $isMenuIconEnabled) {
                    VStack(alignment: .leading) {
                        Text("Show indicator")
                        Text("Display an activity icon in the menu bar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                if isMenuIconEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $menuIconOnlyWhenHigh) {
                            VStack(alignment: .leading) {
                                Text("Only show on high activity")
                                Text("Hide the icon until usage reaches the critical threshold.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Form {
                            Section (header: Text("Icon type")){
                                Picker("", selection: $menuIconType) {
                                    ForEach(MenuIconType.allCases) { iconType in
                                        Label(iconType.title, systemImage: iconType.symbolName)
                                            .tag(iconType)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 220, alignment: .leading)
                                
                                if menuIconType.metricSelection != nil {
                                    Toggle(isOn: $showMetricIcon) {
                                        VStack(alignment: .leading) {
                                            Text("Show metric icon")
                                            Text("Display an icon alongside the metric value.")
                                                .lineLimit(nil)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                }
                            }
                        
                        }
                 
                    }
                    .padding(.leading, 20)
                }
            }
            
            Divider()
            
            // Notifications Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Notifications")
                    .font(.headline)
                
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading) {
                        Text("Enable system notifications")
                        Text("Deliver macOS notifications when activity is high.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Shared Settings Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Detection Settings")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("High activity duration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .bold()
                    Stepper(value: $highActivityDurationSeconds, in: 10...600, step: 5) {
                        Text("\(highActivityDurationSeconds) seconds")
                            .monospacedDigit()
                    }
                    Text("High-activity processes must stay active for at least this long to appear.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
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
                .lineLimit(nil)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                

            Divider()

            if metrics.hasLiveData {
                MenuMetricRow(systemImage: "cpu") {
                    Text(metrics.cpuUsage.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                }

                MenuMetricRow(systemImage: "memorychip") {
                    Text(metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                }

                MenuMetricRow(systemImage: "internaldrive") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metrics.disk.usage.formatted(.percent.precision(.fractionLength(0))))
                            .monospacedDigit()
                    }
                }

                MenuMetricRow(systemImage: "arrow.up.arrow.down") {
                    Text("↓ \(metrics.network.formattedDownload)/s • ↑ \(metrics.network.formattedUpload)/s")
                        .monospacedDigit()
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                MenuMetricRow(systemImage: "gearshape") {
                    Text("\(metrics.runningProcesses)")
                        .monospacedDigit()
                }

                if !metrics.highActivityProcesses.isEmpty {
                    Divider()
                    Text("High-activity processes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .bold()
                    ForEach(Array(metrics.highActivityProcesses.prefix(3))) { process in
                        HStack(){
                            Button {
                                ProcessActions.revealInActivityMonitor(process)
                            } label: {
                                MenuProcessRow(process: process)
                            }
                            .buttonStyle(.plain)
                            
                            Button("",systemImage: "xmark.circle") {
                                ProcessActions.terminate(process)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressView()
                    Text("Metrics will appear once the first sample is available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 220, alignment: .leading)
    }
}

private struct MenuMetricRow<Content: View>: View {
    let systemImage: String
    let content: () -> Content

    init(systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 20, alignment: .center)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MenuProcessRow: View {
    let process: ProcessUsage

    var body: some View {

            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 12) {
                    let path = process.command
                    let appPath: String = {
                        if let range = path.range(of: ".app/") {
                            return String(path[..<range.lowerBound]) + ".app"
                        } else {
                            return path
                        }
                    }()
                    let nsImage = NSWorkspace.shared.icon(forFile: appPath)
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 16, height: 16)
                    
                    Text(process.displayName)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Text("CPU \(process.cpuDescription) • Mem \(process.memoryDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
    }
}

#Preview("ContentView • Normal") {
    ContentView(
        monitor: ActivityMonitor(metrics: .previewNormal, status: .normal, autoStart: false),
        isMenuIconEnabled: .constant(true),
        menuIconOnlyWhenHigh: .constant(false),
        notificationsEnabled: .constant(false),
        menuIconType: .constant(.cpu),
        showMetricIcon: .constant(false),
        highActivityDurationSeconds: .constant(60)
    )
    .frame(minWidth: 200, alignment: .leading)
    .padding()
}

#Preview("ContentView • Critical") {
    ContentView(
        monitor: ActivityMonitor(metrics: .previewCritical, status: .critical, autoStart: false),
        isMenuIconEnabled: .constant(true),
        menuIconOnlyWhenHigh: .constant(true),
        notificationsEnabled: .constant(true),
        menuIconType: .constant(.cpu),
        showMetricIcon: .constant(true),
        highActivityDurationSeconds: .constant(60)
    )
    .frame(minWidth: 300, alignment: .leading)
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
        menuIconType: .constant(.memory),
        showMetricIcon: .constant(true),
        highActivityDurationSeconds: .constant(60)
    )
    .padding()
    .frame(width: 360)
}

#Preview("Notice Preferences • Icon Hidden") {
    NoticePreferencesView(
        isMenuIconEnabled: .constant(false),
        menuIconOnlyWhenHigh: .constant(false),
        notificationsEnabled: .constant(false),
        menuIconType: .constant(.status),
        showMetricIcon: .constant(false),
        highActivityDurationSeconds: .constant(60)
    )
    .padding()
    .frame(width: 360)
}

#Preview("Menu Status • Critical") {
    MenuStatusView(metrics: .previewCritical, status: .critical)
        .padding()
        .frame(width: 240, alignment: .leading)
}
