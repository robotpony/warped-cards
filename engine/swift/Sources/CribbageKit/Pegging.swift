// Classic pegging, the play (engine.md › Classic cribbage › The play): seats play cards in turn,
// the count runs to 31, and fifteens, 31s, pairs, runs, gos and the last card score. The maze's
// duels play it two-handed (maze.md › Duels). Checked against fixtures/pegging.json.
import CardKit

/// Pegging's points: classic.json › peg, or maze.json › duel.peg.
public struct PegScoring: Codable, Sendable, Equatable {
    public var maxCount: Int, fifteen: Int, thirtyOne: Int, pair: Int, runPerCard: Int, go: Int, lastCard: Int
    public init(maxCount: Int = 31, fifteen: Int = 2, thirtyOne: Int = 2, pair: Int = 2, runPerCard: Int = 1, go: Int = 1, lastCard: Int = 1) {
        self.maxCount = maxCount; self.fifteen = fifteen; self.thirtyOne = thirtyOne; self.pair = pair
        self.runPerCard = runPerCard; self.go = go; self.lastCard = lastCard
    }
}

/// One thing a card scored: `fifteen`, `thirty_one`, `pair`, `run`, `go` or `last_card`.
public struct PegScore: Codable, Sendable, Equatable {
    public let kind: String
    public let points: Int
    public init(kind: String, points: Int) { self.kind = kind; self.points = points }
}

/// What a card scores as it's played, in the spec's order: fifteen, thirty-one, pair, run.
/// `played` is every card since the count last started, the new one last; `count` includes it.
public func pegScores(_ played: [Card], count: Int, _ p: PegScoring) -> [PegScore] {
    var out: [PegScore] = []
    if count == 15 { out.append(PegScore(kind: "fifteen", points: p.fifteen)) }
    if count == p.maxCount { out.append(PegScore(kind: "thirty_one", points: p.thirtyOne)) }
    guard let last = played.last else { return out }
    var k = 1
    while k < played.count && played[played.count - 1 - k].rank == last.rank { k += 1 }
    if k >= 2 { out.append(PegScore(kind: "pair", points: p.pair * k * (k - 1) / 2)) }
    if played.count >= 3 {
        for n in stride(from: played.count, through: 3, by: -1) {
            let ranks = played.suffix(n).map(\.rank)
            if Set(ranks).count == n && ranks.max()! - ranks.min()! == n - 1 { out.append(PegScore(kind: "run", points: p.runPerCard * n)); break }
        }
    }
    return out
}

/// Something that happened in the play.
public enum PegEvent: Sendable, Equatable {
    /// A card down: the count after it, and what it scored (the last card's point included).
    case played(seat: Int, card: Card, count: Int, scores: [PegScore])
    /// A seat can't play and sits out until the count starts again.
    case go(seat: Int)
    /// Nobody can play: the last seat to play pegs the go, at this count, and the count starts again.
    case goPoint(seat: Int, points: Int, count: Int)
}

/// The play, for 2 or 3 seats. Play passes from a seat to the next (seat + 1, wrapping).
public struct PegPlay: Sendable, Equatable {
    public let scoring: PegScoring
    public private(set) var hands: [[Card]]
    public private(set) var count = 0
    /// The cards since the count last started, in order.
    public private(set) var run: [Card] = []
    /// Every card played, with its seat, in order.
    public private(set) var played: [(seat: Int, card: Card)] = []
    /// The seat to play next.
    public private(set) var turn: Int
    public private(set) var last: Int?
    public private(set) var saidGo: [Bool]
    public private(set) var scores: [Int]

    /// `lead` plays first: in classic cribbage, the seat after the dealer.
    public init(hands: [[Card]], lead: Int, scoring: PegScoring) {
        self.hands = hands; self.scoring = scoring; turn = lead
        saidGo = [Bool](repeating: false, count: hands.count); scores = [Int](repeating: 0, count: hands.count)
    }

    public var over: Bool { hands.allSatisfy(\.isEmpty) }
    /// The cards this seat may play now: those that keep the count at `maxCount` or under, in hand order.
    public func legal(_ seat: Int) -> [Card] { hands[seat].filter { count + $0.value <= scoring.maxCount } }
    public func canPlay(_ seat: Int) -> Bool { !legal(seat).isEmpty }

    public static func == (a: PegPlay, b: PegPlay) -> Bool {
        a.hands == b.hands && a.count == b.count && a.run == b.run && a.turn == b.turn && a.last == b.last && a.saidGo == b.saidGo && a.scores == b.scores
            && a.played.map(\.seat) == b.played.map(\.seat) && a.played.map(\.card) == b.played.map(\.card)
    }

    /// The seat to play plays this card, then the play runs on (gos, the count starting again) until
    /// a seat can play or every card is down. Returns nil if the card isn't the seat's to play.
    public mutating func play(_ card: Card) -> [PegEvent]? {
        let k = turn
        guard let i = hands[k].firstIndex(of: card), count + card.value <= scoring.maxCount else { return nil }
        hands[k].remove(at: i)
        count += card.value; run.append(card); played.append((k, card)); last = k
        var s = pegScores(run, count: count, scoring)
        if over && count != scoring.maxCount { s.append(PegScore(kind: "last_card", points: scoring.lastCard)) }
        scores[k] += s.reduce(0) { $0 + $1.points }
        var ev: [PegEvent] = [.played(seat: k, card: card, count: count, scores: s)]
        if count == scoring.maxCount { startAgain() } else { turn = next(k) }
        ev += settle()
        return ev
    }

    /// Gos and the count starting again, until a seat can play or the play is over.
    mutating func settle() -> [PegEvent] {
        var ev: [PegEvent] = []
        while !over && !canPlay(turn) {
            if !(0..<hands.count).contains(where: canPlay) {
                // Nobody can play: the last to play pegs the go, and the count starts again.
                if let l = last {
                    scores[l] += scoring.go
                    ev.append(.goPoint(seat: l, points: scoring.go, count: count))
                }
                startAgain()
                continue
            }
            if !saidGo[turn] && !hands[turn].isEmpty { saidGo[turn] = true; ev.append(.go(seat: turn)) }
            turn = next(turn)
        }
        return ev
    }

    /// The count starts again; the seat after the last to play leads, skipping seats with no cards.
    mutating func startAgain() {
        count = 0; run = []; saidGo = saidGo.map { _ in false }
        var t = next(last ?? turn)
        for _ in 0..<hands.count where hands[t].isEmpty { t = next(t) }
        turn = t
    }

    func next(_ s: Int) -> Int { (s + 1) % hands.count }

    /// A simple pegging bot (maze.md › Duels › Bot pegging): the card that scores most now, then one
    /// that doesn't leave the count at 5 or 21, then the highest value; the first in hand order on a tie.
    public func botCard() -> Card? {
        var best: (Card, Int, Int, Int)?
        for c in legal(turn) {
            let n = count + c.value
            let pts = pegScores(run + [c], count: n, scoring).reduce(0) { $0 + $1.points }
            let safe = (n == 5 || n == 21) ? 0 : 1
            if best == nil || (pts, safe, c.value) > (best!.1, best!.2, best!.3) { best = (c, pts, safe, c.value) }
        }
        return best?.0
    }
}
