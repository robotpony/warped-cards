// The match turn (engine.md, match rules r15). Given a state, an action and
// the dice, it returns the new state and the events. No clock, no files, no
// randomness of its own.
import CardKit
import CribbageKit
import GameKit

// MARK: - Events and actions

/// A card in an event: its ID and its notation ({"id": 17, "card": "5H"}).
public struct CardRef: Codable, Sendable, Equatable {
    public let id: Int
    public let card: String
    public init(_ c: Card) { id = c.id; card = c.notation }
}

public struct ComboOut: Codable, Sendable, Equatable {
    public let kind: ComboKind
    public let size: Int?
    public let multiplier: Int?
    public let points: Int
    public let cards: [Int]   // indexes into the set's cards, in traced order
}

public struct Fell: Codable, Sendable, Equatable { public let card: CardRef; public let from: String; public let to: String }
public struct Drew: Codable, Sendable, Equatable { public let card: CardRef; public let cell: String }

public struct TurnTotals: Codable, Sendable, Equatable {
    public var steps = 0
    public var stepsFromEdgePower = 0
    public var best: Int?
    public var scores = 0, singles = 0, multis = 0
    public var rejected = 0, warnings = 0, swaps = 0, bombs = 0, drawn = 0
    public var penaltyTotal = 0, leftOverTotal = 0
    public var stepsBySuit: [String: Int] = [:]
    public var stepsWithEdge = 0, stepsWithoutEdge = 0
    public var extraSteps = 0, clearBonus = 0
}

public enum MatchEvent: Codable, Sendable, Equatable {
    case turnStart(rulesVersion: String, dealer: Bool, hand: [CardRef], crib: [CardRef], starter: CardRef, grid: [CardRef?], stockSize: Int, timer: Int, cardBudget: Int, jokers: [String], tray: [String: Int])
    case traceRejected(positions: [String], reason: String)
    case leftoverWarning(positions: [String], leftOver: Int)
    case leftoverPenalty(positions: [String], leftOver: Int, cost: Int)
    case score(positions: [String], cards: [CardRef], combos: [ComboOut], comboPoints: Int, multiplierPercent: Int, multipliedPoints: Int, leftOver: Int, cost: Int, points: Int, multi: Bool, suit: String?, powerAfter: [String: Int])
    case boardChanged(cleared: [String], fell: [Fell], drawn: [Drew])
    case extraDrawn(card: CardRef, outcome: String, tier: String, prize: String, goes: String, cell: String)
    case swap(line: [String], before: [CardRef], after: [CardRef], source: String)
    case bomb(target: String, shape: String, cleared: [CardRef], source: String)
    case stockOut(reason: String, cardsLeftOnGrid: Int)
    case noSetsLeft(stockLeft: Int, tray: [String: Int])
    case boardCleared(kind: String, amount: Int)
    case prizeWon(tier: String, bestPoints: Int, bestCards: [CardRef], special: String)
    case turnEnd(reason: String, totals: TurnTotals)
}

public enum MatchAction: Codable, Sendable, Equatable {
    case trace(positions: [Pos])
    /// source: nil for the tray, or the board position of a swapper.
    case swap(line: [Pos], source: Pos?)
    case bomb(target: Pos, source: Pos?)
    case endTurn
    case timeUp
}

// MARK: - State

public struct MatchState: Codable, Sendable, Equatable {
    public var dealer: Bool
    /// Every position's card: grid 0-15, hand 16-19, crib 20-23 (empty for a non-dealer), starter 24.
    public var cells: [Card?]
    public var stock: [Card]
    public var drawn = 0
    /// Power level per edge position (16 to 24).
    public var power: [Int]
    public var steps = 0
    public var tray: [String: Int]
    public var items = 0
    public var scoredSets: [[Int]] = []
    public var best: (points: Int, cards: [Card])? { get { bestPoints.map { ($0, bestCards) } } set { bestPoints = newValue?.points; bestCards = newValue?.cards ?? [] } }
    public var bestPoints: Int?
    public var bestCards: [Card] = []
    public var warned: Bool
    public var stockOut = false, dead = false, over = false
    public var endReason: String?
    public var nextMadeID = 200, nextSpecialID = 300
    public var totals = TurnTotals()

