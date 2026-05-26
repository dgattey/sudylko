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
        .executable(name: "SudylkoIconExport", targets: ["SudylkoIconExport"]),
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
        .executableTarget(
            name: "SudylkoIconExport",
            dependencies: ["SudylkoShared"],
            path: "Sources/SudylkoIconExport"
        ),
    ]
)
