// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BearOCR",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BearOCR", targets: ["BearOCR"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.1"),
    ],
    targets: [
        .executableTarget(
            name: "BearOCR",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/BearOCR"
        )
    ]
)
