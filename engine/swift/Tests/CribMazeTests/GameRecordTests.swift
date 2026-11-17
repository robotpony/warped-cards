import CardKit
import Foundation
import GameKit
import GameRecord
import Testing
@testable import CribMaze
@testable import CribMazeBots

/// Golden replays (ARCHITECTURE.md › Testing): recorded games that MUST verify on every build.
/// Re-record with `cribmaze-sim record --games 1 --seed 1 --out <this folder>/seed1.jsonl` when a
/// rules change breaks one on purpose, and say so in the commit.
let goldenRecords = repo.appendingPathComponent("cribbage/minigames/fixtures/records")

/// The medium bot plays a whole game from a seed, through GameRun, as `cribmaze-sim record` does.
@discardableResult
func botGame(_ config: Config, seed: UInt64, writer: RecordWriter<CribMazeGame>? = nil, onStep: (Step<CribMazeGame>) -> Void = { _ in }) throws -> (GameRun<CribMazeGame>, Step<CribMazeGame>) {
    var (run, opening) = GameRun<CribMazeGame>.start(.init(config), seed: seed, players: [.bot(0, level: "medium"), .bot(1, level: "classic")])
    writer?.gameStarted(GameHeader(run, stamp: AppStamp(app: "test"), started: ""))
    writer?.record(opening)
    var dice = Dice(seed: seed)
    try MatchBot(config: config, id: "medium")!.play(&run, options: .init(deal: true, warned: true), dice: &dice, msPerAction: 4000) { writer?.record($0); onStep($0) }
    if let r = run.result { writer?.gameEnded(r) }
    return (run, opening)
}

@Suite struct CribMazeRecordTests {
    let config = try! loadConfig()

    /// A game through GameRun plays exactly as MatchGame does in `cribmaze-sim game`.
    @Test func playsTheSameGamesAsTheSimulator() throws {
        let bot = MatchBot(config: config, id: "medium")!
        for seed in UInt64(1)...2 {
            var g = MatchGame(config: config, seed: seed)
            while !g.over {
                let dealt = g.deal()
                let keep = Deal.classicKeep(dealt.player, scoring: config.rules.scoring), botKeep = Deal.classicKeep(dealt.bot, scoring: config.rules.scoring)
                var (t, ev) = MatchTurn.start(config: config, setup: g.setup(dealt: dealt, thrown: keep.thrown, botThrown: botKeep.thrown, kept: keep.keep.sorted { $0.id < $1.id }, warned: true))
                var ends: [Int: Int] = [:], acted = 0
                while !t.state.over {
                    var d = t.dice
                    let a = bot.choose(t, dice: &d)
                    t.dice = d
                    let e = try t.apply(a)
                    ev += e; acted += 1
                    for x in e { if case .reach(let id, _, _, _, _) = x { ends[id] = acted + 5 } }
                    for (id, end) in ends.sorted(by: { $0.key < $1.key }) where end <= acted && !t.state.over { ends[id] = nil; ev += try t.apply(.reachOver(id: id)) }
                }
                g.finish(t, events: ev)
            }
            let (run, _) = try botGame(config, seed: seed)
            #expect(run.result?.hands == g.results, "seed \(seed)")
        }
    }

