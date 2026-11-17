// Counting a set of cards (engine.md › Counting a set). Shared by classic hands and the match turn.
import CardKit

public struct Scoring: Codable, Sendable, Equatable {
    public var fifteen = 2, pair = 2, runPerCard = 1, flushPerCard = 1, nobs = 1
    public init() {}
}

public struct CountOptions: Codable, Sendable, Equatable {
    /// A flush needs at least this many cards, all one suit.
    public var flushMin: Int
    /// Classic hands: a 4-card flush of the first 4 when the 5th (the starter) is another suit.
    public var handFlush4: Bool
    /// His nobs: the indexes of the starter and the jack of its suit, when both are in the set.
    public var nobs: [Int]?
    public init(flushMin: Int = 4, handFlush4: Bool = false, nobs: [Int]? = nil) {
        self.flushMin = flushMin; self.handFlush4 = handFlush4; self.nobs = nobs
    }
    enum CodingKeys: String, CodingKey { case flushMin, handFlush4, nobs }
    /// Missing options take their defaults, as config and fixtures leave them out.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        flushMin = try c.decodeIfPresent(Int.self, forKey: .flushMin) ?? 4
        handFlush4 = try c.decodeIfPresent(Bool.self, forKey: .handFlush4) ?? false
        nobs = try c.decodeIfPresent([Int].self, forKey: .nobs)
    }
}

public enum ComboKind: String, Codable, Sendable { case fifteen, pair, run, flush, nobs }

public struct Combo: Codable, Sendable, Equatable {
    public let kind: ComboKind
    public let points: Int
    /// Card indexes into the counted list, ascending.
    public let cards: [Int]
    /// Pairs and flushes: how many cards. Runs: distinct ranks (the run's length).
    public let size: Int?
    /// Runs: how many runs (product of each rank's count).
    public let multiplier: Int?
}

public struct Count: Sendable, Equatable {
    public let combos: [Combo]
    public var total: Int { combos.reduce(0) { $0 + $1.points } }
    /// Indexes in no combo.
    public let leftOver: [Int]
}

/// Counts cards given as (rank, suit). Order: fifteens, pairs, runs, flush, his nobs.
public func count(_ cards: [(rank: Int, suit: Suit)], _ o: CountOptions, scoring: Scoring = Scoring()) -> Count {
    let n = cards.count
    var combos: [Combo] = []
    // Fifteens: every subset of 2 or more adding to 15, in increasing bitmask order.
    if n >= 2 {
        for m in 1..<(1 << n) where m.nonzeroBitCount >= 2 {
            var sum = 0, idx: [Int] = []
            for i in 0..<n where m >> i & 1 == 1 { sum += min(cards[i].rank, 10); idx.append(i) }
            if sum == 15 { combos.append(Combo(kind: .fifteen, points: scoring.fifteen, cards: idx, size: nil, multiplier: nil)) }
        }
    }
    // Pairs: by rank, ascending. n of a kind scores every pair: n(n−1)/2.
    var byRank: [Int: [Int]] = [:]
    for (i, c) in cards.enumerated() { byRank[c.rank, default: []].append(i) }
    let ranks = byRank.keys.sorted()
    for r in ranks {
        let idx = byRank[r]!
        if idx.count >= 2 {
            combos.append(Combo(kind: .pair, points: scoring.pair * idx.count * (idx.count - 1) / 2, cards: idx, size: idx.count, multiplier: nil))
        }
    }
    // Runs: each maximal stretch of 3 or more consecutive ranks, ascending.
    var i = 0
    while i < ranks.count {
        var j = i
        while j + 1 < ranks.count && ranks[j + 1] == ranks[j] + 1 { j += 1 }
        if j - i + 1 >= 3 {
            let run = Array(ranks[i...j])
            let mult = run.reduce(1) { $0 * byRank[$1]!.count }
            let idx = run.flatMap { byRank[$0]! }.sorted()
            combos.append(Combo(kind: .run, points: scoring.runPerCard * run.count * mult, cards: idx, size: run.count, multiplier: mult))
        }
        i = j + 1
    }
    // Flush.
    if n >= o.flushMin && n > 0 && cards.allSatisfy({ $0.suit == cards[0].suit }) {
        combos.append(Combo(kind: .flush, points: scoring.flushPerCard * n, cards: Array(0..<n), size: n, multiplier: nil))
    } else if o.handFlush4 && n == 5 && cards[0..<4].allSatisfy({ $0.suit == cards[0].suit }) {
        combos.append(Combo(kind: .flush, points: scoring.flushPerCard * 4, cards: [0, 1, 2, 3], size: 4, multiplier: nil))
    }
    // His nobs.
    if let nb = o.nobs { combos.append(Combo(kind: .nobs, points: scoring.nobs, cards: nb.sorted(), size: nil, multiplier: nil)) }

    var used = Set<Int>()
    for c in combos { used.formUnion(c.cards) }
    return Count(combos: combos, leftOver: (0..<n).filter { !used.contains($0) })
}

/// The suit most cards share; a tie for most is no suit.
public func suitOf(_ suits: [Suit]) -> Suit? {
    var n = [Int](repeating: 0, count: 4)
    for s in suits { n[s.rawValue] += 1 }
    let most = n.max() ?? 0
    let top = Suit.allCases.filter { n[$0.rawValue] == most }
    return most > 0 && top.count == 1 ? top[0] : nil
}
