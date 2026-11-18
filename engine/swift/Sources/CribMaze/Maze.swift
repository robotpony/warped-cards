// The maze phase (maze.md › Turns, Walking, Closing a door and flipping a switch; engine.md › The
// maze): tokens on the board, each seat's plays for the hand, and the actions that spend them.
// One action at a time, so it records and replays like the match turn. No clock, no files; its
// only randomness is the `maze.*` streams of the dice it's given.
import CardKit
import CribbageKit
import GameKit

/// A way a reach takes at a junction: at this cell, go this way.
public struct MazeWay: Codable, Sendable, Equatable {
    public let cell: Int
    public let dir: Dir
    public init(cell: Int, dir: Dir) { self.cell = cell; self.dir = dir }
}

public enum MazeAction: Codable, Sendable, Equatable {
    /// Walk a play. `ways` (with a reach on) are the junctions the player turned, for this play only.
    case mazeWalk(play: Int, ways: [MazeWay]?)
    /// Close the open passage between these two cells with a suited play.
    case mazeClose(play: Int, passage: [Int])
    /// Flip a switch (its letter, A to H) with a play.
    case mazeFlip(play: Int, letter: String)
    /// Use a power joker: a swapper on another seat (`target`), a bomb on a door (`passage`) or a
    /// cell (`cell`, a mine), a burn on a cell (a fire), or a reach (no target).
    case mazeJoker(kind: String, target: Int?, cell: Int?, passage: [Int]?)
    case mazeEndTurn
    /// A person's card in a duel.
    case duelCard(card: CardRef)

    /// Every maze action's name, as records write it.
    public static let names: Set<String> = ["mazeWalk", "mazeClose", "mazeFlip", "mazeJoker", "mazeEndTurn", "duelCard"]
}

/// A door a walk met.
public struct WalkDoor: Codable, Sendable, Equatable {
    /// The door's two cells, lower first.
    public let passage: [Int]
    /// How many cells the walk had moved into when it met the door.
    public let at: Int
    /// Steps spent on it, and whether it broke.
    public let hit: Int
    public let broke: Bool
}

public enum MazeEvent: Codable, Sendable, Equatable {
    case mazeBuilt(size: Int, start: Int, goal: Int, length: Int, doors: Int, variants: Int, switches: Int, stars: Int)
    /// A seat's turn starts.
    case mazeTurn(seat: Int, hand: Int)
    /// A walk: the cells moved into, in order; the junctions it turned at; the doors it met; whether a
    /// wrong-suit door stopped it, a key let it through, or it reached the goal; where it ended.
    case walk(seat: Int, play: Int, steps: Int, path: [Int], junctions: [MazeWay], doors: [WalkDoor], stopped: Bool, key: Bool, end: Int, won: Bool, reach: Bool)
    case doorClosed(seat: Int, play: Int, passage: [Int], suit: String, strength: Int)
    case switchFlipped(seat: Int, play: Int, letter: String)
    /// Nobody has a play left: each seat's cost to the goal.
    case mazeHandEnd(hand: Int, costs: [Int])
    case swapped(seat: Int, target: Int, cells: [Int])
    case doorBombed(seat: Int, passage: [Int], opened: Bool, left: Int)
    /// A hazard placed: `fire` (a burn) or `mine` (a bomb).
    case hazardSet(seat: Int, kind: String, cell: Int)
    case reachOn(seat: Int)
    /// A hazard went off under a seat: the plays it lost, by id, and how many it still owes.
    case hazardHit(seat: Int, kind: String, cell: Int, landed: Bool, lose: Int, lost: [Int], owed: Int)
    /// Plays owed from the last hand came off this hand's.
    case playsOwed(seat: Int, lost: [Int], owed: Int)
    case star(seat: Int, cell: Int, joker: String)
    /// The maze stirs for a stuck seat: `fade` (the door on its way, as passage), `star` (at cell) or `shift` (passage opened).
    case stir(seat: Int, opening: String, cell: Int?, passage: [Int]?)
    /// A duel's game starts: why (`stuck` or `landing`), the two seats, who leads, which game (1, or 2 after a tie), each one's 4 cards.
    case duelStart(why: String, seats: [Int], lead: Int, game: Int, hands: [[CardRef]])
    case duelCard(seat: Int, card: CardRef, count: Int, scores: [PegScore])
    /// A seat can't play and says go.
    case duelGo(seat: Int)
    /// Nobody can play: the last to play pegs the go.
    case duelPoint(seat: Int, kind: String, points: Int, count: Int)
    /// The duel's end: each game's scores, the winner, whether a coin decided, the play that moved
    /// to the winner (its id, or none), and for a stuck duel how the winner's way opened (or none).
    case duelEnd(why: String, seats: [Int], scores: [[Int]], winner: Int, coin: Bool, took: Int?, opened: String?)
    /// The game's winner: `goal` (the first token in) or `cap` (cheapest to the goal after the last hand).
    case mazeEnd(winner: Int, reason: String, costs: [Int])

