// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ClipboardManagerCore",
            path: "Sources/ClipboardManagerCore"
        ),
        .executableTarget(
            name: "ClipboardManager",
            dependencies: ["ClipboardManagerCore"],
            path: "Sources/ClipboardManager"
        ),
        .testTarget(
            name: "ClipboardManagerCoreTests",
            dependencies: ["ClipboardManagerCore"],
            path: "Tests/ClipboardManagerCoreTests"
        ),
    ]
)