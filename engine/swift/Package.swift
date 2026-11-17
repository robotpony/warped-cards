// swift-tools-version: 6.2
// Crib Maze engine: rules, bots and the simulator, with no UI.
// Design: ../../ARCHITECTURE.md. Rules: ../../cribbage/minigames/engine.md.
import PackageDescription

let strict: [SwiftSetting] = [.unsafeFlags(["-warnings-as-errors"])]

let package = Package(
    name: "CribMazeEngine",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "GameKit", targets: ["GameKit"]),
        .library(name: "CardKit", targets: ["CardKit"]),
        .library(name: "CribbageKit", targets: ["CribbageKit"]),
        .library(name: "CribMaze", targets: ["CribMaze"]),
        .library(name: "CribMazeBots", targets: ["CribMazeBots"]),
        .library(name: "GameRecord", targets: ["GameRecord"]),
        .executable(name: "cribmaze-sim", targets: ["cribmaze-sim"]),
    ],
    targets: [
        .target(name: "GameKit", swiftSettings: strict),
        .target(name: "CardKit", swiftSettings: strict),
        .target(name: "CribbageKit", dependencies: ["CardKit"], swiftSettings: strict),
        .target(name: "CribMaze", dependencies: ["GameKit", "CardKit", "CribbageKit"], swiftSettings: strict),
        .target(name: "CribMazeBots", dependencies: ["CribMaze"], swiftSettings: strict),
        .target(name: "GameRecord", dependencies: ["GameKit"], swiftSettings: strict),
        .executableTarget(name: "cribmaze-sim", dependencies: ["CribMaze", "CribMazeBots", "GameRecord"], swiftSettings: strict),
        .testTarget(name: "GameKitTests", dependencies: ["GameKit"]),
        .testTarget(name: "GameRecordTests", dependencies: ["GameRecord", "GameKit"]),
        .testTarget(name: "CribbageKitTests", dependencies: ["CribbageKit"]),
        .testTarget(name: "CribMazeTests", dependencies: ["CribMaze", "CribMazeBots", "GameRecord"]),
    ]
)
