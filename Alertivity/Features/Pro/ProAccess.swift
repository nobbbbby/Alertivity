import Foundation

/// Monetization follows the build target, never whether process sampling happens to work.
enum AppDistribution {
    case appStore, openSource

    static var current: Self {
#if APP_STORE
        .appStore
#else
        .openSource
#endif
    }
}

/// Runtime values are separate from saved preferences so losing access never destroys customization.
struct MonitoringConfiguration: Equatable {
    let thresholds: ActivityThresholds
    let cooldownMinutes: Int
    let durationSeconds: Int
}