    /// Every maze event's name, as records write it.
    public static let names: Set<String> = ["mazeBuilt", "mazeTurn", "walk", "doorClosed", "switchFlipped", "mazeHandEnd", "mazeEnd",
                                          "swapped", "doorBombed", "hazardSet", "reachOn", "hazardHit", "playsOwed", "star",
                                          "stir", "duelStart", "duelCard", "duelGo", "duelPoint", "duelEnd"]
}

/// A player's token, plays and maze state.
public struct MazeToken: Codable, Sendable, Equatable {
    public let seat: Int
    public var pos: Int
    /// The cell it came in from, which a walk doesn't turn back to; none at the start, after a stop or a swap.
    public var from: Int?
    /// It stopped against a door last walk.
    public var atDoor = false
    /// Its plays left this hand, biggest first.
    public var plays: [MazePlay] = []
    /// Its 4 kept cards this hand.
    public var kept: [Card] = []
    /// Its power jokers, the same set as on the grid.
    public var jokers: [String: Int] = [:]
    /// Doors closed this hand.
    public var closed = 0
    /// A reach is on: its next walk picks its way.
    public var reach = false
    /// Plays still owed to hazards, taken from its next hand's.
    public var owed = 0
    /// Its cost to the goal when the last hand started (the stuck check).
    public var handStartCost: Int?
    /// Steps scored on the grid over the game (the cap's tie-break).
    public var gridSteps = 0
}

public struct Maze: Sendable {
    public let config: MazeConfig
    public internal(set) var board: MazeBoard
    public internal(set) var tokens: [MazeToken]
    /// Which seats are people: a person's turn waits for a joker or End turn after the play.
    public let people: [Bool]
    public internal(set) var hand = 0
    public internal(set) var dealer = 0
    /// Whose turn it is, or none between hands.
    public internal(set) var turn: Int?
    /// This turn's play is used.
    public internal(set) var played = false
    public internal(set) var winner: Int?
    /// Pairs [closer, other] this hand: the closer closed a door on the other's way.
    public internal(set) var blocked: [[Int]] = []
    /// A hazard on a cell: `fire` or `mine`, and who set it. In the order set.
    public struct Hazard: Codable, Sendable, Equatable { public let cell: Int, kind: String, seat: Int }
    public internal(set) var hazards: [Hazard] = []
    /// Pairs [a, b], lower first, that swapped this hand.
    public internal(set) var swaps: [[Int]] = []
    /// This turn's joker is used.
    public internal(set) var jokerUsed = false
    /// Pairs [a, b], lower first, that met in a landing duel this hand.
    public internal(set) var met: [[Int]] = []
    /// A duel being played.
    public struct Duel: Sendable, Equatable {
        public let why: String
        public let seats: [Int]
        /// The first game's lead, as an index into seats.
        public let lead: Int
        public internal(set) var game: Int
        public internal(set) var peg: PegPlay
        public internal(set) var scores: [[Int]] = []
        /// The seat whose walk landed it, for a landing duel; its turn goes on after.
        public let walker: Int?
    }
    public internal(set) var duel: Duel?
    public internal(set) var dice: Dice

    public static let letters = ["A", "B", "C", "D", "E", "F", "G", "H"]

    /// The board for a game: built from the game's seed on its own dice, so a record's rolls never hold
    /// the generation's thousands of draws (a replay builds it again from the seed).
    public static func build(_ config: MazeConfig, seed: UInt64) -> MazeBoard {
        var d = Dice(seed: seed)
        return MazeBoard.generate(config.board, dice: &d)
    }

    public init(config: MazeConfig, board: MazeBoard, seats: [PlayerSeat], dice: Dice) {
        self.config = config; self.board = board; self.dice = dice
        tokens = seats.map { MazeToken(seat: $0.seat, pos: board.start) }
        people = seats.map { $0.kind == "human" }
    }

    public var builtEvent: MazeEvent {
        .mazeBuilt(size: board.w, start: board.start, goal: board.goal, length: board.route.count - 1, doors: board.doors.count,
                   variants: board.variants.count, switches: board.switches.count, stars: board.stars.count)
    }
    public var over: Bool { winner != nil }
    /// Whether every play of the hand is used.
    public var handDone: Bool { tokens.allSatisfy { $0.plays.isEmpty } }

    // MARK: The cost field

    /// Every cell's cost to the goal (maze.md › The cost field): Dijkstra from the goal, an open
    /// passage 1, a door its strength left plus 1, plus `suitedDoorExtra` with a suit; a switch
    /// that's off can't be passed. Cells that can't reach it cost `Int.max`.
    public func costField() -> [Int] {
        let n = board.n
        var dist = [Int](repeating: Int.max, count: n)
        var heap = MinHeap()
        dist[board.goal] = 0; heap.push(0, board.goal)
        while let (d0, u) = heap.pop() {
            if d0 > dist[u] { continue }
            for d in Dir.allCases {
                guard let p = board.passage(u, d), p.passable, let v = board.step(u, d) else { continue }
                let c = p.kind == .door ? p.left + 1 + (p.suit != nil ? config.cost.suitedDoorExtra : 0) : 1
                if d0 + c < dist[v] { dist[v] = d0 + c; heap.push(d0 + c, v) }
            }
        }
        return dist
    }

