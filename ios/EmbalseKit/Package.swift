// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmbalseKit",
    platforms: [.iOS("27.0"), .watchOS("27.0")],
    products: [
        .library(name: "EmbalseKit", targets: ["EmbalseKit"]),
    ],
    targets: [
        .target(name: "EmbalseKit"),
        .testTarget(name: "EmbalseKitTests", dependencies: ["EmbalseKit"]),
    ]
)
