// swift-tools-version: 5.9
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
    targets: [
        .target(
            name: "SudylkoShared",
            path: "Sources/SudylkoShared"
        ),
        .executableTarget(
            name: "Sudylko",
            dependencies: ["SudylkoShared"],
            path: "Sources/Sudylko"
        ),
        .target(
            name: "SudylkoDockTilePlugin",
            dependencies: ["SudylkoShared"],
            path: "Sources/SudylkoDockTilePlugin",
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .unsafeFlags(
                    [
                        "-Xlinker", "-bundle",
                        "-Xlinker", "-undefined",
                        "-Xlinker", "dynamic_lookup",
                    ],
                    .when(platforms: [.macOS])
                ),
            ]
        ),
    ]
)