    public func cost(_ seat: Int) -> Int { costField()[tokens[seat].pos] }

    /// A seat's way to the goal: downhill on the cost field, at each cell to the cheapest passable
    /// neighbour that's cheaper (first in direction order on a tie), up to 400 cells; and the
    /// passage key of the first door on it.
    public func wayAhead(_ seat: Int, field f: [Int]? = nil) -> (cells: [Int], keys: [Int], door: Int?) {
        let f = f ?? costField()
        var c = tokens[seat].pos, cells: [Int] = [], keys: [Int] = [], door: Int?
        for _ in 0..<400 where c != board.goal {
            var best: (Int, Dir)?
            for d in board.exits(c) { if let o = board.step(c, d), f[o] < f[c], best == nil || f[o] < f[best!.0] { best = (o, d) } }
            guard let (o, d) = best else { break }
            let k = board.key(c, d)!
            if board.passages[k]?.kind == .door && door == nil { door = k }
            keys.append(k); cells.append(o); c = o
        }
        return (cells, keys, door)
    }

    // MARK: Walking

    /// What a walk did (maze.md › Walking).
    public struct Walk: Sendable, Equatable {
        public var path: [Int] = []
        public var junctions: [MazeWay] = []
        public var doors: [WalkDoor] = []
        public var stopped = false, key = false, won = false
        /// The walk ended on a door still standing.
        public var atStandingDoor = false
        public var end = 0
        /// The cells passed that held a hazard, in order.
        public var hazards: [Int] = []
        /// It used all its steps on its end cell: not stopped, and its last steps not on a door.
        public var landed: Bool { !stopped && !atStandingDoor }
    }

    /// Walks a play, changing the board (doors worn and broken, arrows turned) and the token.
    /// `reach` lets the play pick its way; `ways` are the junctions a person turned.
    mutating func walk(_ seat: Int, steps: Int, suit: String?, reach: Bool, ways: [MazeWay], field f: [Int], hazardAt: (Int) -> Bool = { _ in false }) -> Walk {
        var w = Walk(), n = steps
        var t = tokens[seat]
        defer { tokens[seat] = t }
        while n > 0 {
            let i = t.pos, ex = board.exits(i)
            let back = t.from.flatMap { board.dir(i, $0) }
            var cand = ex.filter { $0 != back }
            let live = cand.filter { !board.dead[i * 4 + $0.rawValue] }
            if !live.isEmpty { cand = live }
            if cand.isEmpty { cand = ex }
            if cand.isEmpty { break }
            let keys = t.jokers["key", default: 0]
            func wrongSuit(_ d: Dir) -> Bool { let p = board.passage(i, d)!; return p.kind == .door && p.suit != nil && p.suit != suit }
            let canPass = cand.filter { !(wrongSuit($0) && keys == 0) }
            if !canPass.isEmpty { cand = canPass }
            if t.atDoor {
                let doors = cand.filter { board.passage(i, $0)!.kind == .door }
                if !doors.isEmpty { cand = doors }
            }
            var d = cand[0]
            if cand.count > 1 && reach {
                if let chosen = ways.last(where: { $0.cell == i })?.dir, cand.contains(chosen) { d = chosen }
                else { d = cand.min { f[board.step(i, $0)!] < f[board.step(i, $1)!] }! }
                w.junctions.append(MazeWay(cell: i, dir: d))
            } else if cand.count > 1 {
                let a = board.arrow[i].rawValue
                d = (0..<4).map { Dir(rawValue: (a + $0) % 4)! }.first { cand.contains($0) }!
                let live = ex.filter { !board.dead[i * 4 + $0.rawValue] }
                let turnable = live.isEmpty ? ex : live
                if let next = (1...4).map({ Dir(rawValue: (d.rawValue + $0) % 4)! }).first(where: { turnable.contains($0) }) { board.arrow[i] = next }
                w.junctions.append(MazeWay(cell: i, dir: d))
            }
            let to = board.step(i, d)!, k = board.key(i, d)!
            if wrongSuit(d) {
                if keys > 0 { t.jokers["key"] = keys - 1; w.key = true }
                else { w.stopped = true; t.from = nil; t.atDoor = true; break }
            }
            if var p = board.passages[k], p.kind == .door {
                let hit = min(n, p.left)
                p.damage += hit; n -= hit
                let broke = p.damage >= p.strength
                if broke { p.kind = .open; p.broken = true }
                board.passages[k] = p
                w.doors.append(WalkDoor(passage: [min(i, to), max(i, to)], at: w.path.count, hit: hit, broke: broke))
                if !broke { w.atStandingDoor = true; break }
                continue
            }
            t.from = i; t.pos = to; t.atDoor = false; n -= 1
            w.path.append(to)
            if to == board.goal { w.won = true; break }
            if hazardAt(to) && !w.hazards.contains(to) { w.hazards.append(to) }
        }
        w.end = t.pos
        return w
    }

