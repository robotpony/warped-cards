import CardKit
import Foundation
import Testing
@testable import CribbageKit

let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../cribbage/minigames/fixtures").standardized

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
