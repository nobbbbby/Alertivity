#if DEBUG
import OSLog
import SwiftUI

/// A separate utility keeps simulation controls out of the panel being photographed.
struct ActivitySimulatorView: View {
    @Binding var preset: CapturePreset
    let metrics: ActivityMetrics
    @ObservedObject var notificationManager: NotificationManager
    @State private var notificationKind: CaptureNotificationKind = .system
    @State private var isSending = false
    @State private var notificationScheduled = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label {
                Text(verbatim: "Debug only · Simulated readings")
            } icon: {
                Image(systemName: "camera")
            }
            .font(.headline)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(selection: $preset) {
                        ForEach(CapturePreset.allCases) { item in
                            Text(verbatim: item.rawValue).tag(item)
                        }
                    } label: {
                        Text(verbatim: "Preset")
                    }
                    .accessibilityIdentifier("capture.preset")
                    Text(verbatim: "The selected readings stay steady in the metrics panel and menu bar icon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            } label: {
                Text(verbatim: "Display")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    if CaptureNotificationKind.availableCases.count > 1 {
                        Picker(selection: $notificationKind) {
                            ForEach(CaptureNotificationKind.availableCases) { kind in
                                Text(verbatim: kind.rawValue).tag(kind)
                            }
                        } label: {
                            Text(verbatim: "Alert type")
                        }
                        .accessibilityIdentifier("capture.notificationKind")
                    }
                    Button(action: sendNotification) {
                        Text(verbatim: isSending ? "Scheduling notification…" : "Send preview notification")
                    }
                    .disabled((preset == .live && notificationKind == .system) || isSending)
                    .accessibilityIdentifier("capture.sendNotification")
                    Text(verbatim: notificationScheduled
                         ? "Notification scheduled. macOS notification and Focus settings control whether a banner appears."
                         : notificationKind == .system
                             ? "Choose a simulated preset, then send a real notification with a three-second delay. Notification permission is required."
                             : "Preview a detected Xcode process using sample CPU and memory readings. Sends after three seconds; process action buttons have no effect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            } label: {
                Text(verbatim: "Notification preview")
            }

            HStack {
                Button {
                    preset = .live
                } label: {
                    Text(verbatim: "Return to Live")
                }
                .disabled(preset == .live)
                .accessibilityIdentifier("capture.returnToLive")
                Spacer()
                Text(verbatim: preset == .live ? "Live readings" : preset.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("capture.activePreset")
            }
            Text(verbatim: "Closing this window keeps the preset active. Monitoring and saved settings remain unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: preset) { notificationScheduled = false }
        .onChange(of: notificationKind) { notificationScheduled = false }
        .alert(Text(verbatim: "Preview notification"), isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
    }

    private func sendNotification() {
        // Keep the requested banner stable even if the display preset changes during permission UI.
        let snapshot = metrics
        let process = notificationKind.process
        isSending = true
        notificationScheduled = false
        Task { @MainActor in
            defer { isSending = false }
            do {
                try await notificationManager.sendCaptureNotification(metrics: snapshot, process: process)
                notificationScheduled = true
            } catch {
                errorMessage = error.localizedDescription
                AppLogger.notifications.error("Capture notification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
#endif
