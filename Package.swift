// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cliq",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Cliq",
            path: "Sources/Cliq",
            exclude: ["Resources"]
        )
    ]
)
