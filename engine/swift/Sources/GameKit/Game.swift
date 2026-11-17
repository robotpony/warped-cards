// The game protocol every game implements, the step it produces, and the run that keeps them in
// order (ARCHITECTURE.md › Core protocol, GameRecord › Interface).

public typealias PlayerID = Int

/// Who sits at a seat: a person or a bot, and the bot's level.
public struct PlayerSeat: Codable, Sendable, Equatable {
    public let seat: PlayerID
    public let kind: String   // "human" or "bot"
    public let level: String?
    public init(seat: PlayerID, kind: String, level: String? = nil) { self.seat = seat; self.kind = kind; self.level = level }
    public static func human(_ seat: PlayerID) -> PlayerSeat { PlayerSeat(seat: seat, kind: "human") }
    public static func bot(_ seat: PlayerID, level: String) -> PlayerSeat { PlayerSeat(seat: seat, kind: "bot", level: level) }
}

/// A game's rules: how it starts and how an action changes it. All randomness comes from the dice
/// passed in; nothing reads a clock.
public protocol GameRules {
    associatedtype Config: Codable & Sendable   // rules options, tuning values
    associatedtype State: Sendable              // everything, hidden cards included
    associatedtype Action: Codable & Sendable   // a choice by a player, or the session
    associatedtype Event: Codable & Sendable    // something that happened
    associatedtype Result: Codable & Sendable   // how a finished game came out

    static var gameID: String { get }           // "crib-maze"
    static var rulesVersion: String { get }     // "match-r24"
    /// The spec version this build implements (PORTING.md › Versions): `specVersion` in spec.json.
    static var specVersion: Int { get }

    static func start(_ config: Config, players: [PlayerSeat], dice: inout Dice) -> (State, [Event])
    static func apply(_ action: Action, by player: PlayerID?, to state: inout State, dice: inout Dice) throws -> [Event]
    /// The hand (or round, or stage) the game is in, from 1; nil for a game without hands.
    static func hand(of state: State) -> Int?
    /// The result once the game is over; nil while it's being played.
    static func result(of state: State) -> Result?
}

/// A step: one action and everything it caused. Records and the presenter consume steps.
public struct Step<G: GameRules>: Codable, Sendable {
    public let seq: Int
    /// The hand the game is in after this step, so a hand's steps group together.
    public let hand: Int?
    public let clockMs: Int
    public let player: PlayerID?
    public let action: G.Action?   // nil for the opening step
    public let rolls: [Roll]       // every random draw, in order
    public let events: [G.Event]
    public init(seq: Int, hand: Int?, clockMs: Int, player: PlayerID?, action: G.Action?, rolls: [Roll], events: [G.Event]) {
        self.seq = seq; self.hand = hand; self.clockMs = clockMs; self.player = player; self.action = action; self.rolls = rolls; self.events = events
    }
}

/// A rule error: the app and bots must only send legal actions.
public struct IllegalAction: Error, CustomStringConvertible, Sendable {
    public let description: String
    public init(_ description: String) { self.description = description }
}

/// One game being played: its state and dice, stepping through actions. The app, the simulator and
/// the replayer all play through this, so they number steps and split rolls the same way.
public struct GameRun<G: GameRules>: Sendable {
    public let config: G.Config
    public let seed: UInt64
    public let players: [PlayerSeat]
    public private(set) var state: G.State
    public private(set) var dice: Dice
    public private(set) var seq = 1

    /// Starts a game and returns its opening step (seq 1). Pass scripted dice to replay rolls.
    public static func start(_ config: G.Config, seed: UInt64, players: [PlayerSeat], dice scripted: Dice? = nil, clockMs: Int = 0) -> (GameRun, Step<G>) {
        var dice = scripted ?? Dice(seed: seed)
        let (state, events) = G.start(config, players: players, dice: &dice)
        var run = GameRun(config: config, seed: seed, players: players, state: state, dice: dice)
        let step = Step<G>(seq: 1, hand: G.hand(of: state), clockMs: clockMs, player: nil, action: nil, rolls: run.dice.takeRolls(), events: events)
        return (run, step)
    }

    private init(config: G.Config, seed: UInt64, players: [PlayerSeat], state: G.State, dice: Dice) {
        self.config = config; self.seed = seed; self.players = players; self.state = state; self.dice = dice
    }

    /// Applies an action. On an illegal action nothing changes and the error is thrown.
    public mutating func send(_ action: G.Action, by player: PlayerID?, clockMs: Int) throws -> Step<G> {
        var s = state, d = dice
        _ = d.takeRolls()
        let events = try G.apply(action, by: player, to: &s, dice: &d)
        state = s; dice = d; seq += 1
        return Step<G>(seq: seq, hand: G.hand(of: s), clockMs: clockMs, player: player, action: action, rolls: dice.takeRolls(), events: events)
    }

    public var result: G.Result? { G.result(of: state) }
}

/// Versions and context for a record's first line (ARCHITECTURE.md › File format). The app or
/// simulator fills in what it knows; the record adds the rest.
public struct AppStamp: Codable, Sendable, Equatable {
    public var app: String           // "0.15.0", or "cribmaze-sim"
    public var build: Int?
    public var commit: String?
    public var platform: String?     // "macOS 26.6"
    public var install: String?      // a random ID made on first launch; nothing personal
    public init(app: String, build: Int? = nil, commit: String? = nil, platform: String? = nil, install: String? = nil) {
        self.app = app; self.build = build; self.commit = commit; self.platform = platform; self.install = install
    }
}

/// A game's header: everything needed to play it again, plus where and when it was played.
public struct GameHeader<G: GameRules>: Codable, Sendable {
    public var game: String
    public var rules: String
    /// The spec version the writer implemented; nil in records written before spec 2.
    public var specVersion: Int?
    public var stamp: AppStamp
    public var started: String       // wall time with its offset, ISO 8601
    /// The seed as decimal text: JSON numbers lose precision past 2^53.
    public var seed: String
    public var config: G.Config
    public var players: [PlayerSeat]

    public init(_ run: GameRun<G>, stamp: AppStamp, started: String) {
        game = G.gameID; rules = G.rulesVersion; specVersion = G.specVersion; self.stamp = stamp; self.started = started
        seed = String(run.seed); config = run.config; players = run.players
    }

    public var seedValue: UInt64? { UInt64(seed) }

    // Written flat: the stamp's fields (app, build, commit, platform, install) sit beside the rest.
    enum Keys: String, CodingKey { case game, rules, specVersion, started, seed, config, players }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        game = try c.decode(String.self, forKey: .game)
        rules = try c.decode(String.self, forKey: .rules)
        specVersion = try c.decodeIfPresent(Int.self, forKey: .specVersion)
        stamp = try AppStamp(from: decoder)
        started = try c.decode(String.self, forKey: .started)
        seed = try c.decode(String.self, forKey: .seed)
        config = try c.decode(G.Config.self, forKey: .config)
        players = try c.decode([PlayerSeat].self, forKey: .players)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(game, forKey: .game)
        try c.encode(rules, forKey: .rules)
        try c.encodeIfPresent(specVersion, forKey: .specVersion)
        try stamp.encode(to: encoder)
        try c.encode(started, forKey: .started)
        try c.encode(seed, forKey: .seed)
        try c.encode(config, forKey: .config)
        try c.encode(players, forKey: .players)
    }
}

/// Watches a game's steps: the hook GameRecord implements. The release app has none.
public protocol StepObserver<G>: AnyObject {
    associatedtype G: GameRules
    func gameStarted(_ header: GameHeader<G>)
    func record(_ step: Step<G>)
    func gameEnded(_ result: G.Result)
}
