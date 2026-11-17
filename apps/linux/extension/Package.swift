// swift-tools-version: 6.2
// The Linux client's bridge: loads the shared Crib Maze engine into Godot through SwiftGodot.
// Layout: ../../../PORTING.md › Layout. Owner: @linux (AGENTS.md).
import PackageDescription

let package = Package(
    name: "CribMazeGodot",
    products: [.library(name: "CribMazeGodot", type: .dynamic, targets: ["CribMazeGodot"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftGodot", exact: "0.99.2"),
        .package(name: "CribMazeEngine", path: "../../../engine/swift"),
    ],
    targets: [
        .target(
            name: "CribMazeGodot",
            dependencies: [
                "SwiftGodot",
                .product(name: "GameKit", package: "CribMazeEngine"),
                .product(name: "CribMaze", package: "CribMazeEngine"),
                .product(name: "CribMazeBots", package: "CribMazeEngine"),
                .product(name: "GameRecord", package: "CribMazeEngine"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6), .unsafeFlags(["-warnings-as-errors"])]
        )
    ]
)
