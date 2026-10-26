// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sudylko",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .executable(name: "Sudylko", targets: ["Sudylko"]),
        .library(name: "SudylkoDockTilePlugin", type: .dynamic, targets: ["SudylkoDockTilePlugin"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/dgattey/dyl-kit",
            revision: "facb7feb389dee1fd20695d6b2a16099fcdbe8e7"
        ),
    ],
    targets: [
        .target(
            name: "SudylkoShared",
            path: "Sources/SudylkoShared"
        ),
        .executableTarget(
            name: "Sudylko",
            dependencies: [
                "SudylkoShared",
                .product(name: "DylCore", package: "dyl-kit"),
                .product(name: "DylUI", package: "dyl-kit"),
                .product(name: "DylUpdates", package: "dyl-kit"),
            ],
            path: "Sources/Sudylko"
        ),
        .target(
            name: "SudylkoDockTilePlugin",
            dependencies: ["SudylkoShared"],
            path: "Sources/SudylkoDockTilePlugin",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SudylkoLogicTests",
            dependencies: ["Sudylko"],
            path: "Tests/SudylkoLogicTests"
        ),
    ]
)
