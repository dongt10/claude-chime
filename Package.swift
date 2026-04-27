// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClaudeChime",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClaudeChime", targets: ["ClaudeChime"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeChime",
            path: "Sources/ClaudeChime"
        ),
        .testTarget(
            name: "ClaudeChimeTests",
            dependencies: ["ClaudeChime"],
            path: "Tests/ClaudeChimeTests"
        )
    ]
)
