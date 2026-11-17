// A whole Crib Maze game as GameKit's GameRules (engine.md › The game), so it can be run, recorded
// and replayed one step at a time. A game is a sequence of hands; each hand is a deal (or fixed
// cards), then a match turn. Later hands add pegging and the maze here, as their rules settle.
//
// Each hand starts its dice again from the hand's seed (MatchGame.turnSeed), so a hand plays
// exactly as MatchGame and the simulator play it. No clock, no files, no randomness of its own.
import CardKit
import CribbageKit
import GameKit

public enum CribMazeGame: GameRules {
    public static let gameID = "crib-maze"
    public static var rulesVersion: String { MatchTurn.rulesVersion }

    /// The config files, plus who deals first. Encoded flat, so a record's config reads like the files.
    public struct Config: Codable, Sendable, Equatable {
        public var files: CribMaze.Config
        public var firstDealer: Bool
        public init(_ files: CribMaze.Config, firstDealer: Bool = true) { self.files = files; self.firstDealer = firstDealer }

        enum Keys: String, CodingKey { case firstDealer }
        public init(from decoder: Decoder) throws {
            files = try CribMaze.Config(from: decoder)
            try files.validate()
            firstDealer = try decoder.container(keyedBy: Keys.self).decode(Bool.self, forKey: .firstDealer)
        }
        public func encode(to encoder: Encoder) throws {
            try files.encode(to: encoder)
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(firstDealer, forKey: .firstDealer)
        }
    }

    /// How a hand is set up: the app's settings at the time, so a record replays them.
    public struct HandOptions: Codable, Sendable, Equatable {
        /// Deal 6 and throw 2 to the crib first. Off, or with fixed cards, the hand comes straight
        /// off the deck.
        public var deal: Bool
        /// Fixed cards (tests, the beta's Strong hand): a hand of 4 and a starter.
        public var fixedHand: [String]?
        public var fixedStarter: String?
        /// This hand's card budget and timer, in place of rules.json's (0 is the whole stock, and off).
        public var cardBudget: Int?
        public var timerSeconds: Int?
        /// Whether the player has seen the left-over warning.
        public var warned: Bool
        public init(deal: Bool = true, fixedHand: [String]? = nil, fixedStarter: String? = nil, cardBudget: Int? = nil, timerSeconds: Int? = nil, warned: Bool = false) {
            self.deal = deal; self.fixedHand = fixedHand; self.fixedStarter = fixedStarter
            self.cardBudget = cardBudget; self.timerSeconds = timerSeconds; self.warned = warned
        }
    }

    public enum Stage: Sendable {
        /// Before the first hand.
        case ready
        /// The deal: your 6, the bot's 6, the starter, and the bot's throw (its best classic keep).
        case dealing(Dealt, botThrown: [Card], options: HandOptions)
        case playing(MatchTurn)
        /// A hand is over and another is to come.
        case handOver(MatchTurn)
        case over(MatchTurn)
    }

    public struct State: Sendable {
        public let config: Config
        public internal(set) var game: MatchGame
        public internal(set) var stage: Stage = .ready
        /// The hand being played, or the last one played; 0 before the first.
        public internal(set) var hand = 0
        /// The match turn's events so far, for its result.
        var turnEvents: [MatchEvent] = []

        /// The match turn being played or just played.
        public var turn: MatchTurn? {
            switch stage {
            case .playing(let t), .handOver(let t), .over(let t): t
            case .ready, .dealing: nil
            }
        }
        public var over: Bool { if case .over = stage { true } else { false } }
    }

    public enum Action: Sendable, Equatable {
        /// Starts the next hand (the app sends it, with its settings).
        case startHand(HandOptions)
        /// The player's 2 cards for the crib.
        case discard(thrown: [CardRef])
        case match(MatchAction)
    }

    public enum Event: Sendable, Equatable {
        case gameStart(hands: Int, shared: Bool, firstDealer: Bool, deckSize: Int)
        case handStart(hand: Int, seed: String, dealer: Bool, deckSize: Int, options: HandOptions)
        case deal(player: [CardRef], bot: [CardRef], starter: CardRef)
        case discard(kept: [CardRef], thrown: [CardRef], botKept: [CardRef], botThrown: [CardRef])
        case match(MatchEvent)
        case handEnd(result: TurnResult)
        case gameEnd(hands: Int, steps: Int)
    }