    public func card(_ p: Pos) -> Card? { cells[p] }
    public var gridEmpty: Bool { Board.grid.allSatisfy { cells[$0] == nil } }
    public var cardsOnGrid: Int { Board.grid.filter { cells[$0] != nil }.count }
}

/// Inputs for a standalone turn (engine.md › Standalone turn).
public struct TurnSetup: Codable, Sendable {
    public var seed: UInt64
    public var dealer: Bool
    public var tray: [String: Int]?
    public var warned: Bool
    /// Fixed cards for tests and scenarios: a hand (4) and a starter, in fixture notation.
    public var fixedHand: [String]?
    public var fixedStarter: String?
    public init(seed: UInt64, dealer: Bool = true, tray: [String: Int]? = nil, warned: Bool = false, fixedHand: [String]? = nil, fixedStarter: String? = nil) {
        self.seed = seed; self.dealer = dealer; self.tray = tray; self.warned = warned; self.fixedHand = fixedHand; self.fixedStarter = fixedStarter
    }
}

/// What a set would score, without changing anything.
public struct SetValue: Sendable {
    public let count: Count
    public let comboPoints: Int
    public let percent: Int
    public let multiplied: Int
    public let leftOver: Int
    public let points: Int
    public let suit: Suit?
}

// MARK: - The match turn

public struct MatchTurn: Sendable {
    public static let rulesVersion = "match-r15"
    public let config: Config
    public private(set) var state: MatchState
    public var dice: Dice

    var r: RulesConfig.Match { config.rules.match }

    // MARK: Setup

    /// Starts a standalone turn. Pass scripted dice to replay recorded rolls.
    public static func start(config: Config, setup: TurnSetup, dice scripted: Dice? = nil) -> (MatchTurn, [MatchEvent]) {
        var dice = scripted ?? Dice(seed: setup.seed)
        var deck = (0..<52).map { Card(standard: $0) }
        dice.shuffle(&deck, stream: "deal", purpose: "shuffle")
        func take(_ text: String) -> Card {
            let want = Card.parse(text)!
            let i = deck.firstIndex { $0.id == want.id }!
            return deck.remove(at: i)
        }
        let hand: [Card], starter: Card
        if let fh = setup.fixedHand, let fs = setup.fixedStarter {
            hand = fh.map(take); starter = take(fs)
        } else {
            hand = Array(deck.prefix(4)); deck.removeFirst(4)
            starter = deck.removeFirst()
        }
        let crib = Array(deck.prefix(4)); deck.removeFirst(4)
        deck.removeFirst(4)   // the other player's hand
        // Jokers for the round, then the configured extras, at the end of the deck.
        let j = config.jokers
        let jokerCount = j.perRound.min + dice.below(j.perRound.max - j.perRound.min + 1, stream: "deal", purpose: "joker_count")
        var extraKinds: [String] = []
        for _ in 0..<jokerCount { extraKinds.append(dice.pick(j.kinds.entries, stream: "deal", purpose: "joker_kind")) }
        extraKinds += j.extras
        for (k, kind) in extraKinds.enumerated() { deck.append(Card(id: 100 + k, kind: .extra(kind), rank: 0, suit: nil)) }
        dice.shuffle(&deck, stream: "deal", purpose: "shuffle")

        var cells = [Card?](repeating: nil, count: 25)
        for i in 0..<4 { cells[16 + i] = hand[i]; if setup.dealer { cells[20 + i] = crib[i] } }
        cells[Board.starter] = starter
        let st = MatchState(dealer: setup.dealer, cells: cells, stock: deck,
                            power: [Int](repeating: config.rules.match.edgePower.start, count: 25),
                            tray: setup.tray ?? config.rules.specials.start, warned: setup.warned)
        var t = MatchTurn(config: config, state: st, dice: dice)
        var ev: [MatchEvent] = []
        // Fill the grid from the top of the stock, row by row.
        for p in Board.grid { t.state.cells[p] = t.draw() }
        ev.append(.turnStart(rulesVersion: Self.rulesVersion, dealer: setup.dealer, hand: hand.map(CardRef.init), crib: setup.dealer ? crib.map(CardRef.init) : [],
                             starter: CardRef(starter), grid: Board.grid.map { t.state.cells[$0].map(CardRef.init) }, stockSize: t.state.stock.count,
                             timer: config.rules.match.timerSeconds, cardBudget: config.rules.match.cardBudget, jokers: extraKinds, tray: t.state.tray))
        ev += t.resolveExtras()
        ev += t.afterAction()
        return (t, ev)
    }

