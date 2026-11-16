// Config files (engine.md › Config): rules.json, jokers.json, bots.json.
// Every number and table the rules use comes from here.
import CribbageKit
import Foundation

/// A weighted list, written in JSON as pairs ([["swapper", 60], ["bomb", 40]]) so its order is fixed.
public struct Weights: Codable, Sendable, Equatable {
    public var entries: [(String, Int)]
    public init(_ entries: [(String, Int)]) { self.entries = entries }
    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer(); var out: [(String, Int)] = []
        while !c.isAtEnd {
            var pair = try c.nestedUnkeyedContainer()
            out.append((try pair.decode(String.self), try pair.decode(Int.self)))
        }
        entries = out
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        for (k, w) in entries { var p = c.nestedUnkeyedContainer(); try p.encode(k); try p.encode(w) }
    }
    public static func == (a: Weights, b: Weights) -> Bool { a.entries.map(\.0) == b.entries.map(\.0) && a.entries.map(\.1) == b.entries.map(\.1) }
}

public struct RulesConfig: Codable, Sendable, Equatable {
    public struct ClearBonus: Codable, Sendable, Equatable { public var kind: String; public var amount: Int }
    public struct EdgePower: Codable, Sendable, Equatable {
        public var start: Int, step: Int, percentPerLevel: Int, combine: String, capPercent: Int
    }
    public struct Prize: Codable, Sendable, Equatable { public var rareAt: Int, epicAt: Int; public var special: Weights }
    public struct Match: Codable, Sendable, Equatable {
        public var maxSet: Int, flushMin: Int, timerSeconds: Int, cardBudget: Int, leftOverCost: Int
        /// The starter counts with every set, like the starter in a cribbage hand (match rules r16).
        /// Missing in older configs, which means no.
        public var starterJoins: Bool?
        /// Match rules r18, with `starterJoins`: flushes count like a classic hand (4 picked cards of
        /// one suit score a 4-card flush whatever the starter's suit), and the starter is optional (a
        /// set is counted with and without it, and the better score wins). Missing means no.
        public var handFlush: Bool?
        public var clearBonus: ClearBonus
        public var edgePower: EdgePower
        public var prize: Prize
    }
    public struct Specials: Codable, Sendable, Equatable {
        public var known: [String]
        public var start: [String: Int]
        public var bombShape: String
        /// The reach joker (r19): how many extra cards a set may pick, and for how many seconds,
        /// each a weighted list of [value, weight] pairs.
        public var reach: Reach?
    }
    public struct Reach: Codable, Sendable, Equatable {
        public var cards: [[Int]]
        public var seconds: [[Int]]
        public var cardsWeights: [(Int, Int)] { cards.map { ($0[0], $0[1]) } }
        public var secondsWeights: [(Int, Int)] { seconds.map { ($0[0], $0[1]) } }
    }
    public var version: Int
    public var rulesVersion: String
    public var scoring: Scoring
    public var match: Match
    public var specials: Specials
}

public struct JokersConfig: Codable, Sendable, Equatable {
    public struct Range: Codable, Sendable, Equatable { public var min: Int, max: Int }
    public struct Outcome: Codable, Sendable, Equatable {
        public var goes: String, tier: String
        public var makes: String?, special: String?, amount: Int?
    }
    public var version: Int
    public var perRound: Range
    public var kinds: Weights
    public var extras: [String]
    public var scoringRanks: [Int]
    public var outcomes: [String: Outcome]
    public var tables: [String: Weights]
    /// A made card's multiplier (r20): [percent, weight] pairs, and the cap on all of a set's made
    /// cards multiplied together. Missing means made cards carry no multiplier, as in r19.
    public var madeMultiplier: [[Int]]?
    public var madeCapPercent: Int?
    public var madeWeights: [(Int, Int)] { (madeMultiplier ?? []).map { ($0[0], $0[1]) } }
}

/// hints.json: what each discard principle is worth on the grid, as measured by
/// `cribmaze-sim principles`, and the least worth a principle needs to be shown.
public struct HintsConfig: Codable, Sendable, Equatable {
    public struct Discard: Codable, Sendable, Equatable {
        public var measured: String
        public var worth: Weights
        public var minWorth: Int
    }
    public var version: Int
    public var discard: Discard
}