    @Test func recordsVerifiesAndReplaysScripted() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cribmaze-record-\(ProcessInfo.processInfo.processIdentifier).jsonl")
        let w = try RecordWriter<CribMazeGame>(url: url, clock: { Date(timeIntervalSince1970: 0) })
        try botGame(config, seed: 7, writer: w)
        let r = try RecordReader<CribMazeGame>.read(url)
        #expect(r.finished)
        #expect(Replayer.check(r, mode: .verify).ok)
        #expect(Replayer.check(r, mode: .scripted).ok)
    }

    @Test func goldenRecordsVerify() throws {
        let (records, skipped) = RecordReader<CribMazeGame>.readAll(goldenRecords)
        #expect(skipped.isEmpty, "\(skipped)")
        #expect(!records.isEmpty)
        for r in records {
            let v = Replayer.check(r, mode: .verify), s = Replayer.check(r, mode: .scripted)
            #expect(v.ok, "\(r.url!.lastPathComponent): \(v)")
            #expect(s.ok, "\(r.url!.lastPathComponent): \(s)")
        }
    }

    /// engine.md › Records › Encoding: reading a golden record and writing it again gives the same
    /// bytes, ignoring `at`, so the checked-in records pin the wire format for every port.
    @Test func goldenRecordsWriteTheSameBytes() throws {
        let (records, _) = RecordReader<CribMazeGame>.readAll(goldenRecords)
        func plain(_ data: Data) -> [String] {
            String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
                .filter { !$0.contains("\"kind\":\"note\"") }
                .map { $0.replacingOccurrences(of: #""at":"[^"]*","#, with: "", options: .regularExpression) }
        }
        for r in records {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("cribmaze-golden-\(ProcessInfo.processInfo.processIdentifier).jsonl")
            let w = try RecordWriter<CribMazeGame>(url: url, clock: { Date(timeIntervalSince1970: 0) })
            w.gameStarted(r.header)
            for s in r.steps { w.record(s) }
            if let e = r.end { w.gameEnded(e.result) }
            let again = try Data(contentsOf: url), original = try Data(contentsOf: r.url!)
            #expect(plain(again) == plain(original), "\(r.url!.lastPathComponent)")
        }
    }

    /// The header names the spec version, and the engine's matches spec.json.
    @Test func headerNamesTheSpecVersion() throws {
        let spec = try JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("cribbage/minigames/spec.json"))) as? [String: Any]
        #expect(spec?["specVersion"] as? Int == CribMazeGame.specVersion)
        let (records, _) = RecordReader<CribMazeGame>.readAll(goldenRecords)
        for r in records { #expect(r.header.specVersion == CribMazeGame.specVersion, "\(r.url!.lastPathComponent)") }
    }

    /// A game is a sequence of hands; each hand's steps carry its number.
    @Test func stepsGroupByHand() throws {
        var steps: [Step<CribMazeGame>] = []
        let (run, opening) = try botGame(config, seed: 3) { steps.append($0) }
        #expect(opening.hand == nil)
        #expect(steps.map { $0.hand ?? 0 } == steps.map { $0.hand ?? 0 }.sorted())
        for s in steps {
            for e in s.events { if case .handStart(let h, _, _, _, _) = e { #expect(s.hand == h) } }
            for e in s.events { if case .handEnd(let r) = e { #expect(s.hand == r.turn) } }
        }
        #expect(Set(steps.compactMap(\.hand)) == Set(1...(config.rules.game?.turns ?? 1)))
        #expect(steps.last?.events.last.map { if case .gameEnd = $0 { true } else { false } } == true)
        #expect(run.state.over)
    }

    /// Actions and events are written flat, the match turn's beside the game's.
    @Test func writesActionsAndEventsFlat() throws {
        let enc = JSONEncoder(); enc.outputFormatting = .sortedKeys
        let a: [CribMazeGame.Action] = [.startHand(.init(deal: false, cardBudget: 0)), .discard(thrown: [CardRef(Card(standard: 4))]), .match(.trace(positions: [0, 1])), .match(.endTurn)]
        let text = try a.map { String(decoding: try enc.encode($0), as: UTF8.self) }
        #expect(text[0].hasPrefix(#"{"startHand":{"options":{"#))
        #expect(text[1] == #"{"discard":{"thrown":[{"card":"5S","id":4}]}}"#)
        #expect(text[2] == #"{"trace":{"positions":[0,1]}}"#)
        #expect(try a == text.map { try JSONDecoder().decode(CribMazeGame.Action.self, from: Data($0.utf8)) })
        let (_, opening) = try botGame(config, seed: 2)
        let back = try JSONDecoder().decode([CribMazeGame.Event].self, from: enc.encode(opening.events))
        #expect(back == opening.events)
    }

    @Test func refusesActionsOutOfTurn() throws {
        var (run, _) = GameRun<CribMazeGame>.start(.init(config), seed: 1, players: [.human(0), .bot(1, level: "classic")])
        #expect(throws: IllegalAction.self) { try run.send(.match(.endTurn), by: 0, clockMs: 0) }
        _ = try run.send(.startHand(.init()), by: 0, clockMs: 0)
        #expect(throws: IllegalAction.self) { try run.send(.discard(thrown: []), by: 0, clockMs: 0) }
        guard case .dealing(let dealt, _, _) = run.state.stage else { Issue.record("no deal"); return }
        let step = try run.send(.discard(thrown: dealt.player.prefix(2).map(CardRef.init)), by: 0, clockMs: 0)
        #expect(step.events.contains { if case .match(.turnStart) = $0 { true } else { false } })
        #expect(throws: IllegalAction.self) { try run.send(.startHand(.init()), by: 0, clockMs: 0) }
    }
}
