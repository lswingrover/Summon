// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Summon",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Summon", targets: ["Summon"])
    ],
    targets: [
        // Pure-logic library — no AppKit, fully testable
        .target(
            name: "SummonCore",
            path: "Sources/SummonCore"
        ),
        // App executable — AppKit, CGEventTap, UI
        .executableTarget(
            name: "Summon",
            dependencies: ["SummonCore"],
            path: "Sources/Summon"
        ),
        // Unit tests — SummonCore only
        .testTarget(
            name: "SummonTests",
            dependencies: ["SummonCore"],
            path: "Tests/SummonTests"
        )
    ]
)
