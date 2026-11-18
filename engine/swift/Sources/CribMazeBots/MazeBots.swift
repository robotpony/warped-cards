// Maze bots (maze.md › Bots; engine.md › Maze bots): each seat's choice on the maze, sent by the
// session as an action for that seat, so a record replays without them. Styles come from
// bots.json › maze. A bot uses its joker first, then its play; it draws no dice.
import CardKit
import CribMaze
import GameKit

public struct MazeBot: Sendable {
    public let style: MazeBots.Style
    public let bots: MazeBots

    public init(style: MazeBots.Style, bots: MazeBots) { self.style = style; self.bots = bots }
    /// A style from config by its id ("balanced", "racer", "timer", "closer", "jokers").
    public init?(config: Config, style id: String) {
        guard let b = config.bots.maze, let s = b.style(id) else { return nil }
        self.init(style: s, bots: b)
    }

    /// The bot's action for the seat to act: its duel card, a joker, or its play.
    public func choose(_ m: Maze) -> MazeAction {
        if let d = m.duel, let c = d.peg.botCard() { return .duelCard(card: CardRef(c)) }
        guard let s = m.turn else { return .mazeEndTurn }
        if m.played { return .mazeEndTurn }
        if style.jokers && !m.jokerUsed, let j = joker(m, s) { return j }
        return play(m, s)
    }

    /// The leader: the other seat cheapest to the goal, the first in seat order on a tie.
    func leader(_ m: Maze, _ s: Int, _ f: [Int], allowed: (Int) -> Bool = { _ in true }) -> Int? {
        m.tokens.indices.filter { $0 != s && allowed($0) }.min { f[m.tokens[$0].pos] < f[m.tokens[$1].pos] }
    }

    /// Its play: close a door before the leader, flip a switch, or walk.
    func play(_ m: Maze, _ s: Int) -> MazeAction {
        let plays = m.tokens[s].plays
        if style.walk == "biggest" { return .mazeWalk(play: plays[0].id, ways: nil) }
        let f = m.costField(), me = f[m.tokens[s].pos]
        if let lead = leader(m, s, f) {
            let l = f[m.tokens[lead].pos]
            let closeIf: Bool
            switch style.close {
            case "leaderFar": closeIf = l < me - style.closeLead! && l < style.closeNear!
            case "levelOrAhead": closeIf = l <= me + style.closeLead!
            default: closeIf = false
            }
            let suited = plays.filter { $0.suit != nil && $0.steps >= bots.closeMinSteps }
            if closeIf && suited.count >= bots.closeMinPlays, let k = closeSpot(m, s, lead, f) {
                let p = style.closePlay == "biggest" ? suited[0] : suited[suited.count / 2]
                let (a, b) = m.board.cells(ofKey: k)
                return .mazeClose(play: p.id, passage: [a, b])
            }
            if let gain = style.flipGain, !m.board.switches.isEmpty, plays.count > 1 {
                // A switch's gain: its own saving plus half the leader's loss, kept doubled as integers.
                var best: (Int, Int)?
                for sw in m.board.switches.indices where m.canFlip(sw) {
                    let g = m.costField(flipping: sw)
                    let twice = 2 * (me - g[m.tokens[s].pos]) + (g[m.tokens[lead].pos] - l)
                    if best == nil || twice > best!.1 { best = (sw, twice) }
                }
                if let (sw, twice) = best, twice >= 2 * gain { return .mazeFlip(play: plays[plays.count - 1].id, letter: Maze.letters[sw]) }
            }
        }
        return .mazeWalk(play: bestWalk(m, s, f).play, ways: nil)
    }

