// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PulseShared",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [.library(name: "PulseShared", targets: ["PulseShared"])],
    targets: [
        .target(
            name: "PulseShared",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "PulseSharedTests", dependencies: ["PulseShared"]),
    ]
)
