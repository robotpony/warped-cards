// Plays for the maze (maze.md › Plays): every set a player scored on the grid this hand, and their
// hand and crib counts, become tiles of steps with a suit. No clock, no files, no randomness.
import CardKit

/// One play: a set scored on the grid, or the hand or crib count, spent on the maze.
public struct MazePlay: Codable, Sendable, Equatable {
    /// Unique in the game, numbered from 1 in the order plays are made.
    public let id: Int
    /// The points it scored, which are the steps it walks.
    public let steps: Int
    /// The suit most of its cards share, or none on a tie (S, H, D or C).
    public let suit: String?
    /// The cards it scored with, in the order counted.
    public let cards: [CardRef]
    /// What it came from: `set`, `hand` or `crib`.
    public let from: String
    public init(id: Int, steps: Int, suit: String?, cards: [CardRef], from: String) {
        self.id = id; self.steps = steps; self.suit = suit; self.cards = cards; self.from = from
    }
}

public enum Plays {
    /// The suit that appears most among these cards, or nil when two or more tie for most.
    /// Cards with no suit don't count.
    public static func suit(of cards: [CardRef]) -> String? {
        var n = [Int](repeating: 0, count: 4)
        for c in cards { if let s = Card.parse(c.card)?.suit { n[s.rawValue] += 1 } }
        let most = n.max() ?? 0
        guard most > 0, n.filter({ $0 == most }).count == 1, let i = n.firstIndex(of: most) else { return nil }
        return Suit(rawValue: i)!.letter
    }

    /// A grid turn's plays, from its events in order: the opening counts and every scored set,
    /// with 1 step or more. Biggest first; plays of the same size keep the order they were made.
    /// `nextID` numbers them and moves on.
    public static func from(_ events: [MatchEvent], nextID: inout Int) -> [MazePlay] {
        var out: [MazePlay] = []
        for e in events {
            switch e {
            case .opening(let what, _, let cards, _, _, _, let points, _) where points > 0:
                out.append(MazePlay(id: nextID, steps: points, suit: suit(of: cards), cards: cards, from: what)); nextID += 1
            case .score(_, let cards, _, _, _, _, _, _, let points, _, let suit, _) where points > 0:
                out.append(MazePlay(id: nextID, steps: points, suit: suit, cards: cards, from: "set")); nextID += 1
            default: break
            }
        }
        return sortBiggestFirst(out)
    }

    /// Biggest first, keeping the order of plays of the same size (a stable sort).
    public static func sortBiggestFirst(_ plays: [MazePlay]) -> [MazePlay] {
        plays.enumerated().sorted { a, b in a.element.steps != b.element.steps ? a.element.steps > b.element.steps : a.offset < b.offset }.map(\.element)
    }
}