    /// The play whose walk leaves it cheapest (maze.md › Bots › Judging a walk), on the field before
    /// the walk; on a tie, the smaller play, then the first.
    public func bestWalk(_ m: Maze, _ s: Int, _ f: [Int], reach: Bool? = nil) -> (play: Int, value: Int) {
        var best: (Int, Int, Int)?   // id, value, steps
        let j = bots.judge
        for p in m.tokens[s].plays {
            guard let (w, _) = m.preview(seat: s, play: p.id, reach: reach, field: f) else { continue }
            var v: Int
            if w.won { v = Int.min / 2 } else {
                v = f[w.end] - (w.doors.contains { $0.broke } ? j.doorBreak : 0)
                for c in w.hazards {
                    guard let h = m.hazards.first(where: { $0.cell == c }) else { continue }
                    let landed = c == w.end
                    v += h.kind == "mine" ? (landed ? j.mineLand : j.minePass) : (landed ? j.fireLand : j.firePass)
                }
            }
            if best == nil || v < best!.1 || (v == best!.1 && p.steps < best!.2) { best = (p.id, v, p.steps) }
        }
        return (best!.0, best!.1)
    }

    /// Where to close before the leader: along its way, the first passage it could close from the
    /// `closeFrom`th step on, looking `closeLook` steps.
    func closeSpot(_ m: Maze, _ s: Int, _ lead: Int, _ f: [Int]) -> Int? {
        var cur = m.tokens[lead].pos
        for k in 0..<bots.closeLook where cur != m.board.goal {
            let next = m.board.neighbours(cur).filter { o in m.board.key(cur, o).flatMap { m.board.passages[$0] }?.passable == true }
                .enumerated().min { a, b in f[a.element] != f[b.element] ? f[a.element] < f[b.element] : a.offset < b.offset }?.element
            guard let n = next, f[n] < f[cur] else { return nil }
            let key = m.board.key(cur, n)!
            if k >= bots.closeFrom && m.canClose(s, key: key) { return key }
            cur = n
        }
        return nil
    }

    /// At most one joker a turn, in order: burn, reach, bomb, swapper (maze.md › Bots › Joker use).
    func joker(_ m: Maze, _ s: Int) -> MazeAction? {
        let t = m.tokens[s], f = m.costField(), me = f[t.pos], eager = style.eager == true
        func has(_ k: String) -> Bool { t.jokers[k, default: 0] > 0 }
        /// A hazard cell where the leader's biggest play would end, else on its way after its first cell.
        func target(_ lead: Int) -> Int? {
            let ok = m.hazardCells(s, field: f)
            if let big = m.tokens[lead].plays.first, let end = m.preview(seat: lead, play: big.id)?.walk.end, ok.contains(end) { return end }
            return m.wayAhead(lead, field: f).cells.prefix(10).dropFirst().first { ok.contains($0) }
        }
        if has("burn"), let lead = leader(m, s, f), eager || f[m.tokens[lead].pos] < me + style.burnBehind!, let c = target(lead) {
            return .mazeJoker(kind: "burn", target: nil, cell: c, passage: nil)
        }
        if has("reach"), !t.reach, t.plays.count > 1 {
            let without = bestWalk(m, s, f).value, with = bestWalk(m, s, f, reach: true).value
            if without - with >= style.reachSaves! { return .mazeJoker(kind: "reach", target: nil, cell: nil, passage: nil) }
        }
        if has("bomb") {
            let way = m.wayAhead(s, field: f)
            if let k = way.door, m.bombDoors(s).contains(k), let d = m.board.passages[k] {
                let suited = t.plays.contains { $0.suit != nil && $0.suit == d.suit }
                if d.left <= m.config.jokers.bombPower || !suited { let (a, b) = m.board.cells(ofKey: k); return .mazeJoker(kind: "bomb", target: nil, cell: nil, passage: [a, b]) }
            }
            if let lead = leader(m, s, f), eager || f[m.tokens[lead].pos] < me - style.mineLead!, let c = target(lead) {
                return .mazeJoker(kind: "bomb", target: nil, cell: c, passage: nil)
            }
        }
        if has("swapper"), let lead = leader(m, s, f, allowed: { m.canSwap(s, $0) }), f[m.tokens[lead].pos] + style.swapLead! < me {
            return .mazeJoker(kind: "swapper", target: lead, cell: nil, passage: nil)
        }
        return nil
    }
}
