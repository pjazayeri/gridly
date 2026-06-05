// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Gridly",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Gridly",
            path: "Sources/Gridly",
            resources: [.process("Assets.xcassets")]
        )
    ]
)
