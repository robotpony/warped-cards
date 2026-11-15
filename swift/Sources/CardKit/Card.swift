// Cards and their notation (engine.md › Cards).

public enum Suit: Int, Codable, Sendable, CaseIterable, Comparable {
    case spades, hearts, diamonds, clubs   // suit order S, H, D, C
    public var letter: String { ["S", "H", "D", "C"][rawValue] }
    public var glyph: String { ["♠", "♥", "♦", "♣"][rawValue] }
    public init?(letter: String) {
        guard let i = ["S", "H", "D", "C"].firstIndex(of: letter) else { return nil }
        self.init(rawValue: i)
    }
    public static func < (a: Suit, b: Suit) -> Bool { a.rawValue < b.rawValue }
}

/// What a card is. Standard and made cards have a rank and suit; the rest are jokers.
public enum CardKind: Codable, Sendable, Equatable, Hashable {
    case standard
    case made                 // made by a joker; kept in the deck for the game
    case extra(String)        // amber, teal, title, blank
    case special(String)      // swapper, bomb
}

/// A card with an ID that never changes. IDs: 0-51 standard, 100+ extras, 200+ made, 300+ specials.
public struct Card: Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let kind: CardKind
    public let rank: Int      // 1 (A) to 13 (K); 0 for jokers
    public let suit: Suit?

    public init(id: Int, kind: CardKind, rank: Int, suit: Suit?) {
        self.id = id; self.kind = kind; self.rank = rank; self.suit = suit
    }
    /// A standard card from its ID: suit index × 13 + rank − 1.
    public init(standard id: Int) {
        precondition((0..<52).contains(id))
        self.init(id: id, kind: .standard, rank: id % 13 + 1, suit: Suit(rawValue: id / 13))
    }

    public var isPlaying: Bool { kind == .standard || kind == .made }
    public var isSpecial: Bool { if case .special = kind { return true }; return false }
    public var isExtra: Bool { if case .extra = kind { return true }; return false }
    /// Value for fifteens: the rank, with 11, 12 and 13 counting 10.
    public var value: Int { min(rank, 10) }

    public static func rankText(_ r: Int) -> String { [1: "A", 11: "J", 12: "Q", 13: "K"][r] ?? String(r) }

    /// Fixture notation: rank then suit (AS, 10H), a star for made cards, or the joker's kind.
    public var notation: String {
        switch kind {
        case .standard: return Card.rankText(rank) + (suit?.letter ?? "")
        case .made: return Card.rankText(rank) + (suit?.letter ?? "") + "*"
        case .extra(let k), .special(let k): return k
        }
    }
    /// Rank and suit glyph for showing: 10♥.
    public var face: String { isPlaying ? Card.rankText(rank) + (suit?.glyph ?? "") : notation }

    /// Parses fixture notation for a playing card ("AS", "10H", "5H*"). The ID is the standard ID.
    public static func parse(_ text: String) -> Card? {
        var t = Substring(text)
        let made = t.hasSuffix("*"); if made { t = t.dropLast() }
        guard let s = t.last.flatMap({ Suit(letter: String($0)) }) else { return nil }
        let r: Int
        switch t.dropLast() {
        case "A": r = 1
        case "J": r = 11
        case "Q": r = 12
        case "K": r = 13
        case let x: guard let v = Int(x), (2...10).contains(v) else { return nil }; r = v
        }
        return Card(id: s.rawValue * 13 + r - 1, kind: made ? .made : .standard, rank: r, suit: s)
    }
}