    public struct Result: Codable, Sendable, Equatable {
        public let hands: [TurnResult]
        public let steps: Int
    }

    // MARK: Rules

    public static func start(_ config: Config, players: [PlayerSeat], dice: inout Dice) -> (State, [Event]) {
        let g = MatchGame(config: config.files, seed: dice.seed, firstDealer: config.firstDealer)
        return (State(config: config, game: g), [.gameStart(hands: g.turns, shared: g.shared, firstDealer: g.firstDealer, deckSize: g.deck.count)])
    }

    public static func apply(_ action: Action, by player: PlayerID?, to state: inout State, dice: inout Dice) throws -> [Event] {
        switch (action, state.stage) {
        case (.startHand(let o), .ready), (.startHand(let o), .handOver):
            let g = state.game
            state.hand = g.turn
            dice.reseed(g.turnSeed)
            var ev: [Event] = [.handStart(hand: g.turn, seed: String(g.turnSeed), dealer: g.dealer, deckSize: g.deck.count, options: o)]
            if o.deal && o.fixedHand == nil {
                let dealt = Deal.deal(dice: &dice, deck: g.deck.cards, botDeck: g.botDeck?.cards)
                let botThrown = Deal.classicKeep(dealt.bot, scoring: state.config.files.rules.scoring).thrown
                state.stage = .dealing(dealt, botThrown: botThrown, options: o)
                ev.append(.deal(player: dealt.player.map(CardRef.init), bot: dealt.bot.map(CardRef.init), starter: CardRef(dealt.starter)))
            } else {
                ev += startTurn(g.setup(fixedHand: o.fixedHand, fixedStarter: o.fixedStarter, warned: o.warned), o, &state, &dice)
            }
            return ev
        case (.discard(let thrown), .dealing(let dealt, let botThrown, let o)):
            let ids = thrown.map(\.id)
            let cards = ids.compactMap { id in dealt.player.first { $0.id == id } }
            guard cards.count == 2, Set(ids).count == 2 else { throw IllegalAction("throw 2 of your 6 cards to the crib") }
            let keep = dealt.player.filter { !ids.contains($0.id) }
            let botKeep = dealt.bot.filter { c in !botThrown.contains { $0.id == c.id } }
            var ev: [Event] = [.discard(kept: keep.map(CardRef.init), thrown: cards.map(CardRef.init), botKept: botKeep.map(CardRef.init), botThrown: botThrown.map(CardRef.init))]
            ev += startTurn(state.game.setup(dealt: dealt, thrown: cards, botThrown: botThrown, warned: o.warned), o, &state, &dice)
            return ev
        case (.match(let a), .playing(var t)):
            t.dice = dice
            let e = try t.apply(a)
            dice = t.dice
            return afterTurn(t, e, &state)
        case (.startHand, _): throw IllegalAction(state.over ? "the game is over" : "a hand is being played")
        case (.discard, _): throw IllegalAction("there's no deal to throw from")
        case (.match, _): throw IllegalAction("no match turn is being played")
        }
    }

    public static func hand(of state: State) -> Int? { state.hand == 0 ? nil : state.hand }

    public static func result(of state: State) -> Result? {
        state.over ? Result(hands: state.game.results, steps: state.game.steps) : nil
    }

    /// Starts the hand's match turn on the game's dice, with the hand's budget and timer.
    private static func startTurn(_ setup: TurnSetup, _ o: HandOptions, _ state: inout State, _ dice: inout Dice) -> [Event] {
        var c = state.config.files
        if let b = o.cardBudget { c.rules.match.cardBudget = b }
        if let s = o.timerSeconds { c.rules.match.timerSeconds = s }
        state.turnEvents = []
        let (t, e) = MatchTurn.start(config: c, setup: setup, dice: dice)
        dice = t.dice
        return afterTurn(t, e, &state)
    }

