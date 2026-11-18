// The maze's board (maze.md › The board; engine.md › The maze › The board): a seeded square grid
// carved as a tree, a golden path from the start to the goal, doors, ways round and shortcuts,
// switches, pockets, junction arrows and stars. Built once a game from the `maze` stream. Every
// search here keeps the spec's order (up, right, down, left), so every build makes the same maze.
import GameKit

/// Directions, in the spec's order: up, right, down, left (y grows downward).
public enum Dir: Int, Codable, Sendable, CaseIterable {
    case up, right, down, left
    public var dx: Int { [0, 1, 0, -1][rawValue] }
    public var dy: Int { [-1, 0, 1, 0][rawValue] }
    public var back: Dir { Dir(rawValue: (rawValue + 2) % 4)! }
}

/// What a passage between two side-by-side cells is.
public struct Passage: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case open, door, `switch` }
    public var kind: Kind
    // A door.
    public var strength = 0, damage = 0
    public var suit: String?
    public var closedBy: Int?
    /// A shortcut's door, and the steps it saves.
    public var shortcut = false
    public var saves: Int?
    /// Part of a variant (a way round or a shortcut): opened by generation, or its entrance.
    public var variant = false
    /// A switch: its index (A is 0), and whether it's on (passable).
    public var sw: Int?
    public var on = false
    /// A door that broke, open for good.
    public var broken = false
    public var left: Int { strength - damage }
    public init(_ kind: Kind) { self.kind = kind }
    public var passable: Bool { kind != .switch || on }
}

/// A switch: two passages, one on and one off, swapped by a flip.
public struct MazeSwitch: Codable, Sendable, Equatable {
    /// The golden passage (on at the start) and the wall it pairs with (off), as passage keys.
    public let a: Int, b: Int
    /// The hand it was last flipped in, or 0.
    public var flipped = 0
}

/// A variant: where it leaves the golden path and rejoins it, and what it is.
public struct MazeVariant: Codable, Sendable, Equatable {
    /// The golden door it goes round (its path index), or 0 for a shortcut.
    public let door: Int
    public let from: Int, to: Int, len: Int, span: Int
    /// `round_door` (a door of another suit), `round_free` (no door) or `shortcut`.
    public let kind: String
}

public struct MazeBoard: Codable, Sendable, Equatable {
    public let w: Int
    public let start: Int, goal: Int
    /// The golden path, start to goal: `length` + 1 cells.
    public let route: [Int]
    public var variants: [MazeVariant] = []
    public var switches: [MazeSwitch] = []
    /// Every passage, by key: cell × 2 for the one to its right, cell × 2 + 1 for the one below.
    /// A wall is none.
    public var passages: [Passage?]
    /// Exits into a pocket, by cell × 4 + direction; and cells on a loop.
    public var dead: [Bool]
    public var onLoop: [Bool]
    /// Each cell's junction arrow (a direction); up for a cell that has none.
    public var arrow: [Dir]
    /// Cells with a star, in the order placed.
    public var stars: [Int] = []

    public var n: Int { w * w }
    public func x(_ c: Int) -> Int { c % w }
    public func y(_ c: Int) -> Int { c / w }

    // MARK: Geometry

    /// The cell one step that way, or nil at the grid's edge.
    public func step(_ c: Int, _ d: Dir) -> Int? {
        let a = x(c) + d.dx, b = y(c) + d.dy
        return a < 0 || b < 0 || a >= w || b >= w ? nil : b * w + a
    }
    /// A cell's neighbours, in direction order, skipping the edge.
    public func neighbours(_ c: Int) -> [Int] { Dir.allCases.compactMap { step(c, $0) } }
    /// The key of the passage leaving a cell that way, or nil at the edge.
    public func key(_ c: Int, _ d: Dir) -> Int? {
        guard let o = step(c, d) else { return nil }
        switch d {
        case .right: return c * 2
        case .down: return c * 2 + 1
        case .left: return o * 2
        case .up: return o * 2 + 1
        }
    }
    /// The key of the passage between two side-by-side cells.
    public func key(_ a: Int, _ b: Int) -> Int? { dir(a, b).flatMap { key(a, $0) } }
    /// The two cells of a passage key, lower first.
    public func cells(ofKey k: Int) -> (Int, Int) { let c = k / 2; return (c, k % 2 == 0 ? c + 1 : c + w) }
    public func dir(_ a: Int, _ b: Int) -> Dir? { Dir.allCases.first { step(a, $0) == b } }
    public func passage(_ c: Int, _ d: Dir) -> Passage? { key(c, d).flatMap { passages[$0] } }
    public func manhattan(_ a: Int, _ b: Int) -> Int { abs(x(a) - x(b)) + abs(y(a) - y(b)) }

