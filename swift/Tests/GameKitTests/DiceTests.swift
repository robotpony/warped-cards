import Foundation
import Testing
@testable import GameKit

/// The repo's shared fixtures folder, found from this file's path.
let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../cribbage/minigames/fixtures").standardized

struct DiceFixture: Decodable {
    struct Case: Decodable {
        struct Below: Decodable { let n: [Int]; let values: [Int] }
        let seed: String, stream: String, streamSeed: String
        let first64: [String]
        let below: Below
        let pick: [String]
        let shuffle52: [Int]
    }
    struct Vectors: Decodable { let fnv1a64: [[String]] }
    let vectors: Vectors
    let cases: [Case]
}

@Suite struct DiceTests {
    let f = try! JSONDecoder().decode(DiceFixture.self, from: Data(contentsOf: fixtures.appendingPathComponent("dice.json")))

    @Test func fnvVectors() {
        for v in f.vectors.fnv1a64 { #expect(String(fnv1a64(v[0])) == v[1]) }
    }

    @Test func splitMixVector() {
        var s = SplitMix64(seed: 1_234_567)
        #expect([s.next(), s.next(), s.next()] == [6_457_827_717_110_365_317, 3_203_168_211_198_807_973, 9_817_491_932_198_370_423])
    }

    @Test func casesMatchTheReference() {
        let weights: [(String, Int)] = [("card", 90), ("scoring", 9), ("item", 1)]
        for c in f.cases {
            let seed = UInt64(c.seed)!
            #expect(String(seed ^ fnv1a64(c.stream)) == c.streamSeed)
            var raw = DiceStream(gameSeed: seed, name: c.stream)
            #expect((0..<4).map { _ in String(raw.next64()) } == c.first64, "\(c.seed) \(c.stream)")
            var d = Dice(seed: seed)
            #expect(c.below.n.map { d.below($0, stream: c.stream, purpose: "test") } == c.below.values)
            var d2 = Dice(seed: seed)
            #expect(c.pick.map { _ in d2.pick(weights, stream: c.stream, purpose: "test") } == c.pick)
            var d3 = Dice(seed: seed)
            var deck = Array(0..<52)
            d3.shuffle(&deck, stream: c.stream, purpose: "test")
            #expect(deck == c.shuffle52)
        }
    }

    @Test func scriptedDiceReplaysRolls() {
        var d = Dice(seed: 42)
        let a = (0..<5).map { _ in d.below(10, stream: "deal", purpose: "x") }
        var s = Dice(scripted: d.takeRolls(), seed: 0)
        #expect((0..<5).map { _ in s.below(10, stream: "deal", purpose: "x") } == a)
    }
}