    private init(config: Config, state: MatchState, dice: Dice) { self.config = config; self.state = state; self.dice = dice }

    // MARK: Drawing and refilling

    /// How many more cards can be drawn.
    public var drawable: Int {
        let budgetLeft = r.cardBudget > 0 ? max(0, r.cardBudget - state.drawn) : Int.max
        return min(state.stock.count, budgetLeft)
    }
    mutating func draw() -> Card? {
        guard drawable > 0 else { return nil }
        state.drawn += 1; state.totals.drawn += 1
        return state.stock.removeFirst()
    }

    /// Clears cells, then refills: per column, cards fall; empty cells fill from the stock, lowest first.
    mutating func clearAndRefill(_ cleared: [Pos]) -> MatchEvent {
        for p in cleared { state.cells[p] = nil }
        var fell: [Fell] = [], drew: [Drew] = []
        let cols = Set(cleared.filter(Board.isGrid).map { $0 % 4 }).sorted()
        for c in cols {
            let column = (0..<4).map { Board.g($0, c) }
            var cards: [(Card, Pos)] = column.compactMap { p in state.cells[p].map { ($0, p) } }
            for p in column { state.cells[p] = nil }
            // Fall to the bottom, keeping order.
            var row = 3
            while let (card, from) = cards.popLast() {
                let to = Board.g(row, c); state.cells[to] = card
                if to != from { fell.append(Fell(card: CardRef(card), from: Board.name(from), to: Board.name(to))) }
                row -= 1
            }
            while row >= 0 {
                let p = Board.g(row, c)
                if let card = draw() { state.cells[p] = card; drew.append(Drew(card: CardRef(card), cell: Board.name(p))) }
                row -= 1
            }
        }
        return .boardChanged(cleared: cleared.map(Board.name), fell: fell, drawn: drew)
    }

    /// One card into one cell, no falling (after an extra card leaves it).
    mutating func refillOne(_ p: Pos) -> MatchEvent {
        state.cells[p] = nil
        var drew: [Drew] = []
        if let card = draw() { state.cells[p] = card; drew.append(Drew(card: CardRef(card), cell: Board.name(p))) }
        return .boardChanged(cleared: [Board.name(p)], fell: [], drawn: drew)
    }

    // MARK: Extra cards

    mutating func resolveExtras() -> [MatchEvent] {
        var ev: [MatchEvent] = []
        while let p = Board.grid.first(where: { state.cells[$0]?.isExtra == true }), let card = state.cells[p], case .extra(let kind) = card.kind {
            let j = config.jokers
            let outcomeName = dice.pick(j.tables[kind]!.entries, stream: "reveal", purpose: "outcome:\(kind)")
            let o = j.outcomes[outcomeName]!
            var prize = "", goes = o.goes
            var made: Card?, special: Card?
            if let makes = o.makes {
                let pool = (0..<52).map { Card(standard: $0) }.filter { c in
                    switch makes { case "scoring": return j.scoringRanks.contains(c.rank); case "five": return c.rank == 5; default: return true }
                }
                let base = pool[dice.below(pool.count, stream: "reveal", purpose: "made_card")]
                made = Card(id: state.nextMadeID, kind: .made, rank: base.rank, suit: base.suit); state.nextMadeID += 1
                prize = made!.notation
            } else if o.special != nil {
                let known = config.rules.specials.known
                let kindName = known[dice.below(known.count, stream: "reveal", purpose: "special_kind")]
                special = Card(id: state.nextSpecialID, kind: .special(kindName), rank: 0, suit: nil); state.nextSpecialID += 1
                prize = kindName
            } else if goes == "tray" {
                prize = "item"
            } else if goes == "steps" {
                prize = "+\(o.amount ?? 0) steps"
            }
            var after: MatchEvent?
            switch o.goes {
            case "board":
                state.cells[p] = made
            case "stock":
                if drawable > 0 {
                    let at = dice.below(drawable + 1, stream: "board", purpose: "stock_insert")
                    state.stock.insert(special!, at: at)
                } else {
                    goes = "tray"; state.tray[special!.notation, default: 0] += 1
                }
                after = refillOne(p)
            case "tray":
                if let s = special { state.tray[s.notation, default: 0] += 1 } else { state.items += 1 }
                after = refillOne(p)
            default: // steps
                state.steps += o.amount ?? 0; state.totals.steps += o.amount ?? 0; state.totals.extraSteps += o.amount ?? 0
                after = refillOne(p)
            }
            ev.append(.extraDrawn(card: CardRef(card), outcome: outcomeName, tier: o.tier, prize: prize, goes: goes, cell: Board.name(p)))
            if let a = after { ev.append(a) }
        }
        return ev
    }

