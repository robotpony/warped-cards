// maze.json (engine.md › Config › maze.json): every number the maze's board, plays, jokers,
// hazards, stirs, duels and bots use. Percents are whole numbers, so every build rounds the same.
import CribbageKit

public struct MazeConfig: Codable, Sendable, Equatable {
    public struct Board: Codable, Sendable, Equatable {
        /// The golden path's steps, and the grid's side: the smallest W with W × W × 100 ≥ length × sizePercent.
        public var length: Int, sizePercent: Int
        /// Carve again with a wider grid after this many tries with no cell exactly `length` from the start.
        public var widenEvery: Int
        public var doors: Int, doorBase: Int, doorStep: Int
        /// A variant's own steps plus the golden steps it skips is at least this.
        public var minLoop: Int
        /// A variant's span (golden steps skipped) lies in this range, and it stays this far from either end.
        public var variantSpan: [Int]
        public var pathMargin: Int
        /// A golden door's way round: its steps from roundMinPercent % of its span to its span plus
        /// roundMaxExtra, its door within roundNearPercent % of an even slot of the even spot.
        public var roundMinPercent: Int, roundMaxExtra: Int, roundNearPercent: Int
        /// A way round under freeRoundExtra steps longer than it skips gets a door of another suit,
        /// roundDoorPercent % as strong as the golden door, at least doorMinStrength.
        public var roundDoorPercent: Int, freeRoundExtra: Int, doorMinStrength: Int
        /// Shortcuts: how many, the steps they save, and the most golden steps they skip.
        public var shortcuts: Int, shortcutSave: [Int], shortcutSpanMax: Int
        /// Two variants stay this many path indexes apart.
        public var variantGap: Int
        /// Switches: how many, which part of the path their passages come from (percents of the
        /// path's cells), how near their wall is, how many walls are tried, and how much of the
        /// golden path every mix of settings must keep (percent of `length`).
        public var switches: Int, switchFromPercent: Int, switchToPercent: Int, switchNear: Int, switchWallsTried: Int, switchKeepPercent: Int
        /// One star for every this many golden steps, rounded half up.
        public var starsPerSteps: Int
    }
    public struct Close: Codable, Sendable, Equatable {
        /// A closed door's strength is the play's steps × mulPercent / 100, rounded half up, at least `min`.
        public var mulPercent: Int, min: Int, perRound: Int
        /// `any`: anywhere on the board.
        public var `where`: String
    }
    public struct Cost: Codable, Sendable, Equatable { public var suitedDoorExtra: Int }
    public struct Jokers: Codable, Sendable, Equatable {
        public var targetRange: Int, bombPower: Int
        public var starOdds: Weights
    }
    public struct Range2: Codable, Sendable, Equatable { public var pass: [Int], land: [Int] }
    public struct Hazards: Codable, Sendable, Equatable { public var fire: Range2, mine: Range2 }
    public struct Plot: Codable, Sendable, Equatable {
        public var on: Bool
        public var openings: Weights
        /// A shift opens a wall beside the player whose way round is this many steps or fewer.
        public var shiftMaxRound: Int
        /// A star falls at this index of the player's way (0 is the first cell ahead), or its last cell.
        public var starAhead: Int
        /// A star opening needs a way longer than this many cells.
        public var starMinWay: Int
    }
    public struct Duel: Codable, Sendable, Equatable {
        public var landing: Bool, oncePerPairPerRound: Bool
        public var peg: PegScoring
    }
    public struct Timing: Codable, Sendable, Equatable {
        public var stepMs: Int, walkDelayMs: Int, hazardHoldMs: Int, hazardLandHoldMs: Int, botPegMs: Int
    }
    public var version: Int
    public var board: Board
    public var turn: Turn
    public struct Turn: Codable, Sendable, Equatable { public var jokersPerTurn: Int }
    public var close: Close
    public var cost: Cost
    public var jokers: Jokers
    public var hazards: Hazards
    public var plot: Plot
    public var duel: Duel
    public var timing: Timing

    /// The checks on load.
    public func validate(known: [String]) throws {
        func fail(_ s: String) throws -> Never { throw ConfigError(description: "maze.json: \(s)") }
        let b = board
        if b.length < 20 { try fail("board.length must be 20 or more") }
        if b.sizePercent < 100 { try fail("board.sizePercent must be 100 or more") }
        if b.widenEvery < 1 { try fail("board.widenEvery must be 1 or more") }
        for (name, r) in [("variantSpan", b.variantSpan), ("shortcutSave", b.shortcutSave)] where r.count != 2 || r[0] > r[1] {
            try fail("board.\(name) is [min, max], min no more than max")
        }
        if b.switches > 8 { try fail("board.switches is at most 8 (A to H)") }
        if b.starsPerSteps < 1 { try fail("board.starsPerSteps must be 1 or more") }
        if close.min < 1 || close.perRound < 0 || close.where != "any" { try fail("close: min 1 or more, perRound 0 or more, where any") }
        for (k, w) in jokers.starOdds.entries {
            if w < 1 { try fail("jokers.starOdds: weight for \(k) must be a positive integer") }
            if !known.contains(k) { try fail("jokers.starOdds names unknown \(k)") }
        }
        for (k, w) in plot.openings.entries where w < 1 || !["fade", "star", "shift"].contains(k) { try fail("plot.openings: \(k) must be fade, star or shift, with a positive weight") }
        for (name, r) in [("fire.pass", hazards.fire.pass), ("fire.land", hazards.fire.land), ("mine.pass", hazards.mine.pass), ("mine.land", hazards.mine.land)]
        where r.count != 2 || r[0] > r[1] || r[0] < 0 { try fail("hazards.\(name) is [min, max]") }
    }
}
