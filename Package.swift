// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "poof",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PoofCore", path: "Sources/PoofCore"),
        .executableTarget(name: "poof", dependencies: ["PoofCore"], path: "Sources/poof"),
        .testTarget(name: "PoofCoreTests", dependencies: ["PoofCore"], path: "Tests/PoofCoreTests"),
    ]
)