    // MARK: Checks

    mutating func afterAction() -> [MatchEvent] {
        var ev: [MatchEvent] = []
        if drawable == 0 && !state.stockOut {
            state.stockOut = true
            ev.append(.stockOut(reason: state.stock.isEmpty ? "stock_empty" : "budget_used", cardsLeftOnGrid: state.cardsOnGrid))
        }
        if state.gridEmpty { return ev + end("board_cleared") }
        let canScore = anySetScores()
        if !canScore && !state.dead { ev.append(.noSetsLeft(stockLeft: drawable, tray: state.tray)) }
        state.dead = !canScore
        return ev
    }

    /// Whether any connected set of 2 to maxSet could score above 0 now.
    public func anySetScores() -> Bool {
        for set in Self.sets(maxSize: r.maxSet) where traceProblem(set) == nil {
            if let v = value(of: set), !v.count.combos.isEmpty, v.points > 0 { return true }
        }
        return false
    }

    private static let setsCache: [[[Pos]]] = (0...7).map { $0 >= 2 ? Board.connectedSets(maxSize: $0) : [] }
    /// Every connected set up to maxSize, in position order.
    public static func sets(maxSize: Int) -> [[Pos]] { maxSize <= 7 ? setsCache[max(0, maxSize)] : Board.connectedSets(maxSize: maxSize) }

    // MARK: Tracing

    /// Why a trace would be rejected (steps 1 to 4), or nil if it passes.
    public func traceProblem(_ ps: [Pos]) -> String? {
        if ps.count < 2 || ps.count > r.maxSet || Set(ps).count != ps.count { return "size" }
        for p in ps { guard let c = state.cells[p] else { return "size" }; if c.isSpecial { return "special" } }
        if !ps.contains(where: Board.isGrid) { return "no_grid_card" }
        if !Board.connected(ps) { return "not_touching" }
        if state.scoredSets.contains(ps.map { state.cells[$0]!.id }.sorted()) { return "already_scored" }
        return nil
    }

    /// What a set of positions would score now, counted in the order given.
    public func value(of ps: [Pos]) -> SetValue? {
        var cards: [(rank: Int, suit: Suit)] = []
        for p in ps { guard let c = state.cells[p], c.isPlaying, let s = c.suit else { return nil }; cards.append((c.rank, s)) }
        var opts = CountOptions(flushMin: r.flushMin)
        if let si = ps.firstIndex(of: Board.starter), let st = state.cells[Board.starter],
           let ji = ps.firstIndex(where: { (Board.hand.contains($0) || Board.crib.contains($0)) && state.cells[$0]?.rank == 11 && state.cells[$0]?.suit == st.suit }) {
            opts.nobs = [si, ji]
        }
        let cnt = count(cards, opts, scoring: config.rules.scoring)
        let combo = cnt.total
        let ep = r.edgePower
        let levels = ps.filter(Board.isEdge).map { state.power[$0] }
        var percent: Int
        if ep.combine == "each" {
            percent = 100
            for l in levels { percent = (percent * (100 + ep.percentPerLevel * l) + 50) / 100 }
        } else {
            percent = 100 + ep.percentPerLevel * levels.reduce(0, +)
        }
        if ep.capPercent > 0 { percent = min(percent, ep.capPercent) }
        let multiplied = (combo * percent + 50) / 100
        let left = cnt.leftOver.count
        return SetValue(count: cnt, comboPoints: combo, percent: percent, multiplied: multiplied, leftOver: left,
                        points: multiplied - r.leftOverCost * left, suit: suitOf(cards.map(\.suit)))
    }

    // MARK: Actions