    /// The ways out of a cell a token can take: open passages, doors and switches that are on.
    public func exits(_ c: Int) -> [Dir] { Dir.allCases.filter { passage(c, $0)?.passable == true } }
    /// Exits that aren't pockets.
    public func liveExits(_ c: Int) -> [Dir] { exits(c).filter { !dead[c * 4 + $0.rawValue] } }

    /// Steps from a cell to every cell, through passages that pass the test (breadth first, in
    /// direction order); -1 where it can't reach.
    public func distances(from: Int, _ pass: (Passage) -> Bool = { $0.passable }) -> [Int] {
        var d = [Int](repeating: -1, count: n), q = [from]
        d[from] = 0
        var h = 0
        while h < q.count {
            let c = q[h]; h += 1
            for dir in Dir.allCases {
                guard let o = step(c, dir), d[o] < 0, let p = passage(c, dir), pass(p) else { continue }
                d[o] = d[c] + 1; q.append(o)
            }
        }
        return d
    }

    // MARK: Pockets

    /// Marks pockets (the bridges of the open maze, found depth first from the goal: each one's
    /// exit away from the goal) and the cells on a loop. Run again after a flip or an opened wall.
    public mutating func findPockets() {
        dead = [Bool](repeating: false, count: n * 4); onLoop = [Bool](repeating: false, count: n)
        var disc = [Int](repeating: -1, count: n), low = [Int](repeating: 0, count: n), par = [Int](repeating: -1, count: n), pd = [Int](repeating: 0, count: n)
        var t = 0
        var stack: [(Int, Int)] = [(goal, 0)]
        disc[goal] = t; low[goal] = t; t += 1
        while let top = stack.last {
            let u = top.0
            if top.1 < 4 {
                let d = top.1
                stack[stack.count - 1].1 += 1
                guard let p = passage(u, Dir(rawValue: d)!), p.passable, let v = step(u, Dir(rawValue: d)!) else { continue }
                if disc[v] < 0 { disc[v] = t; low[v] = t; t += 1; par[v] = u; pd[v] = d; stack.append((v, 0)) }
                else if v != par[u] { low[u] = min(low[u], disc[v]) }
            } else {
                stack.removeLast()
                let p = par[u]
                guard p >= 0 else { continue }
                low[p] = min(low[p], low[u])
                if low[u] > disc[p] { dead[p * 4 + pd[u]] = true } else { onLoop[u] = true; onLoop[p] = true }
            }
        }
    }

    // MARK: Generation

    public static func makeLength(_ c: MazeConfig.Board) -> Int {
        var w = 1
        while w * w * 100 < c.length * c.sizePercent { w += 1 }
        return w
    }