    /// A play's walk, on a copy of the maze (maze.md › Walking › preview): what it would do, and the
    /// cost to the goal from where it would end, on the field after it.
    /// `reach` overrides whether a reach is on, for a bot weighing one.
    public func preview(seat: Int, play id: Int, ways: [MazeWay] = [], reach: Bool? = nil, field: [Int]? = nil) -> (walk: Walk, cost: Int)? {
        guard let p = tokens[seat].plays.first(where: { $0.id == id }) else { return nil }
        var copy = self
        let w = copy.walk(seat, steps: p.steps, suit: p.suit, reach: reach ?? copy.reachOn(seat), ways: ways, field: field ?? costField(), hazardAt: copy.hazardAt)
        return (w, copy.costField()[w.end])
    }

    // MARK: Closing and flipping

    /// Whether this seat may close the open passage with this key now (maze.md › Close a door).
    public func canClose(_ seat: Int, key k: Int) -> Bool {
        guard let p = board.passages[k], p.kind == .open else { return false }
        guard tokens[seat].closed < config.close.perRound else { return false }
        let (a, b) = board.cells(ofKey: k)
        if [a, b].contains(where: { c in c == board.goal || tokens.contains { $0.pos == c } }) { return false }
        for q in tokens.indices where q != seat && blocked.contains([q, seat]) && wayAhead(q).keys.contains(k) { return false }
        return true
    }

    public func canFlip(_ s: Int) -> Bool { s < board.switches.count && board.switches[s].flipped != hand }

    /// The cost field after flipping a switch, on a copy (for bots weighing a flip).
    public func costField(flipping s: Int) -> [Int] { var c = self; c.flip(s); return c.costField() }

    mutating func flip(_ s: Int) {
        for k in [board.switches[s].a, board.switches[s].b] { board.passages[k]!.on.toggle() }
        board.findPockets()
    }

    // MARK: Hands and turns

    /// Starts a hand's maze phase with each seat's plays and kept cards.
    mutating func startHand(_ hand: Int, dealer: Int, plays: [[MazePlay]], kept: [[Card]], jokers: [[String: Int]], gridSteps: [Int]) -> [MazeEvent] {
        self.hand = hand; self.dealer = dealer; blocked = []
        for i in tokens.indices {
            tokens[i].plays = i < plays.count ? plays[i] : []
            tokens[i].kept = i < kept.count ? kept[i] : []
            tokens[i].jokers = i < jokers.count ? jokers[i] : [:]
            tokens[i].closed = 0
            tokens[i].gridSteps += i < gridSteps.count ? gridSteps[i] : 0
        }
        turn = nil
        swaps = []; met = []
        var ev: [MazeEvent] = []
        // Plays owed to hazards come off first, in seat order.
        for i in tokens.indices where tokens[i].owed > 0 {
            let n = tokens[i].owed
            tokens[i].owed = 0
            let lost = burnPlays(i, n)
            ev.append(.playsOwed(seat: i, lost: lost, owed: tokens[i].owed))
        }
        let stuck = stuckCheck()
        ev += stuck
        // A stuck duel starts the hand's first turn when it ends.
        if stuck.contains(where: { if case .duelStart = $0 { true } else { false } }) { return ev }
        return ev + nextTurn(after: dealer)
    }

    // MARK: Stuck

    /// maze.md › Stuck: a seat whose cost to the goal hasn't dropped since the last hand started.
    /// One event a hand at most: two or more stuck, the two furthest duel; one, behind a door
    /// another seat closed, duels the closer; one, any other way, the maze stirs for it.
    mutating func stuckCheck() -> [MazeEvent] {
        let f = costField()
        var stuck: [Int] = []
        for i in tokens.indices {
            if let was = tokens[i].handStartCost, f[tokens[i].pos] >= was { stuck.append(i) }
        }
        for i in tokens.indices { tokens[i].handStartCost = f[tokens[i].pos] }
        guard config.plot.on, !stuck.isEmpty else { return [] }
        stuck = stuck.enumerated().sorted { a, b in f[tokens[a.element].pos] != f[tokens[b.element].pos] ? f[tokens[a.element].pos] > f[tokens[b.element].pos] : a.offset < b.offset }.map(\.element)
        if stuck.count >= 2 { return startDuel(stuck[0], stuck[1], why: "stuck", walker: nil) }
        let p = stuck[0], way = wayAhead(p, field: f)
        if let k = way.door, let q = board.passages[k]?.closedBy, q != p, q < tokens.count { return startDuel(p, q, why: "stuck", walker: nil) }
        let opts = openings(p, way: way, field: f)
        guard !opts.isEmpty else { return [] }
        let o = dice.pick(opts.map { o in (o, config.plot.openings.entries.first { $0.0 == o }!.1) }, stream: "maze.plot", purpose: "plot")
        let (cell, passage) = open(p, o, way: way, field: f)
        return [.stir(seat: p, opening: o, cell: cell, passage: passage)]
    }