    /// Applies an action. Throws for an action that isn't allowed; a trace the rules reject is an event.
    public mutating func apply(_ action: MatchAction) throws -> [MatchEvent] {
        guard !state.over else { throw IllegalAction("the turn is over") }
        switch action {
        case .trace(let ps): return trace(ps)
        case .swap(let line, let source): return try swap(line, source)
        case .bomb(let target, let source): return try bomb(target, source)
        case .endTurn: return end("player")
        case .timeUp:
            guard r.timerSeconds > 0 else { throw IllegalAction("the timer is off") }
            return end("timer")
        }
    }

    mutating func trace(_ ps: [Pos]) -> [MatchEvent] {
        let names = ps.map(Board.name)
        if let why = traceProblem(ps) { state.totals.rejected += 1; return [.traceRejected(positions: names, reason: why)] }
        let v = value(of: ps)!
        let hasCombos = !v.count.combos.isEmpty
        if v.leftOver > 0 && !state.warned {
            state.warned = true; state.totals.warnings += 1
            return [.leftoverWarning(positions: names, leftOver: v.leftOver)]
        }
        if !hasCombos {
            let cost = r.leftOverCost * ps.count
            state.steps -= cost; state.totals.steps -= cost; state.totals.penaltyTotal += cost
            return [.leftoverPenalty(positions: names, leftOver: ps.count, cost: cost)]
        }
        // Score.
        let cost = r.leftOverCost * v.leftOver
        state.steps += v.points
        var t = state.totals
        t.steps += v.points; t.stepsFromEdgePower += v.multiplied - v.comboPoints; t.leftOverTotal += cost
        t.scores += 1; if v.count.combos.count == 1 { t.singles += 1 } else { t.multis += 1 }
        let hasEdge = ps.contains(where: Board.isEdge)
        if hasEdge { t.stepsWithEdge += v.points } else { t.stepsWithoutEdge += v.points }
        t.stepsBySuit[v.suit?.letter ?? "none", default: 0] += v.points
        state.totals = t
        var powerAfter: [String: Int] = [:]
        for p in ps where Board.isEdge(p) { state.power[p] += r.edgePower.step; powerAfter[Board.name(p)] = state.power[p] }
        let cards = ps.map { state.cells[$0]! }
        state.scoredSets.append(cards.map(\.id).sorted())
        if state.bestPoints == nil || v.points > state.bestPoints! { state.bestPoints = v.points; state.bestCards = cards; state.totals.best = v.points }
        var ev: [MatchEvent] = [.score(positions: names, cards: cards.map(CardRef.init),
                                       combos: v.count.combos.map { ComboOut(kind: $0.kind, size: $0.size, multiplier: $0.multiplier, points: $0.points, cards: $0.cards) },
                                       comboPoints: v.comboPoints, multiplierPercent: v.percent, multipliedPoints: v.multiplied, leftOver: v.leftOver, cost: cost,
                                       points: v.points, multi: v.count.combos.count > 1, suit: v.suit?.letter, powerAfter: powerAfter)]
        ev.append(clearAndRefill(ps.filter(Board.isGrid)))
        ev += resolveExtras()
        ev += afterAction()
        return ev
    }

    /// Whether positions make a 2 to 4 cell straight, gap-free line on the grid.
    public static func isLine(_ ps: [Pos]) -> Bool {
        guard (2...4).contains(ps.count), ps.allSatisfy(Board.isGrid), Set(ps).count == ps.count else { return false }
        let s = ps.sorted { Board.coords($0) < Board.coords($1) }.map(Board.coords)
        let dr = s[1].r - s[0].r, dc = s[1].c - s[0].c
        guard abs(dr) <= 1, abs(dc) <= 1, (dr, dc) != (0, 0) else { return false }
        for i in 1..<s.count where s[i].r - s[i - 1].r != dr || s[i].c - s[i - 1].c != dc { return false }
        return true
    }

    mutating func useSpecial(_ kind: String, from source: Pos?) throws {
        if let src = source {
            guard Board.isGrid(src), state.cells[src]?.kind == .special(kind) else { throw IllegalAction("no \(kind) at \(Board.name(src))") }
        } else {
            guard state.tray[kind, default: 0] > 0 else { throw IllegalAction("no \(kind) in the tray") }
            state.tray[kind]! -= 1
        }
    }

