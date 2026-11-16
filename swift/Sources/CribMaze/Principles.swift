// Discard principles (concept.md › Hints): plain rules of thumb for keeping 4 of 6, shown as hints.
// A hint names a principle and the cards it's about, never the cards to throw. Which principles
// pay on the grid, and by how much, is measured with `cribmaze-sim principles`, not assumed from
// classic cribbage.
import CardKit

public enum DiscardPrinciple: String, CaseIterable, Codable, Sendable {
    /// Keep 5s: every ten-card on the grid makes 15 with them.
    case keepFives
    /// Keep cards that score two ways (in a run and in a fifteen).
    case twoWays
    /// Keep the middle of a run; the grid won't fill it for you.
    case runMiddle
    /// Don't keep 4 of a suit just for the flush.
    case noFlushChase
    /// Keep the cards that combine with the most others; they power up most.
    case connectors

    /// The hint's one line.
    public var line: String {
        switch self {
        case .keepFives: "Keep your 5s: every ten-card on the grid makes 15 with them."
        case .twoWays: "These cards score two ways, in a run and a fifteen. Both pay every time."
        case .runMiddle: "A run needs its middle cards. The grid won't fill them for you."
        case .noFlushChase: "A flush scores once. Cards that combine score again and again."
        case .connectors: "Hand cards power up each time they score. Keep the ones that combine most."
        }
    }
}

/// A principle that applies to a deal, and the cards it's about (in deal order).
public struct PrincipleHit: Sendable, Equatable {
    public let principle: DiscardPrinciple
    public let cards: [Card]
}

public enum Principles {
    /// The principles that apply to a 6-card deal, in the order of `DiscardPrinciple.allCases`.
    public static func applying(to deal: [Card]) -> [PrincipleHit] {
        var hits: [PrincipleHit] = []
        let fives = deal.filter { $0.rank == 5 }
        if !fives.isEmpty { hits.append(PrincipleHit(principle: .keepFives, cards: fives)) }
        let runs = runCards(deal), fifteens = fifteenCards(deal)
        let both = deal.filter { c in runs.contains(c.id) && fifteens.contains(c.id) }
        if !both.isEmpty { hits.append(PrincipleHit(principle: .twoWays, cards: both)) }
        let middles = runMiddles(deal)
        if !middles.isEmpty { hits.append(PrincipleHit(principle: .runMiddle, cards: middles)) }
        for s in Suit.allCases {
            let suited = deal.filter { $0.suit == s }
            if suited.count >= 4 { hits.append(PrincipleHit(principle: .noFlushChase, cards: suited)) }
        }
        let links = deal.map { c in (c, deal.filter { $0.id != c.id && linked(c, $0) }.count) }
        let top = links.map(\.1).max() ?? 0
        if top >= 2 { hits.append(PrincipleHit(principle: .connectors, cards: links.filter { $0.1 == top }.map(\.0))) }
        return hits
    }

    /// The one principle to show for a deal: the applying principle worth the most on the grid, if
    /// it's worth at least `minWorth` (hints.json). Principles not yet shown to pay are never shown.
    public static func best(for deal: [Card], hints: HintsConfig.Discard) -> PrincipleHit? {
        let worth = Dictionary(hints.worth.entries, uniquingKeysWith: { a, _ in a })
        return applying(to: deal)
            .filter { (worth[$0.principle.rawValue] ?? .min) >= hints.minWorth }
            .max { (worth[$0.principle.rawValue] ?? 0) < (worth[$1.principle.rawValue] ?? 0) }
    }

    /// Whether keeping these 4 follows the principle.
    public static func follows(_ keep: [Card], _ hit: PrincipleHit) -> Bool {
        let kept = Set(keep.map(\.id))
        switch hit.principle {
        case .noFlushChase:
            return !(Set(keep.compactMap(\.suit)).count == 1)
        default:
            // Keep all its cards, or as many as fit in 4.
            return hit.cards.filter { kept.contains($0.id) }.count >= min(4, hit.cards.count)
        }
    }

    /// Two cards combine: a pair, a fifteen, or neighbouring ranks.
    static func linked(_ a: Card, _ b: Card) -> Bool { a.rank == b.rank || a.value + b.value == 15 || abs(a.rank - b.rank) == 1 }

    /// Cards in a run of 3 or more distinct ranks within the deal.
    static func runCards(_ deal: [Card]) -> Set<Int> {
        var out = Set<Int>()
        for (lo, hi) in runSpans(deal) { for c in deal where (lo...hi).contains(c.rank) { out.insert(c.id) } }
        return out
    }

    /// Cards in a run, less the run's two end ranks.
    static func runMiddles(_ deal: [Card]) -> [Card] {
        var ids = Set<Int>()
        for (lo, hi) in runSpans(deal) where hi - lo >= 2 { for c in deal where c.rank > lo && c.rank < hi { ids.insert(c.id) } }
        return deal.filter { ids.contains($0.id) }
    }

    /// Spans of 3 or more consecutive ranks present in the deal.
    static func runSpans(_ deal: [Card]) -> [(Int, Int)] {
        let ranks = Set(deal.map(\.rank))
        var spans: [(Int, Int)] = [], r = 1
        while r <= 13 {
            if ranks.contains(r) {
                var e = r
                while ranks.contains(e + 1) { e += 1 }
                if e - r >= 2 { spans.append((r, e)) }
                r = e + 1
            } else { r += 1 }
        }
        return spans
    }

    /// Cards in some subset of the deal that adds to 15.
    static func fifteenCards(_ deal: [Card]) -> Set<Int> {
        var out = Set<Int>()
        for mask in 1..<(1 << deal.count) {
            let pick = deal.indices.filter { mask & (1 << $0) != 0 }
            if pick.count >= 2, pick.map({ deal[$0].value }).reduce(0, +) == 15 { for i in pick { out.insert(deal[i].id) } }
        }
        return out
    }
}