    /// Walls beside a seat whose way round, through passable passages, is 1 to `shiftMaxRound` steps.
    func shiftable(_ p: Int) -> [Int] {
        let at = tokens[p].pos, d = board.distances(from: at)
        return board.neighbours(at).filter { board.key(at, $0).map { board.passages[$0] == nil } ?? false && d[$0] > 0 && d[$0] <= config.plot.shiftMaxRound }
    }

    /// The openings that can happen for a seat, in `plot.openings` order.
    func openings(_ p: Int, way: (cells: [Int], keys: [Int], door: Int?), field f: [Int]) -> [String] {
        config.plot.openings.entries.map(\.0).filter {
            switch $0 {
            case "fade": way.door != nil
            case "star": way.cells.count > config.plot.starMinWay
            default: !shiftable(p).isEmpty
            }
        }
    }

    /// Applies an opening: the cell a star fell on, or the passage that faded, broke or opened.
    mutating func open(_ p: Int, _ o: String, way: (cells: [Int], keys: [Int], door: Int?), field f: [Int]) -> (Int?, [Int]?) {
        func pair(_ k: Int) -> [Int] { let (a, b) = board.cells(ofKey: k); return [a, b] }
        switch o {
        case "fade":
            let k = way.door!
            var d = board.passages[k]!
            d.suit = nil; d.strength = d.damage + (d.left + 1) / 2
            board.passages[k] = d
            return (nil, pair(k))
        case "break":
            let k = way.door!
            board.passages[k]!.kind = .open; board.passages[k]!.broken = true
            return (nil, pair(k))
        case "star":
            let c = way.cells[min(config.plot.starAhead, way.cells.count - 1)]
            if !board.stars.contains(c) { board.stars.append(c) }
            return (c, nil)
        default:
            let at = tokens[p].pos
            let n = shiftable(p).enumerated().min { a, b in f[a.element] != f[b.element] ? f[a.element] < f[b.element] : a.offset < b.offset }!.element
            let k = board.key(at, n)!
            board.passages[k] = Passage(.open)
            board.findPockets()
            return (nil, pair(k))
        }
    }

    // MARK: Duels

    /// Each seat's 4 cards for a duel: its kept hand, or 4 dealt from the rest of the standard deck
    /// (by card ID, less both hands, shuffled on `maze.duel`, purpose `duel_deal`) when it has none
    /// or, for the second seat, when it shares a card with the first's. Shuffles only when one deals.
    mutating func duelHands(_ p: Int, _ q: Int) -> [[Card]] {
        var a: [Card]? = tokens[p].kept.count == 4 ? tokens[p].kept : nil
        var b: [Card]? = tokens[q].kept.count == 4 ? tokens[q].kept : nil
        if let x = a, let y = b, y.contains(where: { c in x.contains { $0.id == c.id } }) { b = nil }
        if a == nil || b == nil {
            let held = Set((a ?? []).map(\.id) + (b ?? []).map(\.id))
            var deck = (0..<52).filter { !held.contains($0) }.map { Card(standard: $0) }
            dice.shuffle(&deck, stream: "maze.duel", purpose: "duel_deal")
            if a == nil { a = Array(deck.prefix(4)); deck.removeFirst(4) }
            if b == nil { b = Array(deck.prefix(4)) }
        }
        return [a!, b!]
    }

    mutating func startDuel(_ p: Int, _ q: Int, why: String, walker: Int?) -> [MazeEvent] {
        let n = tokens.count
        func after(_ x: Int) -> Int { (x - dealer - 1 + 2 * n) % n }
        let lead = after(q) < after(p) ? 1 : 0
        let hands = duelHands(p, q)
        duel = Duel(why: why, seats: [p, q], lead: lead, game: 1, peg: PegPlay(hands: hands, lead: lead, scoring: config.duel.peg), walker: walker)
        return [.duelStart(why: why, seats: [p, q], lead: [p, q][lead], game: 1, hands: hands.map { $0.map(CardRef.init) })] + runDuel()
    }

    func pegEvents(_ e: [PegEvent], _ seats: [Int]) -> [MazeEvent] {
        e.compactMap {
            switch $0 {
            case .played(let k, let c, let count, let scores): .duelCard(seat: seats[k], card: CardRef(c), count: count, scores: scores)
            case .go(let k): .duelGo(seat: seats[k])
            case .goPoint(let k, let pts, let count): .duelPoint(seat: seats[k], kind: "go", points: pts, count: count)
            }
        }
    }

