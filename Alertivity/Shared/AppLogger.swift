import Foundation
import OSLog

/// Shared logging categories keep operational events searchable without coupling features to a logging backend.
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Alertivity"

    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let metrics = Logger(subsystem: subsystem, category: "metrics")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let purchases = Logger(subsystem: subsystem, category: "purchases")
    static let reviews = Logger(subsystem: subsystem, category: "reviews")
}
