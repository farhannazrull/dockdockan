// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SecondDock",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SecondDock", targets: ["SecondDock"]),
        .library(name: "SecondDockKit", targets: ["SecondDockKit"]),
    ],
    targets: [
        .executableTarget(
            name: "SecondDock",
            dependencies: ["SecondDockKit"],
            path: "Sources/SecondDock"
        ),
        .target(
            name: "SecondDockKit",
            path: "Sources/SecondDockKit"
        ),
        // Pemeriksa formatter yang bisa jalan dengan CLT saja
        // (XCTest butuh Xcode penuh; migrasi: bungkus fungsi check jadi XCTest).
        .executableTarget(
            name: "FormatterChecks",
            dependencies: ["SecondDockKit"],
            path: "Tools/FormatterChecks"
        ),
        .executableTarget(
            name: "RenderShots",
            dependencies: ["SecondDockKit"],
            path: "Tools/RenderShots"
        ),
    ]
)