    /// Bots' cards until a person must play, or the duel's game is over; then a tie plays again
    /// once with the other lead, and a second tie goes to a coin (`maze.duel`, purpose `duel_coin`).
    mutating func runDuel() -> [MazeEvent] {
        var ev: [MazeEvent] = []
        while var d = duel {
            if !d.peg.over {
                let k = d.peg.turn
                if people[d.seats[k]] { return ev }
                ev += pegEvents(d.peg.play(d.peg.botCard()!) ?? [], d.seats)
                duel = d
                continue
            }
            let sc = d.peg.scores
            d.scores.append(sc)
            if sc[0] == sc[1] && d.game == 1 {
                let hands = duelHands(d.seats[0], d.seats[1])
                d.game = 2
                d.peg = PegPlay(hands: hands, lead: 1 - d.lead, scoring: config.duel.peg)
                duel = d
                ev.append(.duelStart(why: d.why, seats: d.seats, lead: d.seats[1 - d.lead], game: 2, hands: hands.map { $0.map(CardRef.init) }))
                continue
            }
            var coin = false, wi: Int
            if sc[0] != sc[1] { wi = sc[0] > sc[1] ? 0 : 1 } else { coin = true; wi = dice.pick([(0, 50), (1, 50)], stream: "maze.duel", purpose: "duel_coin") }
            let w = d.seats[wi], l = d.seats[1 - wi]
            var opened: String?
            if d.why == "stuck" {
                let f = costField(), way = wayAhead(w, field: f)
                if way.door != nil { opened = "break"; _ = open(w, "break", way: way, field: f) }
                else {
                    let opts = openings(w, way: way, field: f)
                    if !opts.isEmpty {
                        let o = dice.pick(opts.map { o in (o, config.plot.openings.entries.first { $0.0 == o }!.1) }, stream: "maze.duel", purpose: "duel_open")
                        opened = o; _ = open(w, o, way: way, field: f)
                    }
                }
            }
            var took: Int?
            if !tokens[l].plays.isEmpty {
                let t = tokens[l].plays.removeFirst()
                took = t.id
                tokens[w].plays = Plays.sortBiggestFirst(tokens[w].plays + [t])
            }
            duel = nil
            ev.append(.duelEnd(why: d.why, seats: d.seats, scores: d.scores, winner: w, coin: coin, took: took, opened: opened))
            // After a stuck duel the hand's first turn starts; after a landing duel the walker's turn goes on.
            if let s = d.walker { if turnOver(s) { ev += nextTurn(after: s) } } else { ev += nextTurn(after: dealer) }
        }
        return ev
    }

    /// The next seat after this one with a play left takes a turn; with none, the hand is done.
    mutating func nextTurn(after s: Int) -> [MazeEvent] {
        played = false; jokerUsed = false
        let n = tokens.count
        for k in 1...n {
            let q = (s + k) % n
            if !tokens[q].plays.isEmpty { turn = q; return [.mazeTurn(seat: q, hand: hand)] }
        }
        turn = nil
        return [.mazeHandEnd(hand: hand, costs: tokens.indices.map(cost))]
    }

