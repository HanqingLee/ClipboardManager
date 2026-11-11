// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [.macOS(.v13)],
    products: [
        // 显式 library product：Xcode 工程通过本地 package 依赖它，
        // `swift test` 仍直接使用下面的 target。
        .library(name: "ClipboardManagerCore", targets: ["ClipboardManagerCore"]),
    ],
    targets: [
        .target(
            name: "ClipboardManagerCore",
            path: "Sources/ClipboardManagerCore"
        ),
        .executableTarget(
            name: "ClipboardManager",
            dependencies: ["ClipboardManagerCore"],
            path: "Sources/ClipboardManager",
            // SwiftPM 只构建商店版（无自动粘贴）；直发版由 Xcode target 选择另一份实现。
            exclude: ["AutoPaste/AutoPasteEngine+Direct.swift"]
        ),
        .testTarget(
            name: "ClipboardManagerCoreTests",
            dependencies: ["ClipboardManagerCore"],
            path: "Tests/ClipboardManagerCoreTests"
        ),
    ]
)