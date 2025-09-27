import Foundation
import UserNotifications

final class NotificationManager: NSObject, ObservableObject {
    private let notificationCenter = UNUserNotificationCenter.current()
    private var lastNotificationDate: Date?
    private let throttleInterval: TimeInterval = 60 * 10
    private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        notificationCenter.delegate = self
        Task {
            await refreshAuthorizationStatus()
        }
    }

    func requestAuthorizationIfNeeded() {
        guard authorizationStatus == .notDetermined else { return }
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            Task { await self?.refreshAuthorizationStatus() }
            if !granted {
                self?.lastNotificationDate = nil
            }
        }
    }

    func postNotificationIfNeeded(for status: ActivityStatus, metrics: ActivityMetrics) {
        guard authorizationStatus == .authorized else { return }
        guard status == .critical else { return }

        let now = Date()
        if let last = lastNotificationDate, now.timeIntervalSince(last) < throttleInterval {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = status.title
        content.body = status.message(for: metrics)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
        lastNotificationDate = now
    }

    @MainActor
    private func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
