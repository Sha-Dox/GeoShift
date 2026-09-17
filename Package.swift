// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GeoShift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GeoShift", targets: ["GeoShift"])
    ],
    targets: [
        .executableTarget(
            name: "GeoShift",
            path: "Sources/GeoShift"
        ),
        .testTarget(name: "GeoShiftTests", dependencies: ["GeoShift"])
    ]
)
