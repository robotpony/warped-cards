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
    case mazeEndTurn

    /// Every maze action's name, as records write it.
    public static let names: Set<String> = ["mazeWalk", "mazeClose", "mazeFlip", "mazeEndTurn"]
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
    /// The game's winner: `goal` (the first token in) or `cap` (cheapest to the goal after the last hand).
    case mazeEnd(winner: Int, reason: String, costs: [Int])

    /// Every maze event's name, as records write it.
    public static let names: Set<String> = ["mazeBuilt", "mazeTurn", "walk", "doorClosed", "switchFlipped", "mazeHandEnd", "mazeEnd"]
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
    public func preview(seat: Int, play id: Int, ways: [MazeWay] = []) -> (walk: Walk, cost: Int)? {
        guard let p = tokens[seat].plays.first(where: { $0.id == id }) else { return nil }
        var copy = self
        let w = copy.walk(seat, steps: p.steps, suit: p.suit, reach: copy.reachOn(seat), ways: ways, field: costField(), hazardAt: copy.hazardAt)
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
        return nextTurn(after: dealer)
    }

    /// The next seat after this one with a play left takes a turn; with none, the hand is done.
    mutating func nextTurn(after s: Int) -> [MazeEvent] {
        played = false
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
        case .mazeEndTurn:
            guard played else { throw IllegalAction("a turn uses a play first") }
        }
        if winner == nil && turnOver(s) { ev += nextTurn(after: s) }
        return ev
    }

    /// The turn ends after its play, unless a person may still play a joker.
    func turnOver(_ s: Int) -> Bool { played }

    /// What follows a walk that didn't reach the goal: hazards, a star, a landing duel.
    mutating func afterWalk(_ s: Int, _ w: Walk) -> [MazeEvent] { [] }

    func reachOn(_ s: Int) -> Bool { false }
    func hazardAt(_ c: Int) -> Bool { false }

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
