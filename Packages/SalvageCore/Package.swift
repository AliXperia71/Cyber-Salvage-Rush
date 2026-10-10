// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalvageCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SalvageCore", targets: ["SalvageCore"]),
    ],
    targets: [
        .target(name: "SalvageCore"),
        .testTarget(name: "SalvageCoreTests", dependencies: ["SalvageCore"]),
    ]
)
