// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zenith",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Zenith",
            path: "Sources/Zenith",
            resources: [.process("Assets.xcassets")]
        )
    ]
)
