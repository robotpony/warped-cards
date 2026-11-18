import Foundation
import GameKit
import Testing
@testable import CribMaze

/// fixtures/mazes.json: one maze per seed, from the mock's generator (engine.md › The maze › The board).
@Suite struct MazeBoardTests {
    struct Fixture: Decodable {
        struct Door: Decodable, Equatable { let cells: [Int]; let strength: Int; let suit: String?; let variant: Bool; let shortcut: Bool }
        struct Variant: Decodable, Equatable { let door: Int, from: Int, to: Int, len: Int, span: Int; let kind: String }
        struct Case: Decodable {
            let seed: String; let size: Int; let start: Int; let goal: Int; let route: [Int]
            let doors: [Door]; let variants: [Variant]; let switches: [[[Int]]]; let stars: [Int]; let arrows: [[Int]]
        }
        let cases: [Case]
    }
    let config = try! loadConfig()

    @Test func buildsEverySeedsMaze() throws {
        let url = repo.appendingPathComponent("cribbage/minigames/fixtures/mazes.json")
        let f = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        #expect(f.cases.count >= 5)
        for c in f.cases {
            var dice = Dice(seed: UInt64(c.seed)!)
            let m = MazeBoard.generate(config.maze!.board, dice: &dice)
            #expect(m.w == c.size && m.start == c.start && m.goal == c.goal, "seed \(c.seed)")
            #expect(m.route == c.route, "seed \(c.seed): golden path")
            let doors = m.doors.map { k, d in let (a, b) = m.cells(ofKey: k); return Fixture.Door(cells: [a, b], strength: d.strength, suit: d.suit, variant: d.variant, shortcut: d.shortcut) }
            #expect(doors == c.doors, "seed \(c.seed): doors")
            #expect(m.variants.map { Fixture.Variant(door: $0.door, from: $0.from, to: $0.to, len: $0.len, span: $0.span, kind: $0.kind) } == c.variants, "seed \(c.seed): variants")
            #expect(m.switches.map { s in [s.a, s.b].map { let (a, b) = m.cells(ofKey: $0); return [a, b] } } == c.switches, "seed \(c.seed): switches")
            #expect(m.stars == c.stars, "seed \(c.seed): stars")
            let arrows = (0..<m.n).filter { m.liveExits($0).count >= 2 }.map { [$0, m.arrow[$0].rawValue] }
            #expect(arrows == c.arrows, "seed \(c.seed): arrows")
        }
    }

    /// The maze draws only from the `maze` stream.
    @Test func drawsOnlyFromTheMazeStream() {
        var dice = Dice(seed: 9)
        _ = MazeBoard.generate(config.maze!.board, dice: &dice)
        let rolls = dice.takeRolls()
        #expect(!rolls.isEmpty && rolls.allSatisfy { $0.stream == "maze" })
    }
}
