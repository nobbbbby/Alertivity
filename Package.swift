// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnhancedActivityMonitor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EnhancedActivityMonitor", targets: ["EnhancedActivityMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "EnhancedActivityMonitor",
            path: "Sources"
        )
    ]
)