    /// The seat whose action this is: only the seat whose turn it is may act.
    mutating func apply(_ action: MazeAction, by seat: Int?) throws -> [MazeEvent] {
        guard winner == nil else { throw IllegalAction("the game is over") }
        if case .duelCard(let ref) = action {
            guard var d = duel, !d.peg.over, seat == nil || seat == d.seats[d.peg.turn], let c = d.peg.legal(d.peg.turn).first(where: { $0.id == ref.id }) else { throw IllegalAction("not a card to play in the duel") }
            let e = pegEvents(d.peg.play(c) ?? [], d.seats)
            duel = d
            return e + runDuel()
        }
        guard duel == nil else { throw IllegalAction("a duel is being played") }
        guard let s = turn, seat == nil || seat == s else { throw IllegalAction("it isn't that seat's turn") }
        func play(_ id: Int) throws -> MazePlay {
            guard !played else { throw IllegalAction("this turn's play is used") }
            guard let p = tokens[s].plays.first(where: { $0.id == id }) else { throw IllegalAction("no such play left") }
            return p
        }
        func use(_ id: Int) { tokens[s].plays.removeAll { $0.id == id }; played = true }
        var ev: [MazeEvent] = []
        switch action {
        case .mazeWalk(let id, let ways):
            let p = try play(id)
            use(id)
            let f = costField()
            let w = walk(s, steps: p.steps, suit: p.suit, reach: reachOn(s), ways: ways ?? [], field: f, hazardAt: hazardAt)
            ev.append(.walk(seat: s, play: id, steps: p.steps, path: w.path, junctions: w.junctions, doors: w.doors, stopped: w.stopped, key: w.key, end: w.end, won: w.won, reach: reachOn(s)))
            tokens[s].reach = false
            if w.won {
                winner = s
                ev.append(.mazeEnd(winner: s, reason: "goal", costs: tokens.indices.map(cost)))
                return ev
            }
            ev += afterWalk(s, w)
        case .mazeClose(let id, let cells):
            let p = try play(id)
            guard let suit = p.suit else { throw IllegalAction("closing a door takes a play with a suit") }
            guard cells.count == 2, let k = board.key(cells[0], cells[1]), canClose(s, key: k) else { throw IllegalAction("that passage can't be closed") }
            for q in tokens.indices where q != s && wayAhead(q).keys.contains(k) && !blocked.contains([s, q]) { blocked.append([s, q]) }
            use(id)
            var d = board.passages[k]!
            d.kind = .door; d.strength = max(config.close.min, (p.steps * config.close.mulPercent + 50) / 100); d.damage = 0; d.suit = suit; d.closedBy = s; d.broken = false
            board.passages[k] = d
            tokens[s].closed += 1
            ev.append(.doorClosed(seat: s, play: id, passage: [min(cells[0], cells[1]), max(cells[0], cells[1])], suit: suit, strength: d.strength))
        case .mazeFlip(let id, let letter):
            _ = try play(id)
            guard let sw = Self.letters.firstIndex(of: letter), canFlip(sw) else { throw IllegalAction("that switch can't be flipped this hand") }
            use(id)
            board.switches[sw].flipped = hand
            flip(sw)
            ev.append(.switchFlipped(seat: s, play: id, letter: letter))
        case .mazeJoker(let kind, let target, let cell, let passage):
            guard jokerUsed == false else { throw IllegalAction("one joker a turn") }
            guard tokens[s].jokers[kind, default: 0] > 0 else { throw IllegalAction("no \(kind) to use") }
            ev += try useJoker(s, kind, target: target, cell: cell, passage: passage)
            tokens[s].jokers[kind, default: 0] -= 1
            jokerUsed = true
        case .mazeEndTurn:
            // A person ends the turn without the joker it could still play.
            guard played else { throw IllegalAction("a turn uses a play first") }
            return nextTurn(after: s)
        case .duelCard: break
        }
        if duel != nil { return ev }
        if winner == nil && turnOver(s) { ev += nextTurn(after: s) }
        return ev
    }

    /// The turn ends after its play, unless a person may still play a joker: one this turn hasn't
    /// used, with a swapper, bomb, burn or (with no reach on) reach in hand. `mazeEndTurn` ends it then.
    func turnOver(_ s: Int) -> Bool { played && (jokerUsed || !people[s] || !canStillJoker(s)) }

    public func canStillJoker(_ s: Int) -> Bool {
        !jokerUsed && ["swapper", "bomb", "burn", "reach"].contains { tokens[s].jokers[$0, default: 0] > 0 && !($0 == "reach" && tokens[s].reach) }
    }

    /// What follows a walk that didn't reach the goal (maze.md › Walking, 8): hazards go off in the
    /// order passed, then a star on the end cell gives a joker.
    mutating func afterWalk(_ s: Int, _ w: Walk) -> [MazeEvent] {
        var ev: [MazeEvent] = []
        for c in w.hazards {
            guard let i = hazards.firstIndex(where: { $0.cell == c }) else { continue }
            let h = hazards.remove(at: i)
            let landed = c == w.end
            let r = h.kind == "mine" ? config.hazards.mine : config.hazards.fire
            let range = landed ? r.land : r.pass
            let n = range[0] + dice.below(range[1] - range[0] + 1, stream: "maze.burn", purpose: landed ? "burn_land" : "burn_pass")
            let lost = burnPlays(s, n)
            ev.append(.hazardHit(seat: s, kind: h.kind, cell: c, landed: landed, lose: n, lost: lost, owed: tokens[s].owed))
        }
        if let i = board.stars.firstIndex(of: w.end) {
            board.stars.remove(at: i)
            let j = dice.pick(config.jokers.starOdds.entries, stream: "maze.star", purpose: "star")
            tokens[s].jokers[j, default: 0] += 1
            ev.append(.star(seat: s, cell: w.end, joker: j))
        }
        // Landing on another token's cell (not the start) starts a duel, once a pair a hand.
        if config.duel.landing && w.landed && w.end != board.start,
           let q = tokens.indices.first(where: { $0 != s && tokens[$0].pos == w.end && !(config.duel.oncePerPairPerRound && met.contains([min(s, $0), max(s, $0)])) }) {
            met.append([min(s, q), max(s, q)])
            ev += startDuel(s, q, why: "landing", walker: s)
        }
        return ev
    }

    /// Takes n plays at random from those left (stream `maze.burn`, purpose `burn_play` each); what
    /// it can't take is owed. Returns the ids lost.
    mutating func burnPlays(_ s: Int, _ n: Int) -> [Int] {
        var lost: [Int] = []
        while lost.count < n && !tokens[s].plays.isEmpty {
            let k = dice.below(tokens[s].plays.count, stream: "maze.burn", purpose: "burn_play")
            lost.append(tokens[s].plays.remove(at: k).id)
        }
        tokens[s].owed += n - lost.count
        return lost
    }

