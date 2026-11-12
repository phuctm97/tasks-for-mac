// swift-tools-version: 6.2
// Tasks for Mac: a small, fast, local-only task list for macOS (SwiftUI).
import PackageDescription

let package = Package(
    name: "TasksForMac",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "TasksForMac"),
    ],
)
