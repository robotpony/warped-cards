// A whole Crib RPG game as GameKit's GameRules (engine.md › The game), so it can be run, recorded
// and replayed one step at a time. A game is a sequence of hands; each hand is a deal (or fixed
// cards), then a match turn. In a game around the maze (Config.mazeGame, maze.md › The game around
// the maze), each bot also plays a grid turn of its own, and hands go on until a token reaches the
// goal, at most game.maxHands.
//
// Each hand starts its dice again from the hand's seed (MatchGame.turnSeed), so a hand plays
// exactly as MatchGame and the simulator play it. No clock, no files, no randomness of its own.
import CardKit
import CribbageKit
import GameKit

public enum CribMazeGame: GameRules {
    public static let gameID = "crib-maze"
    public static var rulesVersion: String { MatchTurn.rulesVersion }
    /// Keep in step with `specVersion` in cribbage/minigames/spec.json (spec.test.js checks it).
    public static let specVersion = 16

    /// The config files, plus who deals first. Encoded flat, so a record's config reads like the files.
    public struct Config: Codable, Sendable, Equatable {
        public var files: CribMaze.Config
        public var firstDealer: Bool
        /// A game around the maze (maze.md › The game around the maze): bots play grid turns of
        /// their own, and hands go on until a token reaches the goal, at most `game.maxHands`. Off,
        /// the game is `game.turns` hands and only the player's grid turn is played. Written to a
        /// record's header only when on.
        public var mazeGame: Bool
        public init(_ files: CribMaze.Config, firstDealer: Bool = true, mazeGame: Bool = false) {
            self.files = files; self.firstDealer = firstDealer; self.mazeGame = mazeGame
        }

        enum Keys: String, CodingKey { case firstDealer, mazeGame }
        public init(from decoder: Decoder) throws {
            files = try CribMaze.Config(from: decoder)
            try files.validate()
            let c = try decoder.container(keyedBy: Keys.self)
            firstDealer = try c.decode(Bool.self, forKey: .firstDealer)
            mazeGame = try c.decodeIfPresent(Bool.self, forKey: .mazeGame) ?? false
        }
        public func encode(to encoder: Encoder) throws {
            try files.encode(to: encoder)
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(firstDealer, forKey: .firstDealer)
            if mazeGame { try c.encode(true, forKey: .mazeGame) }
        }
    }

    /// A bot's own grid turn this hand, played off screen (maze.md › The game around the maze).
    public struct BotTurn: Sendable {
        public let seat: Int
        public let turn: MatchTurn
        public let events: [MatchEvent]
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
        /// The hand's maze phase, after its last grid turn (a game around the maze).
        case maze(MatchTurn)
        /// A hand is over and another is to come.
        case handOver(MatchTurn)
        case over(MatchTurn)
    }

    public struct State: Sendable {
        public let config: Config
        /// Who sits where: seat 0 is the player (a person, or a bot in the simulator), the rest bots.
        public let players: [PlayerSeat]
        public internal(set) var game: MatchGame
        /// This hand's bot grid turns, in seat order (a game around the maze).
        public internal(set) var botTurns: [BotTurn] = []
        /// Each seat's 4 kept cards this hand, in the order laid along the hand row.
        public internal(set) var kept: [[Card]] = []
        /// Each seat's plays this hand, once the grid turns are over (a game around the maze).
        public internal(set) var plays: [[MazePlay]] = []
        /// The next play's ID: plays are numbered from 1 through the game.
        var nextPlayID = 1
        /// The maze, in a game around the maze with `maze.json`; built when the game starts.
        public internal(set) var maze: Maze?
        /// The hand's result, kept from the end of its grid turn until its maze phase ends.
        var handResult: TurnResult?
        public internal(set) var stage: Stage = .ready
        /// The hand being played, or the last one played; 0 before the first.
        public internal(set) var hand = 0
        /// The match turn's events so far, for its result.
        var turnEvents: [MatchEvent] = []

        /// How many seats play (1 to 3). Only a game around the maze gives the bots turns of their own.
        public var seatCount: Int { config.mazeGame ? players.count : 1 }

        /// The match turn being played or just played.
        public var turn: MatchTurn? {
            switch stage {
            case .playing(let t), .maze(let t), .handOver(let t), .over(let t): t
            case .ready, .dealing: nil
            }
        }
        public var over: Bool { if case .over = stage { true } else { false } }
    }

    public enum Action: Sendable, Equatable {
        /// Starts the next hand (the app sends it, with its settings).
        case startHand(HandOptions)
        /// The player's 2 cards for the crib, and (r24) the 4 they keep, in the order they sorted
        /// them, which is the order they lie along the hand row. Without `kept`, the dealt order.
        case discard(thrown: [CardRef], kept: [CardRef]? = nil)
        case match(MatchAction)
        /// A maze action, by the seat whose turn it is.
        case maze(MazeAction)
    }

