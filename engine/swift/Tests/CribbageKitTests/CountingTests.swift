import CardKit
import Foundation
import Testing
@testable import CribbageKit

let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../cribbage/minigames/fixtures").standardized

struct CountFixture: Decodable {
    struct Combo: Decodable { let kind: String; let points: Int; let cards: [Int]; let size: Int?; let multiplier: Int? }
    struct Case: Decodable { let cards: String; let options: CountOptions; let total: Int; let combos: [Combo]; let leftOver: [Int] }
    let cases: [Case]
}

func load(_ name: String) throws -> CountFixture {
    try JSONDecoder().decode(CountFixture.self, from: Data(contentsOf: fixtures.appendingPathComponent(name)))
}

@Suite struct CountingTests {
    @Test(arguments: ["counting.json", "classic-hands.json"])
    func fixturesMatch(file: String) throws {
        for c in try load(file).cases {
            let cards = c.cards.split(separator: " ").map { Card.parse(String($0))! }
            let got = count(cards.map { ($0.rank, $0.suit!) }, c.options)
            #expect(got.total == c.total, "\(c.cards)")
            #expect(got.combos.map(\.kind.rawValue) == c.combos.map(\.kind), "\(c.cards)")
            #expect(got.combos.map(\.points) == c.combos.map(\.points), "\(c.cards)")
            #expect(got.combos.map(\.cards) == c.combos.map(\.cards), "\(c.cards)")
            #expect(got.combos.map(\.size) == c.combos.map(\.size), "\(c.cards)")
            #expect(got.combos.map(\.multiplier) == c.combos.map(\.multiplier), "\(c.cards)")
            #expect(got.leftOver == c.leftOver, "\(c.cards)")
        }
    }

    @Test func suitTies() {
        #expect(suitOf([.hearts, .hearts, .spades]) == .hearts)
        #expect(suitOf([.diamonds, .spades, .spades, .diamonds]) == nil)
    }

    @Test func notation() {
        #expect(Card.parse("10H")?.id == 13 + 9)
        #expect(Card.parse("AS")?.id == 0)
        #expect(Card.parse("KC")?.notation == "KC")
        #expect(Card.parse("5H*")?.kind == .made)
    }
}

/// Rung 4: fixtures/pegging.json, classic pegging (engine.md › Classic cribbage › The play).
@Suite struct PeggingTests {
    struct Fixture: Decodable {
        struct Case: Decodable { let note: String; let players: Int; let dealer: Int; let hands: [[String]]; let plays: [String]; let expect: [Expect]; let totals: [Int] }
        struct Expect: Decodable, Equatable {
            let seat: Int; let card: String?; let go: Int?; let count: Int; let scores: [[Score]]?
        }
        enum Score: Decodable, Equatable {
            case kind(String), points(Int)
            init(from d: Decoder) throws {
                let c = try d.singleValueContainer()
                if let s = try? c.decode(String.self) { self = .kind(s) } else { self = .points(try c.decode(Int.self)) }
            }
        }
        let cases: [Case]
    }

    @Test func peggingFixturesPlayOut() throws {
        let url = fixtures.appendingPathComponent("pegging.json")
        let f = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        #expect(f.cases.count >= 5)
        for c in f.cases {
            var p = PegPlay(hands: c.hands.map { $0.map { Card.parse($0)! } }, lead: (c.dealer + 1) % c.players, scoring: PegScoring())
            var out: [Fixture.Expect] = []
            for text in c.plays {
                let card = Card.parse(text)!
                #expect(p.legal(p.turn).contains(card), "\(c.note): \(text) isn't seat \(p.turn)'s to play")
                guard let ev = p.play(card) else { Issue.record("\(c.note): \(text) refused"); break }
                for e in ev {
                    switch e {
                    case .played(let seat, let card, let count, let scores) where !scores.isEmpty:
                        out.append(.init(seat: seat, card: card.notation, go: nil, count: count, scores: scores.map { [.kind($0.kind), .points($0.points)] }))
                    case .goPoint(let seat, let points, let count):
                        out.append(.init(seat: seat, card: nil, go: points, count: count, scores: nil))
                    default: break
                    }
                }
            }
            #expect(p.over, "\(c.note)")
            #expect(out == c.expect, "\(c.note)")
            #expect(p.scores == c.totals, "\(c.note)")
        }
    }

    @Test func botPegsForPointsThenSafety() {
        // At 10, a 5 makes fifteen; with no score, it avoids 21 and plays high.
        var p = PegPlay(hands: [["10S"], ["4H", "5D", "KC"]].map { $0.map { Card.parse($0)! } }, lead: 0, scoring: PegScoring())
        _ = p.play(Card.parse("10S")!)
        #expect(p.botCard()?.notation == "5D")
        var q = PegPlay(hands: [["JS", "AH"], ["AD", "KC", "9C"]].map { $0.map { Card.parse($0)! } }, lead: 0, scoring: PegScoring())
        _ = q.play(Card.parse("JS")!)
        #expect(q.botCard()?.notation == "KC")   // nothing scores or leaves 5 or 21, so the highest value
    }
}
