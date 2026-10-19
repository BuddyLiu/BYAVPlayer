// swift-tools-version: 5.10
//
// BYAVPlayer — a zero-dependency, configurable SwiftUI wrapper over AVFoundation's
// three rendering paths (VideoPlayer / AVPlayerViewController / AVPlayerLayer).
//
// Language mode is pinned to Swift 5 so callers on older toolchains can still
// consume the package; the code itself is written to be MainActor-clean.

import PackageDescription

let package = Package(
    name: "BYAVPlayer",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BYAVPlayer", targets: ["BYAVPlayer"])
    ],
    targets: [
        .target(
            name: "BYAVPlayer",
            path: "Sources/BYAVPlayer"
        ),
        .testTarget(
            name: "BYAVPlayerTests",
            dependencies: ["BYAVPlayer"],
            path: "Tests/BYAVPlayerTests"
        )
    ]
)