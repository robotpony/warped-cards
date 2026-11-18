import CardKit
import Foundation
import GameKit
import GameRecord
import Testing
@testable import CribMaze
import CribMazeBots

/// A game around the maze: seat 0 is a bot in the player's seat (as in the simulator), seat 1 a bot.
func mazeGame(_ config: Config, seed: UInt64, players: Int = 2, writer: RecordWriter<CribMazeGame>? = nil) throws -> (GameRun<CribMazeGame>, [Step<CribMazeGame>]) {
    let seats = [PlayerSeat.bot(0, level: "medium")] + (1..<players).map { PlayerSeat.bot($0, level: "medium") }
    var (run, opening) = GameRun<CribMazeGame>.start(.init(config, mazeGame: true), seed: seed, players: seats)
    writer?.gameStarted(GameHeader(run, stamp: AppStamp(app: "test"), started: ""))
    writer?.record(opening)
    var steps = [opening]
    var dice = Dice(seed: seed)
    try MatchBot(config: config, id: "medium")!.play(&run, options: .init(deal: true, warned: true), dice: &dice, msPerAction: 4000) { writer?.record($0); steps.append($0) }
    if let r = run.result { writer?.gameEnded(r) }
    return (run, steps)
}

/// The repo's config with a short game, so debug test runs stay quick.
func shortConfig(hands: Int = 3) -> Config {
    var c = try! loadConfig()
    c.rules.game?.maxHands = hands
    return c
}

@Suite struct GameAroundTheMazeTests {
    let config = shortConfig()

    @Test func botsPlayGridTurnsOfTheirOwn() throws {
        let (run, steps) = try mazeGame(config, seed: 3)
        let events = steps.flatMap(\.events)
        let bots = events.filter { if case .botTurn = $0 { true } else { false } }
        let plays = events.compactMap { e -> (Int, [MazePlay])? in if case .handPlays(let s, let p, _) = e { (s, p) } else { nil } }
        let hands = run.state.game.results.count
        #expect(hands == config.rules.game?.maxHands)
        #expect(bots.count == hands)
        #expect(plays.count == 2 * hands)
        // Plays are biggest first, each with steps, and their IDs run on through the game.
        for (_, p) in plays { #expect(p.map(\.steps) == p.map(\.steps).sorted(by: >)); #expect(p.allSatisfy { $0.steps > 0 }) }
        let ids = plays.flatMap { $0.1.map(\.id) }.sorted()
        #expect(ids == Array(1...ids.count))
    }

    /// A bot's turn starts from its own seed, so the player's turn plays exactly as without it.
    @Test func aBotsTurnNeverShiftsThePlayers() throws {
        var (plain, _) = GameRun<CribMazeGame>.start(.init(config), seed: 5, players: [.bot(0, level: "medium")])
        var (maze, _) = GameRun<CribMazeGame>.start(.init(config, mazeGame: true), seed: 5, players: [.bot(0, level: "medium"), .bot(1, level: "medium")])
        let o = CribMazeGame.HandOptions(deal: true, warned: true)
        _ = try plain.send(.startHand(o), by: 0, clockMs: 0)
        _ = try maze.send(.startHand(o), by: 0, clockMs: 0)
        guard case .dealing(let dealt, _, _) = plain.state.stage else { Issue.record("deal"); return }
        let keep = Deal.classicKeep(dealt.player)
        let a = try plain.send(.discard(thrown: keep.thrown.map(CardRef.init)), by: 0, clockMs: 0)
        let b = try maze.send(.discard(thrown: keep.thrown.map(CardRef.init)), by: 0, clockMs: 0)
        #expect(a.events.compactMap(\.matchEvent) == b.events.compactMap(\.matchEvent))
        #expect(b.events.contains { if case .botTurn(1, _, _, _, _, _, _, _) = $0 { true } else { false } })
    }

    @Test func recordsReplay() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cribmaze-mazegame-\(ProcessInfo.processInfo.processIdentifier).jsonl")
        let w = try RecordWriter<CribMazeGame>(url: url, clock: { Date(timeIntervalSince1970: 0) })
        _ = try mazeGame(shortConfig(hands: 2), seed: 8, writer: w)
        let r = try RecordReader<CribMazeGame>.read(url)
        #expect(r.finished)
        #expect(Replayer.check(r, mode: .verify).ok)
        #expect(Replayer.check(r, mode: .scripted).ok)
    }

    @Test func playSuitIsTheMostCommon() {
        let refs = ["5H", "6H", "7S", "JH", "2C"].map { CardRef(Card.parse($0)!) }
        #expect(Plays.suit(of: refs) == "H")
        #expect(Plays.suit(of: ["5H", "6H", "7S", "JS", "2C"].map { CardRef(Card.parse($0)!) }) == nil)
    }
}
