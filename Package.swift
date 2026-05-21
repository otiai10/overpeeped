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
            path: "Sources/Overpeeped",
            // Resources/skills/ は install.sh が repo から直接コピーするので bundle 不要
            exclude: ["Resources/skills"]
        ),
        .testTarget(
            name: "OverpeepedTests",
            dependencies: ["Overpeeped"],
            path: "Tests/OverpeepedTests"
        )
    ]
)
