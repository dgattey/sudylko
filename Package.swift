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
    ],
    dependencies: [
        .package(url: "https://github.com/dgattey/dyl-kit", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "Sudylko",
            dependencies: [
                .product(name: "DylCore", package: "dyl-kit"),
                .product(name: "DylUI", package: "dyl-kit"),
                .product(name: "DylUpdates", package: "dyl-kit"),
            ],
            path: "Sources/Sudylko"
        ),
        .testTarget(
            name: "SudylkoLogicTests",
            dependencies: [
                "Sudylko",
                .product(name: "DylTestSupport", package: "dyl-kit"),
            ],
            path: "Tests/SudylkoLogicTests"
        ),
    ]
)
