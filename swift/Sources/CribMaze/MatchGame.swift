// A game of match turns (engine.md › The game, match rules r23). The deck lasts the game: cards a
// joker makes join it, and burned cards leave it. Power jokers carry over from turn to turn, and a
// turn's prize joins them. No clock, no files, no randomness of its own.
import CardKit
import GameKit

/// A deck that lasts the game: what's in it now, and what's been burned out of it.
public struct GameDeck: Codable, Sendable, Equatable {
    /// Every card in the deck, in ID order: standard cards, then made cards.
    public private(set) var cards: [Card]
    /// Cards burned out of the deck, in the order they were burned.
    public private(set) var burned: [Card] = []

    public init(cards: [Card]) { self.cards = cards.sorted { $0.id < $1.id } }
    public static var standard: GameDeck { GameDeck(cards: (0..<52).map { Card(standard: $0) }) }

    public var count: Int { cards.count }
    public var made: [Card] { cards.filter { $0.kind == .made } }

    /// Adds made cards and removes burned ones, after a turn.
    public mutating func apply(made: [Card], burned gone: [Card]) {
        let goneIDs = Set(gone.map(\.id))
        cards = (cards + made).filter { !goneIDs.contains($0.id) }.sorted { $0.id < $1.id }
        burned += gone
    }
}

/// One finished turn of a game.
public struct TurnResult: Codable, Sendable, Equatable {
    public let turn: Int
    public let dealer: Bool
    public let steps: Int
    public let best: Int?
    /// The prize tier and the power joker it won, which joins the player's power jokers.
    public let tier: String?
    public let prize: String?
    /// Cards made into the deck and burned out of it this turn (a card made and burned in the
    /// same turn is in both).
    public let made: [CardRef]
    public let burned: [CardRef]
    public let deckSize: Int
}

public struct MatchGame: Codable, Sendable, Equatable {
    public let seed: UInt64
    public let turns: Int
    /// Whether everyone is dealt from one shared deck (rules.json deck.shared).
    public let shared: Bool
    /// Whether the player deals the first turn; the deal then alternates.
    public let firstDealer: Bool
    /// The shared deck, or the player's own.
    public private(set) var deck: GameDeck
    /// The bot's own deck, when decks aren't shared. Bots don't play grid turns yet, so it stays
    /// a standard deck.
    public private(set) var botDeck: GameDeck?
    /// The player's power jokers, carried from turn to turn.
    public private(set) var tray: [String: Int]
    public private(set) var results: [TurnResult] = []

    public init(config: Config, seed: UInt64, firstDealer: Bool = true) {
        self.seed = seed
        turns = config.rules.game?.turns ?? 1
        shared = config.rules.deck?.shared ?? true
        self.firstDealer = firstDealer
        deck = .standard
        botDeck = shared ? nil : .standard
        tray = config.rules.specials.start
    }

    /// The turn being played or to play next, from 1.
    public var turn: Int { results.count + 1 }
    public var over: Bool { results.count >= turns }
    public var steps: Int { results.reduce(0) { $0 + $1.steps } }
    /// Whether the player deals this turn.
    public var dealer: Bool { firstDealer == results.count.isMultiple(of: 2) }

    /// This turn's seed: the game's seed for turn 1, so a one-turn game plays as a standalone turn
    /// from the same seed; after that, FNV-1a 64 of "<seed>/turn<n>".
    public var turnSeed: UInt64 { turn == 1 ? seed : fnv1a64("\(seed)/turn\(turn)") }

    /// This turn's deal, from the game's deck (and the bot's own, when decks aren't shared).
    public func deal() -> Dealt { Deal.deal(seed: turnSeed, deck: deck.cards, botDeck: botDeck?.cards) }

    /// The setup for this turn after a deal.
    public func setup(dealt: Dealt, thrown: [Card], botThrown: [Card], warned: Bool = false) -> TurnSetup {
        Deal.setup(seed: turnSeed, dealer: dealer, dealt: dealt, thrown: thrown, botThrown: botThrown, tray: tray, warned: warned, deck: deck.cards)
    }

    /// The setup for this turn with no deal: the hand comes off the top of the game's deck, or is
    /// fixed (tests and scenarios; a fixed card the deck no longer holds is used as given).
    public func setup(fixedHand: [String]? = nil, fixedStarter: String? = nil, warned: Bool = false) -> TurnSetup {
        var s = TurnSetup(seed: turnSeed, dealer: dealer, tray: tray, warned: warned, fixedHand: fixedHand, fixedStarter: fixedStarter)
        s.deck = deck.cards
        return s
    }

    /// Ends this turn: made cards join the deck, burned cards leave it, the power jokers left over
    /// carry on and the prize's joins them. Bots don't play grid turns yet, so every change is the
    /// player's: into the shared deck, or into the player's own.
    @discardableResult
    public mutating func finish(_ t: MatchTurn, events: [MatchEvent]) -> TurnResult {
        precondition(t.state.over && !over)
        deck.apply(made: t.state.made, burned: t.state.burned)
        tray = t.state.tray
        var tier: String?, prize: String?
        for e in events { if case .prizeWon(let ti, _, _, let special) = e { tier = ti; prize = special } }
        if let p = prize { tray[p, default: 0] += 1 }
        let r = TurnResult(turn: turn, dealer: dealer, steps: t.state.steps, best: t.state.bestPoints, tier: tier, prize: prize,
                           made: t.state.made.map(CardRef.init), burned: t.state.burned.map(CardRef.init), deckSize: deck.count)
        results.append(r)
        return r
    }
}