    /// Keeps the turn's events, and when it's over finishes the hand, and the game after the last.
    private static func afterTurn(_ t: MatchTurn, _ e: [MatchEvent], _ state: inout State) -> [Event] {
        state.turnEvents += e
        var ev = e.map(Event.match)
        guard t.state.over else { state.stage = .playing(t); return ev }
        let r = state.game.finish(t, events: state.turnEvents)
        ev.append(.handEnd(result: r))
        if state.game.over {
            state.stage = .over(t)
            ev.append(.gameEnd(hands: state.game.results.count, steps: state.game.steps))
        } else {
            state.stage = .handOver(t)
        }
        return ev
    }
}

extension CribMazeGame.Event {
    /// The match turn's own event, if this is one.
    public var matchEvent: MatchEvent? { if case .match(let e) = self { e } else { nil } }
}

// MARK: - Coding

// Actions and events are written flat: the match turn's own (`{"trace": …}`, `{"turnStart": …}`)
// sit beside the game's (`{"startHand": …}`, `{"handEnd": …}`), so records read like the mocks' logs.

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

private func firstKey(_ decoder: Decoder) throws -> String? {
    try decoder.container(keyedBy: AnyKey.self).allKeys.first?.stringValue
}

extension CribMazeGame.Action: Codable {
    private enum Own: Codable { case startHand(options: CribMazeGame.HandOptions), discard(thrown: [CardRef]) }

    public init(from decoder: Decoder) throws {
        switch try firstKey(decoder) {
        case "startHand", "discard":
            switch try Own(from: decoder) {
            case .startHand(let o): self = .startHand(o)
            case .discard(let t): self = .discard(thrown: t)
            }
        default: self = .match(try MatchAction(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .startHand(let o): try Own.startHand(options: o).encode(to: encoder)
        case .discard(let t): try Own.discard(thrown: t).encode(to: encoder)
        case .match(let a): try a.encode(to: encoder)
        }
    }
}

extension CribMazeGame.Event: Codable {
    private enum Own: Codable {
        case gameStart(hands: Int, shared: Bool, firstDealer: Bool, deckSize: Int)
        case handStart(hand: Int, seed: String, dealer: Bool, deckSize: Int, options: CribMazeGame.HandOptions)
        case deal(player: [CardRef], bot: [CardRef], starter: CardRef)
        case discard(kept: [CardRef], thrown: [CardRef], botKept: [CardRef], botThrown: [CardRef])
        case handEnd(result: TurnResult)
        case gameEnd(hands: Int, steps: Int)
    }
    private static let ownKeys: Set<String> = ["gameStart", "handStart", "deal", "discard", "handEnd", "gameEnd"]

    public init(from decoder: Decoder) throws {
        guard let k = try firstKey(decoder), Self.ownKeys.contains(k) else { self = .match(try MatchEvent(from: decoder)); return }
        switch try Own(from: decoder) {
        case .gameStart(let h, let s, let f, let d): self = .gameStart(hands: h, shared: s, firstDealer: f, deckSize: d)
        case .handStart(let h, let s, let d, let n, let o): self = .handStart(hand: h, seed: s, dealer: d, deckSize: n, options: o)
        case .deal(let p, let b, let s): self = .deal(player: p, bot: b, starter: s)
        case .discard(let k, let t, let bk, let bt): self = .discard(kept: k, thrown: t, botKept: bk, botThrown: bt)
        case .handEnd(let r): self = .handEnd(result: r)
        case .gameEnd(let h, let s): self = .gameEnd(hands: h, steps: s)
        }
    }

    public func encode(to encoder: Encoder) throws {
        let own: Own
        switch self {
        case .match(let e): try e.encode(to: encoder); return
        case .gameStart(let h, let s, let f, let d): own = .gameStart(hands: h, shared: s, firstDealer: f, deckSize: d)
        case .handStart(let h, let s, let d, let n, let o): own = .handStart(hand: h, seed: s, dealer: d, deckSize: n, options: o)
        case .deal(let p, let b, let s): own = .deal(player: p, bot: b, starter: s)
        case .discard(let k, let t, let bk, let bt): own = .discard(kept: k, thrown: t, botKept: bk, botThrown: bt)
        case .handEnd(let r): own = .handEnd(result: r)
        case .gameEnd(let h, let s): own = .gameEnd(hands: h, steps: s)
        }
        try own.encode(to: encoder)
    }
}
