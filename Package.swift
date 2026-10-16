// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "APIInspector",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "APIInspector", targets: ["APIInspector"]),
        .library(name: "APIInspectorCore", targets: ["APIInspectorCore"])
    ],
    targets: [
        .target(name: "APIInspectorCore"),
        .target(name: "APIInspector", dependencies: ["APIInspectorCore"]),
        .testTarget(name: "APIInspectorCoreTests", dependencies: ["APIInspectorCore"])
    ],
    swiftLanguageModes: [.v6]
)