    mutating func swap(_ line: [Pos], _ source: Pos?) throws -> [MatchEvent] {
        guard Self.isLine(line), line.allSatisfy({ state.cells[$0] != nil }) else { throw IllegalAction("not a line of cards") }
        if let s = source, line.contains(s) { throw IllegalAction("the swapper can't be in its own line") }
        try useSpecial("swapper", from: source)
        let ordered = line.sorted { Board.coords($0) < Board.coords($1) }
        let before = ordered.map { state.cells[$0]! }
        for (p, c) in zip(ordered, before.reversed()) { state.cells[p] = c }
        state.totals.swaps += 1
        var ev: [MatchEvent] = [.swap(line: ordered.map(Board.name), before: before.map(CardRef.init), after: ordered.map { CardRef(state.cells[$0]!) }, source: source.map(Board.name) ?? "tray")]
        if let s = source { ev.append(clearAndRefill([s])) }
        ev += resolveExtras()
        ev += afterAction()
        return ev
    }

    /// The turn as it would be with a line's cards reversed, for searching (no dice, no events,
    /// nothing used up). Bots use it to look for the swap that opens the best set.
    public func reversing(_ line: [Pos]) -> MatchTurn {
        var t = self
        let ordered = line.sorted { Board.coords($0) < Board.coords($1) }
        let cards = ordered.map { t.state.cells[$0] }
        for (p, c) in zip(ordered, cards.reversed()) { t.state.cells[p] = c }
        return t
    }

    public func blast(_ target: Pos) -> [Pos] {
        let (tr, tc) = Board.coords(target)
        let square = config.rules.specials.bombShape == "square"
        return Board.grid.filter { p in
            let (r, c) = Board.coords(p), dr = abs(r - tr), dc = abs(c - tc)
            return square ? (dr <= 1 && dc <= 1) : (dr + dc <= 1)
        }
    }

    mutating func bomb(_ target: Pos, _ source: Pos?) throws -> [MatchEvent] {
        guard Board.isGrid(target), state.cells[target] != nil else { throw IllegalAction("the target holds no card") }
        try useSpecial("bomb", from: source)
        var hit = blast(target).filter { state.cells[$0] != nil }
        if let s = source, !hit.contains(s) { hit.append(s) }
        hit.sort()
        let cleared = hit.map { state.cells[$0]! }
        state.totals.bombs += 1
        var ev: [MatchEvent] = [.bomb(target: Board.name(target), shape: config.rules.specials.bombShape, cleared: cleared.map(CardRef.init), source: source.map(Board.name) ?? "tray")]
        ev.append(clearAndRefill(hit))
        ev += resolveExtras()
        ev += afterAction()
        return ev
    }

    // MARK: Ending

    mutating func end(_ reason: String) -> [MatchEvent] {
        guard !state.over else { return [] }
        state.over = true; state.endReason = reason
        var ev: [MatchEvent] = []
        if reason == "board_cleared" {
            let b = r.clearBonus
            let amount = b.kind == "steps" ? b.amount : 0
            state.steps += amount; state.totals.steps += amount; state.totals.clearBonus = amount
            ev.append(.boardCleared(kind: b.kind, amount: amount))
        }
        if let bp = state.bestPoints {
            let p = r.prize
            let tier = bp >= p.epicAt ? "epic" : bp >= p.rareAt ? "rare" : "common"
            let special = dice.pick(p.special.entries, stream: "prize", purpose: "prize_special")
            ev.append(.prizeWon(tier: tier, bestPoints: bp, bestCards: state.bestCards.map(CardRef.init), special: special))
        }
        ev.append(.turnEnd(reason: reason, totals: state.totals))
        return ev
    }
}

extension MatchState {
    // Tuples aren't Equatable or Codable, so best lives in two stored fields.
    enum CodingKeys: String, CodingKey {
        case dealer, cells, stock, drawn, power, steps, tray, items, scoredSets, bestPoints, bestCards, warned, stockOut, dead, over, endReason, nextMadeID, nextSpecialID, totals
    }
    public static func == (a: MatchState, b: MatchState) -> Bool {
        a.cells == b.cells && a.stock == b.stock && a.steps == b.steps && a.power == b.power && a.tray == b.tray && a.scoredSets == b.scoredSets && a.over == b.over && a.totals == b.totals
    }
}
