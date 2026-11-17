// Match turn bots (engine.md › Bots). A bot sees the player's view and returns one
// action. Its only randomness is its own stream, "bot.<seat>". Bots count as
// already warned about cards left over, so start their turns with warned set.
import CribMaze
import GameKit

/// A set a bot found: positions in the order it would trace them, and their points.
public struct FoundSet: Sendable, Equatable {
    public let positions: [Pos]
    public let points: Int
}

public struct MatchBot: Sendable {
    public let level: BotsConfig.MatchLevel
    public let seat: Int
    public var stream: String { "bot.\(seat)" }
    /// When the bot plays a reach joker: only when stuck (the default), or as soon as it has one.
    /// The simulator's `--reach early` measures the second, closer to how a keen player might use it.
    public var reachEarly = false

    public init(level: BotsConfig.MatchLevel, seat: Int = 0) { self.level = level; self.seat = seat }

    /// A level from config by its id ("perfect", "strong", "medium", "weak").
    public init?(config: Config, id: String, seat: Int = 0) {
        guard let l = config.bots.match.first(where: { $0.id == id }) else { return nil }
        self.init(level: l, seat: seat)
    }

    /// The bot's next action. Only legal actions: a trace, a reach, a swap, a bomb or end turn.
    public func choose(_ turn: MatchTurn, dice: inout Dice) -> MatchAction {
        let s = turn.state
        // 0. With `reachEarly`, a reach joker first.
        if reachEarly, s.reaches.isEmpty, let source = specialSource("reach", s) { return .reach(source: source.pos) }
        // 1. The best set, if it scores.
        if let b = bestSet(turn, dice: &dice) { return .trace(positions: b.positions) }
        // 2. A reach joker, which may open a bigger set, before changing the board.
        if s.reaches.isEmpty, let source = specialSource("reach", s) { return .reach(source: source.pos) }
        // 3. A swapper, on the board first, then the tray.
        if let source = specialSource("swapper", s), let line = bestSwap(turn, excluding: source.pos, dice: &dice) {
            return .swap(line: line, source: source.pos)
        }
        // 4. A bomb, on the board first, then the tray, if the grid isn't empty.
        if let source = specialSource("bomb", s), !s.gridEmpty {
            var at: Pos?, most = -1
            for p in Board.grid where s.cells[p] != nil {
                let n = turn.blast(p).filter { s.cells[$0] != nil }.count
                if n > most { most = n; at = p }
            }
            if let at { return .bomb(target: at, source: source.pos) }
        }
        // 5. Nothing to do.
        return .endTurn
    }

    /// Where a special joker would be used from: the board (first in position order) or the tray.
    struct Source { let pos: Pos? }   // pos nil: the tray

    /// The source of a special joker, or nil when the bot has none.
    func specialSource(_ kind: String, _ s: MatchState) -> Source? {
        if let p = Board.grid.first(where: { s.cells[$0]?.kind == .special(kind) }) { return Source(pos: p) }
        return s.tray[kind, default: 0] > 0 ? Source(pos: nil) : nil
    }

    // MARK: Finding the best set

    /// The best set at this level that scores above 0, or nil.
    public func bestSet(_ turn: MatchTurn, dice: inout Dice) -> FoundSet? {
        level.search == "all" ? bestOfAll(turn) : bestTraced(turn, dice: &dice)
    }

    func scores(_ turn: MatchTurn, _ ps: [Pos]) -> Int? {
        guard turn.traceProblem(ps) == nil, let v = turn.value(of: ps), !v.count.combos.isEmpty, v.points > 0 else { return nil }
        return v.points
    }

    /// Perfect: every set in position order. Highest points, then the larger set, then the first found.
    func bestOfAll(_ turn: MatchTurn, only touching: Set<Pos>? = nil) -> FoundSet? {
        var best: FoundSet?
        for set in MatchTurn.sets(maxSize: turn.pickLimit) {
            if let t = touching, !set.contains(where: t.contains) { continue }
            guard let pts = scores(turn, set) else { continue }
            if let b = best, pts < b.points || (pts == b.points && set.count <= b.positions.count) { continue }
            best = FoundSet(positions: set, points: pts)
        }
        return best
    }

    /// The lower levels: random starting cards, paths of touching cards up to `depth`.
    /// Highest points wins; on a tie, the first found.
    func bestTraced(_ turn: MatchTurn, dice: inout Dice) -> FoundSet? {
        let s = turn.state
        var pos = (0..<Board.count).filter { p in s.cells[p].map { !$0.isSpecial } ?? false }
        guard !pos.isEmpty else { return nil }
        dice.shuffle(&pos, stream: stream, purpose: "starts")
        let fraction = level.starts ?? 1
        let n = max(1, Int((Double(pos.count) * fraction).rounded(.toNearestOrAwayFromZero)))
        // A reach joker lets every level look one card further for each extra card.
        let extra = turn.pickLimit - turn.config.rules.match.maxSet
        let depth = min((level.depth ?? turn.config.rules.match.maxSet) + extra, turn.pickLimit)
        var best: FoundSet?
        var path: [Pos] = []
        var mask: UInt32 = 0
        // A walk meets the same set in many orders; its points don't depend on the order.
        var memo: [UInt32: Int] = [:]   // set mask -> points, 0 for a set that doesn't score
        func walk() {
            if path.count >= 2 {
                let pts: Int
                if let m = memo[mask] { pts = m } else { pts = scores(turn, path) ?? 0; memo[mask] = pts }
                if pts > 0, best == nil || pts > best!.points { best = FoundSet(positions: path, points: pts) }
            }
            if path.count >= depth { return }
            // Next cards in the shuffled order, as the mock walks them.
            for p in pos where mask & (1 << UInt32(p)) == 0 && Board.touching(path.last!, p) {
                path.append(p); mask |= 1 << UInt32(p)
                walk()
                path.removeLast(); mask &= ~(1 << UInt32(p))
            }
        }
        for start in pos.prefix(n) {
            path = [start]; mask = 1 << UInt32(start)
            walk()
        }
        return best
    }

    // MARK: Swaps

    /// Every pair of touching grid cells: each cell, then its neighbours right, below,
    /// below-right and below-left. Takes the swap that opens the highest score (first on a tie).
    func bestSwap(_ turn: MatchTurn, excluding source: Pos?, dice: inout Dice) -> [Pos]? {
        let s = turn.state
        var best: (line: [Pos], points: Int)?
        for p in Board.grid {
            let (r, c) = Board.coords(p)
            for (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
                guard let q = Board.at(r + dr, c + dc), Board.isGrid(q) else { continue }
                guard s.cells[p] != nil, s.cells[q] != nil, p != source, q != source else { continue }
                let after = turn.reversing([p, q])
                // Nothing scored before the swap, so for a full search only sets touching the
                // swapped cells can change. A traced search starts afresh on the new board.
                let found = level.search == "all" ? bestOfAll(after, only: [p, q]) : bestTraced(after, dice: &dice)
                if let f = found, best == nil || f.points > best!.points { best = ([p, q], f.points) }
            }
        }
        return best?.line
    }
}