    public enum Event: Sendable, Equatable {
        case gameStart(hands: Int, shared: Bool, firstDealer: Bool, deckSize: Int)
        case handStart(hand: Int, seed: String, dealer: Bool, deckSize: Int, options: HandOptions)
        case deal(player: [CardRef], bot: [CardRef], starter: CardRef)
        case discard(kept: [CardRef], thrown: [CardRef], botKept: [CardRef], botThrown: [CardRef])
        case match(MatchEvent)
        case handEnd(result: TurnResult)
        case gameEnd(hands: Int, steps: Int)
        /// A bot's own grid turn, played off screen before the player's: its result only.
        case botTurn(seat: Int, steps: Int, best: Int?, tier: String?, prize: String?, made: [CardRef], burned: [CardRef], tray: [String: Int])
        /// A seat's plays for the maze, biggest first, and the 4 cards it kept, once every grid turn is over.
        case handPlays(seat: Int, plays: [MazePlay], kept: [CardRef])
        case maze(MazeEvent)
    }

    public struct Result: Codable, Sendable, Equatable {
        public let hands: [TurnResult]
        public let steps: Int
    }

    // MARK: Rules

    public static func start(_ config: Config, players: [PlayerSeat], dice: inout Dice) -> (State, [Event]) {
        let bots = config.mazeGame ? max(0, players.count - 1) : 0
        let g = MatchGame(config: config.files, seed: dice.seed, firstDealer: config.firstDealer, bots: bots,
                          maxHands: config.mazeGame ? (config.files.rules.game?.maxHands ?? 15) : nil)
        var state = State(config: config, players: players, game: g)
        var ev: [Event] = [.gameStart(hands: g.turns, shared: g.shared, firstDealer: g.firstDealer, deckSize: g.deck.count)]
        if config.mazeGame, let mc = config.files.maze {
            let m = Maze(config: mc, board: Maze.build(mc, seed: dice.seed), seats: Array(players.prefix(max(1, state.seatCount))), dice: dice)
            state.maze = m
            ev.append(.maze(m.builtEvent))
        }
        return (state, ev)
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
                let setup = g.setup(fixedHand: o.fixedHand, fixedStarter: o.fixedStarter, warned: o.warned)
                state.botTurns = []
                ev += startTurn(setup, o, &state, &dice)
                if let t = state.turn { state.kept = [Board.hand.compactMap { t.state.cells[$0] }] }
            }
            return ev
        case (.discard(let thrown, let kept), .dealing(let dealt, let botThrown, let o)):
            let ids = thrown.map(\.id)
            let cards = ids.compactMap { id in dealt.player.first { $0.id == id } }
            guard cards.count == 2, Set(ids).count == 2 else { throw IllegalAction("throw 2 of your 6 cards to the crib") }
            var keep = dealt.player.filter { !ids.contains($0.id) }
            if let k = kept {
                let order = k.compactMap { r in keep.first { $0.id == r.id } }
                guard order.count == 4, Set(order.map(\.id)).count == 4 else { throw IllegalAction("kept must be the other 4 of your 6, each once") }
                keep = order
            }
            let botKeep = dealt.bot.filter { c in !botThrown.contains { $0.id == c.id } }
            var ev: [Event] = [.discard(kept: keep.map(CardRef.init), thrown: cards.map(CardRef.init), botKept: botKeep.map(CardRef.init), botThrown: botThrown.map(CardRef.init))]
            state.kept = [keep]
            state.botTurns = []
            if state.seatCount >= 2 {
                // Bots play their own grid turns first, each from its own seed, then the player's
                // turn starts again from the hand's.
                let laid = botKeep.sorted { $0.id < $1.id }
                state.kept.append(laid)
                let setup = state.game.botSetup(seat: 1, dealt: dealt, thrown: cards, botThrown: botThrown, botKept: laid)
                let b = botGridTurn(seat: 1, setup: setup, state: state, dice: &dice)
                state.botTurns.append(b)
                ev.append(botTurnEvent(b))
                dice.reseed(state.game.turnSeed)
            }
            ev += startTurn(state.game.setup(dealt: dealt, thrown: cards, botThrown: botThrown, kept: keep, warned: o.warned), o, &state, &dice)
            return ev
        case (.match(let a), .playing(var t)):
            t.dice = dice
            let e = try t.apply(a)
            dice = t.dice
            return afterTurn(t, e, &state, &dice)
        case (.startHand, _): throw IllegalAction(state.over ? "the game is over" : "a hand is being played")
        case (.discard, _): throw IllegalAction("there's no deal to throw from")
        case (.maze(let a), .maze(let t)):
            guard var m = state.maze else { throw IllegalAction("there's no maze") }
            m.dice = dice
            var ev = try m.apply(a, by: player).map(Event.maze)
            dice = m.dice
            state.maze = m
            ev += afterMaze(t, &state)
            return ev
        case (.match, _): throw IllegalAction("no match turn is being played")
        case (.maze, _): throw IllegalAction("the maze isn't being played")
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
        return afterTurn(t, e, &state, &dice)
    }

    /// Keeps the turn's events, and when it's over finishes the hand, and the game after the last.
    private static func afterTurn(_ t: MatchTurn, _ e: [MatchEvent], _ state: inout State, _ dice: inout Dice) -> [Event] {
        state.turnEvents += e
        var ev = e.map(Event.match)
        guard t.state.over else { state.stage = .playing(t); return ev }
        if state.config.mazeGame {
            ev += finishGrid(t, &state, &dice)
            return ev
        }
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

// MARK: - A game around the maze

extension CribMazeGame {
    /// A bot plays its own grid turn to the end, off screen, with `MatchBot` at its seat's level
    /// (an unknown level plays as `medium`). The turn draws from the game's dice, started again
    /// from the bot's seed; the bot's own choices draw from its own dice, from the same seed. A
    /// reach or timed key ends after `bots.reachActions` of its actions.
    static func botGridTurn(seat: Int, setup: TurnSetup, state: State, dice: inout Dice) -> BotTurn {
        let files = state.config.files
        let level = state.players.first { $0.seat == seat }?.level ?? "medium"
        let bot = MatchBot(config: files, id: level, seat: seat) ?? MatchBot(config: files, id: "medium", seat: seat) ?? MatchBot(level: files.bots.match[0], seat: seat)
        dice.reseed(setup.seed)
        var (t, ev) = MatchTurn.start(config: files, setup: setup, dice: dice)
        var own = Dice(seed: setup.seed)
        var acted = 0, ends: [Int: Int] = [:]
        let every = files.bots.reachActions ?? 5
        while !t.state.over {
            let a = bot.choose(t, dice: &own)
            // Bots send only legal actions; should one not be, the turn ends.
            let e = (try? t.apply(a)) ?? ((try? t.apply(.endTurn)) ?? [])
            ev += e; acted += 1
            for x in e { if let (id, _) = x.startedReach { ends[id] = acted + every } }
            for (id, end) in ends.sorted(by: { $0.key < $1.key }) where end <= acted && !t.state.over {
                ends[id] = nil
                ev += (try? t.apply(.reachOver(id: id))) ?? []
            }
        }
        dice = t.dice
        return BotTurn(seat: seat, turn: t, events: ev)
    }

    static func botTurnEvent(_ b: BotTurn) -> Event {
        var tier: String?, prize: String?
        for e in b.events { if case .prizeWon(let ti, _, _, let special) = e { tier = ti; prize = special } }
        var tray = b.turn.state.tray
        if let p = prize { tray[p, default: 0] += 1 }
        return .botTurn(seat: b.seat, steps: b.turn.state.steps, best: b.turn.state.bestPoints, tier: tier, prize: prize,
                        made: b.turn.state.made.map(CardRef.init), burned: b.turn.state.burned.map(CardRef.init), tray: tray)
    }

    /// Every grid turn of the hand is over: deck changes apply (the player's, then each bot's), and
    /// each seat's sets and counts become its plays for the maze.
    static func finishGrid(_ t: MatchTurn, _ state: inout State, _ dice: inout Dice) -> [Event] {
        let r = state.game.finish(t, events: state.turnEvents, bots: state.botTurns.map { ($0.seat, $0.turn, $0.events) })
        var ev: [Event] = []
        state.plays = []
        for seat in 0..<state.seatCount {
            let events = seat == 0 ? state.turnEvents : (state.botTurns.first { $0.seat == seat }?.events ?? [])
            let plays = Plays.from(events, nextID: &state.nextPlayID)
            state.plays.append(plays)
            ev.append(.handPlays(seat: seat, plays: plays, kept: (seat < state.kept.count ? state.kept[seat] : []).map(CardRef.init)))
        }
        state.handResult = r
        if var m = state.maze {
            let jokers = [state.game.tray] + state.game.botTrays
            let steps = [r.steps] + state.botTurns.map(\.turn.state.steps)
            m.dice = dice
            let dealerSeat = r.dealer || m.tokens.count < 2 ? 0 : 1
            ev += m.startHand(r.turn, dealer: dealerSeat, plays: state.plays, kept: state.kept, jokers: jokers, gridSteps: steps).map(Event.maze)
            dice = m.dice
            state.maze = m
            state.stage = .maze(t)
            return ev + afterMaze(t, &state)
        }
        // Without maze.json there's no maze phase: the hand ends now.
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

extension CribMazeGame {
    /// After a maze action: the game ends at the goal; when every play is used the hand ends, and
    /// after the last hand the cap picks the winner.
    static func afterMaze(_ t: MatchTurn, _ state: inout State) -> [Event] {
        guard var m = state.maze, let r = state.handResult else { return [] }
        var ev: [Event] = []
        if m.over {
            state.game.ended = true
        } else if m.turn == nil && m.duel == nil {
            if state.game.results.count >= state.game.turns { ev.append(.maze(m.capWinner())); state.game.ended = true }
        } else {
            return []
        }
        state.game.setJokers(m.tokens.map(\.jokers))
        state.maze = m
        state.handResult = nil
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
    /// The maze's own event, if this is one.
    public var mazeEvent: MazeEvent? { if case .maze(let e) = self { e } else { nil } }
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
    private enum Own: Codable { case startHand(options: CribMazeGame.HandOptions), discard(thrown: [CardRef], kept: [CardRef]?) }

    public init(from decoder: Decoder) throws {
        switch try firstKey(decoder) {
        case "startHand", "discard":
            switch try Own(from: decoder) {
            case .startHand(let o): self = .startHand(o)
            case .discard(let t, let k): self = .discard(thrown: t, kept: k)
            }
        case let k? where MazeAction.names.contains(k): self = .maze(try MazeAction(from: decoder))
        default: self = .match(try MatchAction(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .startHand(let o): try Own.startHand(options: o).encode(to: encoder)
        case .discard(let t, let k): try Own.discard(thrown: t, kept: k).encode(to: encoder)
        case .match(let a): try a.encode(to: encoder)
        case .maze(let a): try a.encode(to: encoder)
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
        case botTurn(seat: Int, steps: Int, best: Int?, tier: String?, prize: String?, made: [CardRef], burned: [CardRef], tray: [String: Int])
        case handPlays(seat: Int, plays: [MazePlay], kept: [CardRef])
    }
    private static let ownKeys: Set<String> = ["gameStart", "handStart", "deal", "discard", "handEnd", "gameEnd", "botTurn", "handPlays"]

    public init(from decoder: Decoder) throws {
        if let k = try firstKey(decoder), MazeEvent.names.contains(k) { self = .maze(try MazeEvent(from: decoder)); return }
        guard let k = try firstKey(decoder), Self.ownKeys.contains(k) else { self = .match(try MatchEvent(from: decoder)); return }
        switch try Own(from: decoder) {
        case .gameStart(let h, let s, let f, let d): self = .gameStart(hands: h, shared: s, firstDealer: f, deckSize: d)
        case .handStart(let h, let s, let d, let n, let o): self = .handStart(hand: h, seed: s, dealer: d, deckSize: n, options: o)
        case .deal(let p, let b, let s): self = .deal(player: p, bot: b, starter: s)
        case .discard(let k, let t, let bk, let bt): self = .discard(kept: k, thrown: t, botKept: bk, botThrown: bt)
        case .handEnd(let r): self = .handEnd(result: r)
        case .gameEnd(let h, let s): self = .gameEnd(hands: h, steps: s)
        case .botTurn(let a, let b, let c, let d, let e, let f, let g, let h): self = .botTurn(seat: a, steps: b, best: c, tier: d, prize: e, made: f, burned: g, tray: h)
        case .handPlays(let a, let b, let c): self = .handPlays(seat: a, plays: b, kept: c)
        }
    }

    public func encode(to encoder: Encoder) throws {
        let own: Own
        switch self {
        case .match(let e): try e.encode(to: encoder); return
        case .maze(let e): try e.encode(to: encoder); return
        case .gameStart(let h, let s, let f, let d): own = .gameStart(hands: h, shared: s, firstDealer: f, deckSize: d)
        case .handStart(let h, let s, let d, let n, let o): own = .handStart(hand: h, seed: s, dealer: d, deckSize: n, options: o)
        case .deal(let p, let b, let s): own = .deal(player: p, bot: b, starter: s)
        case .discard(let k, let t, let bk, let bt): own = .discard(kept: k, thrown: t, botKept: bk, botThrown: bt)
        case .handEnd(let r): own = .handEnd(result: r)
        case .gameEnd(let h, let s): own = .gameEnd(hands: h, steps: s)
        case .botTurn(let a, let b, let c, let d, let e, let f, let g, let h): own = .botTurn(seat: a, steps: b, best: c, tier: d, prize: e, made: f, burned: g, tray: h)
        case .handPlays(let a, let b, let c): own = .handPlays(seat: a, plays: b, kept: c)
        }
        try own.encode(to: encoder)
    }
}