    public func reachOn(_ s: Int) -> Bool { tokens[s].reach }
    public func hazardAt(_ c: Int) -> Bool { hazards.contains { $0.cell == c } }

    // MARK: Power jokers

    /// Doors a bomb can reach: either end within `targetRange` steps of the seat through passable
    /// passages. By passage key, in key order.
    public func bombDoors(_ s: Int) -> [Int] {
        let d = board.distances(from: tokens[s].pos)
        return board.doors.map(\.key).filter { k in let (a, b) = board.cells(ofKey: k); return (0...config.jokers.targetRange).contains(d[a]) || (0...config.jokers.targetRange).contains(d[b]) }
    }

    /// Cells a burn or a mine can go on: the first `targetRange` cells of each other seat's way, in
    /// seat order, less the start, the goal, a cell with a token or a hazard, each once.
    public func hazardCells(_ s: Int, field f: [Int]? = nil) -> [Int] {
        let f = f ?? costField()
        var out: [Int] = []
        for q in tokens.indices where q != s {
            for c in wayAhead(q, field: f).cells.prefix(config.jokers.targetRange)
            where c != board.goal && c != board.start && !hazardAt(c) && !tokens.contains(where: { $0.pos == c }) && !out.contains(c) { out.append(c) }
        }
        return out
    }

    public func canSwap(_ s: Int, _ q: Int) -> Bool { s != q && q >= 0 && q < tokens.count && !swaps.contains([min(s, q), max(s, q)]) }

    mutating func useJoker(_ s: Int, _ kind: String, target: Int?, cell: Int?, passage: [Int]?) throws -> [MazeEvent] {
        switch kind {
        case "swapper":
            guard let q = target, canSwap(s, q) else { throw IllegalAction("swap with another seat, not the same pair twice a hand") }
            swaps.append([min(s, q), max(s, q)])
            let a = tokens[s].pos
            tokens[s].pos = tokens[q].pos; tokens[q].pos = a
            for i in [s, q] { tokens[i].from = nil; tokens[i].atDoor = false }
            return [.swapped(seat: s, target: q, cells: [tokens[s].pos, tokens[q].pos])]
        case "bomb" where passage != nil:
            let cells = passage!
            guard cells.count == 2, let k = board.key(cells[0], cells[1]), bombDoors(s).contains(k) else { throw IllegalAction("bomb a door within reach") }
            var d = board.passages[k]!
            let opened = d.left <= config.jokers.bombPower
            if opened { d.kind = .open; d.broken = true } else { d.damage += config.jokers.bombPower }
            board.passages[k] = d
            return [.doorBombed(seat: s, passage: [min(cells[0], cells[1]), max(cells[0], cells[1])], opened: opened, left: opened ? 0 : d.left)]
        case "bomb", "burn":
            guard let c = cell, hazardCells(s).contains(c) else { throw IllegalAction("a hazard goes on another seat's way, near them") }
            let h = Hazard(cell: c, kind: kind == "bomb" ? "mine" : "fire", seat: s)
            hazards.append(h)
            return [.hazardSet(seat: s, kind: h.kind, cell: c)]
        case "reach":
            guard !tokens[s].reach else { throw IllegalAction("a reach is already on") }
            tokens[s].reach = true
            return [.reachOn(seat: s)]
        default:
            throw IllegalAction("\(kind) has no use on the maze")
        }
    }

    /// The cap (maze.md › Round cap): the cheapest to the goal, then the most grid steps over the
    /// game, then the first in turn order from the seat after the last dealer.
    mutating func capWinner() -> MazeEvent {
        let costs = tokens.indices.map(cost), n = tokens.count
        let order = (1...n).map { (dealer + $0) % n }
        let w = order.min { a, b in costs[a] != costs[b] ? costs[a] < costs[b] : tokens[a].gridSteps > tokens[b].gridSteps }!
        winner = w
        return .mazeEnd(winner: w, reason: "cap", costs: costs)
    }
}

/// A binary min-heap of (cost, cell), for the cost field.
struct MinHeap {
    private var k: [Int] = [], v: [Int] = []
    mutating func push(_ key: Int, _ value: Int) {
        k.append(key); v.append(value)
        var i = k.count - 1
        while i > 0 { let p = (i - 1) / 2; if k[p] <= k[i] { break }; k.swapAt(p, i); v.swapAt(p, i); i = p }
    }
    mutating func pop() -> (Int, Int)? {
        guard !k.isEmpty else { return nil }
        let top = (k[0], v[0])
        k[0] = k[k.count - 1]; v[0] = v[v.count - 1]; k.removeLast(); v.removeLast()
        var i = 0
        while true {
            var c = 2 * i + 1
            if c >= k.count { break }
            if c + 1 < k.count && k[c + 1] < k[c] { c += 1 }
            if k[c] >= k[i] { break }
            k.swapAt(c, i); v.swapAt(c, i); i = c
        }
        return top
    }
}