    /// Builds the maze for a game seed, drawing only from the `maze` stream of `dice`.
    public static func generate(_ c: MazeConfig.Board, dice: inout Dice) -> MazeBoard {
        func below(_ n: Int, _ purpose: String) -> Int { dice.below(n, stream: "maze", purpose: purpose) }
        func shuffle<T>(_ list: inout [T], _ purpose: String) { dice.shuffle(&list, stream: "maze", purpose: purpose) }
        let suits = ["S", "H", "D", "C"]
        var w = makeLength(c), tries = 0
        var m: MazeBoard!
        // 1, 2. Carve a tree from the start; pick a goal exactly `length` away, or carve again.
        while true {
            tries += 1
            if tries % c.widenEvery == 0 { w += 1 }
            let start = (w - 1) * w
            var b = MazeBoard(w: w, start: start, goal: -1, route: [], passages: [Passage?](repeating: nil, count: w * w * 2),
                              dead: [], onLoop: [], arrow: [Dir](repeating: .up, count: w * w))
            var seen = [Bool](repeating: false, count: w * w), stack = [start]
            seen[start] = true
            while let cur = stack.last {
                let open = b.neighbours(cur).filter { !seen[$0] }
                if open.isEmpty { stack.removeLast(); continue }
                let o = open[below(open.count, "carve")]
                b.passages[b.key(cur, o)!] = Passage(.open); seen[o] = true; stack.append(o)
            }
            let dist = b.distances(from: start)
            let exact = (0..<(w * w)).filter { dist[$0] == c.length }
            if !exact.isEmpty {
                let goal = exact[below(exact.count, "goal")]
                m = MazeBoard(w: w, start: start, goal: goal, route: [], passages: b.passages, dead: [], onLoop: [], arrow: b.arrow)
                break
            }
        }
        let n = w * w
        // 4. Every wall between two cells, in cell order (right, then below), shuffled.
        var walls: [(Int, Int)] = []
        for i in 0..<n { for o in m.neighbours(i) where i < o && m.passages[m.key(i, o)!] == nil { walls.append((i, o)) } }
        shuffle(&walls, "walls")
        // 3. The golden path: the tree's one way from the start to the goal.
        let toGoal = m.distances(from: m.goal)
        var route = [m.start], cur = m.start
        while cur != m.goal {
            let c0 = cur
            cur = m.neighbours(c0).first { toGoal[$0] == toGoal[c0] - 1 && m.passages[m.key(c0, $0)!] != nil }!
            route.append(cur)
        }
        m = MazeBoard(w: w, start: m.start, goal: m.goal, route: route, passages: m.passages, dead: [], onLoop: [], arrow: m.arrow)
        let length = route.count - 1
        // 5. Each cell off the path: the path index it hangs from, and its depth.
        var attach = [Int](repeating: -1, count: n), depth = [Int](repeating: 0, count: n), parent = [Int](repeating: -1, count: n)
        var q: [Int] = []
        for (k, cell) in route.enumerated() { attach[cell] = k; q.append(cell) }
        var h = 0
        while h < q.count {
            let a = q[h]; h += 1
            for o in m.neighbours(a) where attach[o] < 0 && m.passages[m.key(a, o)!] != nil {
                attach[o] = attach[a]; depth[o] = depth[a] + 1; parent[o] = a; q.append(o)
            }
        }
        func branch(_ x0: Int) -> [Int] { var out: [Int] = [], x = x0; while parent[x] >= 0 { out.append(x); x = parent[x] }; return out }
        // 6. Variant candidates, in walls-list order.
        struct Cand { let a: Int, b: Int, i: Int, j: Int, len: Int, span: Int; var save: Int { span - len } }
        var cand: [Cand] = []
        for (u, v) in walls {
            guard attach[u] >= 0, attach[v] >= 0, attach[u] != attach[v] else { continue }
            let (a, b) = attach[u] < attach[v] ? (u, v) : (v, u)
            let i = attach[a], j = attach[b], len = depth[a] + depth[b] + 1, span = j - i
            if len + span < c.minLoop || span < c.variantSpan[0] || span > c.variantSpan[1] || i < c.pathMargin || j > length - c.pathMargin { continue }
            cand.append(Cand(a: a, b: b, i: i, j: j, len: len, span: span))
        }
        var takenRange: [(Int, Int)] = [], takenCells = Set<Int>()
        func free(_ v: Cand) -> Bool {
            !takenRange.contains { v.i < $0.1 + c.variantGap && v.j > $0.0 - c.variantGap } && !(branch(v.a) + branch(v.b)).contains { takenCells.contains($0) }
        }
        func openVariant(_ v: Cand, _ door: Passage?) {
            var p = Passage(.open); p.variant = true
            m.passages[m.key(v.a, v.b)!] = p
            // The variant's door sits on its entrance, beside the golden path.
            let up = branch(v.a)
            let entry = up.isEmpty ? m.key(v.a, v.b)! : m.key(up.last!, route[v.i])!
            if var d = door { d.variant = true; m.passages[entry] = d }
            takenRange.append((v.i, v.j)); for x in branch(v.a) + branch(v.b) { takenCells.insert(x) }
        }
        func door(_ strength: Int, _ suit: String?) -> Passage { var d = Passage(.door); d.strength = strength; d.suit = suit; return d }
        // 7. Golden doors, each at its even spot or inside a way round near it.
        var routeDoors: [Int] = []
        let slots = c.doors + 1
        for k in 1...max(1, c.doors) where c.doors > 0 {
            let t = (2 * k * length + slots) / (2 * slots)
            let gold = door(c.doorBase + c.doorStep * (k - 1), suits[below(4, "door_suit")])
            var best: (Cand, Int)?
            for v in cand where v.len * 100 >= v.span * c.roundMinPercent && v.len <= v.span + c.roundMaxExtra && free(v) {
                let at = min(v.j - 1, max(v.i + 2, t))
                guard abs(at - t) * slots * 100 <= c.roundNearPercent * length, !routeDoors.contains(at) else { continue }
                if best == nil || abs(at - t) < abs(best!.1 - t) { best = (v, at) }
            }
            let at = best?.1 ?? t
            m.passages[m.key(route[at - 1], route[at])!] = gold
            routeDoors.append(at)
            if let (v, _) = best {
                var d: Passage?
                if v.len < v.span + c.freeRoundExtra {
                    let others = suits.filter { $0 != gold.suit }
                    d = door(max(c.doorMinStrength, (gold.strength * c.roundDoorPercent + 50) / 100), others[below(3, "variant_suit")])
                }
                openVariant(v, d)
                m.variants.append(MazeVariant(door: at, from: v.i, to: v.j, len: v.len, span: v.span, kind: d != nil ? "round_door" : "round_free"))
            }
        }
        // 8. Shortcuts, in walls-list order, behind a suited door at the entrance.
        for v in cand {
            if m.variants.filter({ $0.door == 0 }).count >= c.shortcuts { break }
            if v.save < c.shortcutSave[0] || v.save > c.shortcutSave[1] || v.span > c.shortcutSpanMax || routeDoors.contains(where: { $0 > v.i && $0 <= v.j }) || !free(v) { continue }
            var d = door(max(c.doorMinStrength, (v.save + 1) / 2), suits[below(4, "variant_suit")])
            d.shortcut = true; d.saves = v.save
            openVariant(v, d)
            m.variants.append(MazeVariant(door: 0, from: v.i, to: v.j, len: v.len, span: v.span, kind: "shortcut"))
        }
        // 11. Switches: a golden passage from the middle of the path, paired with a wall near it.
        func joined() -> Bool {
            let k = m.switches.count
            for mask in 0..<(1 << k) {
                func pass(_ p: Passage) -> Bool { p.kind != .switch || (p.on != ((mask >> p.sw!) & 1 == 1)) }
                if m.distances(from: m.goal, pass).contains(where: { $0 < 0 }) { return false }
                if m.distances(from: m.start, { !$0.variant && pass($0) })[m.goal] * 100 < c.length * c.switchKeepPercent { return false }
            }
            return true
        }
        let cellsN = route.count
        var onRoute: [(Int, Int)] = []
        for k in (cellsN * c.switchFromPercent / 100)..<(cellsN * c.switchToPercent / 100) where k >= 1 { onRoute.append((route[k - 1], route[k])) }
        shuffle(&onRoute, "switch_edge")
        var used = Set<Int>()
        for (a, b) in onRoute {
            if m.switches.count >= c.switches { break }
            let ka = m.key(a, b)!
            guard let ea = m.passages[ka], ea.kind == .open, !used.contains(a), !used.contains(b) else { continue }
            var near = walls.filter { (p, q) in
                m.passages[m.key(p, q)!] == nil && ![p, q].contains { used.contains($0) || $0 == m.start || $0 == m.goal } && m.manhattan(p, a) <= c.switchNear
            }
            near = Array(near.prefix(c.switchWallsTried))
            shuffle(&near, "switch_wall")
            let sw = m.switches.count
            for (p, q) in near {
                let kb = m.key(p, q)!
                var on = ea; on.kind = .switch; on.sw = sw; on.on = true
                var off = Passage(.switch); off.sw = sw; off.on = false
                m.passages[ka] = on; m.passages[kb] = off
                m.switches.append(MazeSwitch(a: ka, b: kb))
                if joined() { for x in [a, b, p, q] { used.insert(x) }; break }
                m.switches.removeLast(); m.passages[kb] = nil; m.passages[ka] = ea
            }
        }
        // 12. Pockets.
        m.findPockets()
        // 13. Junction arrows, among the exits that aren't pockets.
        for i in 0..<n {
            let live = m.liveExits(i)
            if live.count >= 2 { m.arrow[i] = live[below(live.count, "junction")] }
        }
        // 14. Stars on the loops off the golden path.
        let onR = Set(route)
        var loopCells = (0..<n).filter { !onR.contains($0) && $0 != m.start && m.onLoop[$0] }
        shuffle(&loopCells, "prize_cells")
        m.stars = Array(loopCells.prefix((c.length + c.starsPerSteps / 2) / c.starsPerSteps))
        return m
    }

    /// The doors on the board, by passage key in key order.
    public var doors: [(key: Int, door: Passage)] { passages.enumerated().compactMap { k, p in p?.kind == .door ? (k, p!) : nil } }
}
