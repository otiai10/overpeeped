// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Overpeeped",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Overpeeped",
            path: "Sources/Overpeeped"
        ),
        .testTarget(
            name: "OverpeepedTests",
            dependencies: ["Overpeeped"],
            path: "Tests/OverpeepedTests"
        )
    ]
)
