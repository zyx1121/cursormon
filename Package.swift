// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cursormon",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Cursormon", path: "Sources/Cursormon")
    ]
)
