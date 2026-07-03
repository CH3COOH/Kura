// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kura",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "kura-generator", targets: ["KuraGenerator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        // 1. 実処理ロジック
        .executableTarget(
            name: "KuraGenerator",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ]
        ),

        // 2. テスト
        .testTarget(
            name: "KuraGeneratorTests",
            dependencies: ["KuraGenerator"]
        ),
    ]
)