public struct BotsConfig: Codable, Sendable, Equatable {
    public struct MatchLevel: Codable, Sendable, Equatable { public var id: String, search: String; public var depth: Int?; public var starts: Double? }
    public struct ClassicLevel: Codable, Sendable, Equatable { public var id: String, discard: String, peg: String }
    public var version: Int
    public var match: [MatchLevel]
    public var classic: [ClassicLevel]
}

public struct ConfigError: Error, CustomStringConvertible, Sendable {
    public let description: String
    public init(description: String) { self.description = description }
}

/// Everything a match turn reads.
public struct Config: Codable, Sendable, Equatable {
    public var rules: RulesConfig
    public var jokers: JokersConfig
    public var bots: BotsConfig
    public var hints: HintsConfig?

    public init(rules: RulesConfig, jokers: JokersConfig, bots: BotsConfig, hints: HintsConfig? = nil) throws {
        self.rules = rules; self.jokers = jokers; self.bots = bots; self.hints = hints
        try validate()
    }

    /// Loads rules.json, jokers.json and bots.json from a folder, and checks them.
    public static func load(from folder: URL) throws -> Config {
        let d = JSONDecoder()
        func read<T: Decodable>(_ name: String) throws -> T {
            let url = folder.appendingPathComponent(name)
            do { return try d.decode(T.self, from: Data(contentsOf: url)) } catch { throw ConfigError(description: "\(name): \(error)") }
        }
        // hints.json is optional: without it, no discard principle is shown.
        let hints: HintsConfig? = FileManager.default.fileExists(atPath: folder.appendingPathComponent("hints.json").path) ? try read("hints.json") : nil
        return try Config(rules: read("rules.json"), jokers: read("jokers.json"), bots: read("bots.json"), hints: hints)
    }

    /// The checks on load (engine.md › Config). A bad file fails loudly.
    public func validate() throws {
        func fail(_ s: String) throws -> Never { throw ConfigError(description: s) }
        func weights(_ w: Weights, _ name: String) throws {
            if w.entries.isEmpty { try fail("\(name): no entries") }
            for (k, v) in w.entries where v <= 0 { try fail("\(name): weight for \(k) must be a positive integer") }
        }
        let m = rules.match
        if m.maxSet < 2 { try fail("match.maxSet must be 2 or more") }
        if m.prize.epicAt < m.prize.rareAt { try fail("prize.epicAt must be at least rareAt") }
        try weights(m.prize.special, "prize.special")
        for (k, _) in m.prize.special.entries where !rules.specials.known.contains(k) { try fail("prize.special names unknown \(k)") }
        for pair in jokers.madeMultiplier ?? [] where pair.count != 2 || pair[0] < 100 || pair[1] < 1 { try fail("jokers.madeMultiplier: each entry is [percent of 100 or more, weight]") }
        if jokers.perRound.min > jokers.perRound.max { try fail("jokers.perRound: min is above max") }
        try weights(jokers.kinds, "jokers.kinds")
        let kinds = jokers.kinds.entries.map(\.0) + jokers.extras
        for k in kinds where jokers.tables[k] == nil { try fail("jokers: no table for \(k)") }
        for (k, t) in jokers.tables {
            try weights(t, "jokers.tables.\(k)")
            for (o, _) in t.entries where jokers.outcomes[o] == nil { try fail("jokers.tables.\(k) names unknown outcome \(o)") }
        }
        if rules.specials.known.contains("reach") {
            guard let reach = rules.specials.reach else { try fail("specials.reach is missing, but reach is a known special") }
            for (name, list) in [("cards", reach.cards), ("seconds", reach.seconds)] {
                if list.isEmpty { try fail("specials.reach.\(name): no entries") }
                for pair in list where pair.count != 2 || pair[0] < 1 || pair[1] < 1 { try fail("specials.reach.\(name): each entry is [value, weight], both 1 or more") }
            }
            if m.maxSet + (reach.cards.map { $0[0] }.max() ?? 0) > 6 { try fail("specials.reach.cards: maxSet plus the most extra cards must be 6 or less") }
        }
        if !["plus", "square"].contains(rules.specials.bombShape) { try fail("specials.bombShape must be plus or square") }
        if !["add", "each"].contains(m.edgePower.combine) { try fail("edgePower.combine must be add or each") }
        for l in bots.match where l.search == "traced" && (l.depth == nil || l.starts == nil) { try fail("bots.match.\(l.id): traced needs depth and starts") }
    }
}
