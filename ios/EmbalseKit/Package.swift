// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmbalseKit",
    defaultLocalization: "es",
    platforms: [.iOS("27.0"), .watchOS("27.0")],
    products: [
        .library(name: "EmbalseKit", targets: ["EmbalseKit"]),
    ],
    targets: [
        .target(name: "EmbalseKit", resources: [.process("Resources")]),
        .testTarget(name: "EmbalseKitTests", dependencies: ["EmbalseKit"]),
    ]
)
