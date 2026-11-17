import Foundation
import GameKit
import Testing
@testable import GameRecord

/// A toy game for GameRecord: a few hands of calling coin flips. Each hand starts its dice again
/// from its own seed, as Crib Maze's hands do.
enum Coins: GameRules {
    struct Config: Codable, Sendable { var hands = 3, flips = 4 }
    struct State: Sendable { var config: Config; var hand = 0, flipped = 0, right = 0, inHand = false, over = false }
    enum Action: Codable, Sendable, Equatable { case startHand, call(heads: Bool) }
    enum Event: Codable, Sendable, Equatable { case gameStart(hands: Int), handStart(hand: Int), flip(heads: Bool, right: Bool), handEnd(hand: Int), gameEnd(right: Int) }
    struct Result: Codable, Sendable, Equatable { let right: Int }

    static let gameID = "coins"
    static let rulesVersion = "coins-r1"

    static func start(_ config: Config, players: [PlayerSeat], dice: inout Dice) -> (State, [Event]) {
        (State(config: config), [.gameStart(hands: config.hands)])
    }

    static func apply(_ action: Action, by player: PlayerID?, to s: inout State, dice: inout Dice) throws -> [Event] {
        switch action {
        case .startHand:
            guard !s.inHand, !s.over else { throw IllegalAction("a hand is being played") }
            s.hand += 1; s.flipped = 0; s.inHand = true
            dice.reseed(fnv1a64("\(dice.seed)/hand\(s.hand)"))
            return [.handStart(hand: s.hand)]
        case .call(let heads):
            guard s.inHand else { throw IllegalAction("no hand") }
            let h = dice.below(2, stream: "coin", purpose: "flip") == 1
            s.flipped += 1
            if h == heads { s.right += 1 }
            var ev: [Event] = [.flip(heads: h, right: h == heads)]
            if s.flipped == s.config.flips {
                s.inHand = false; ev.append(.handEnd(hand: s.hand))
                if s.hand == s.config.hands { s.over = true; ev.append(.gameEnd(right: s.right)) }
            }
            return ev
        }
    }

    static func hand(of s: State) -> Int? { s.hand == 0 ? nil : s.hand }
    static func result(of s: State) -> Result? { s.over ? Result(right: s.right) : nil }
}

let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("GameRecordTests-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
let fixedClock: @Sendable () -> Date = { Date(timeIntervalSince1970: 1_763_175_723.12) }
let utcMinus8 = TimeZone(secondsFromGMT: -8 * 3600)!

/// Plays a whole toy game into a writer, always calling heads.
@discardableResult
func playCoins(seed: UInt64, to url: URL, config: Coins.Config = .init()) throws -> RecordWriter<Coins> {
    let w = try RecordWriter<Coins>(url: url, clock: fixedClock, timeZone: utcMinus8)
    var (run, opening) = GameRun<Coins>.start(config, seed: seed, players: [.human(0)])
    w.gameStarted(GameHeader(run, stamp: AppStamp(app: "test"), started: w.stamp(fixedClock())))
    w.record(opening)
    var clock = 0
    while run.result == nil {
        clock += 1500
        let a: Coins.Action = run.state.inHand ? .call(heads: true) : .startHand
        w.record(try run.send(a, by: 0, clockMs: clock))
        if case .startHand = a, run.state.hand == 1 { w.note("hint", ["shown": "calls"]) }
    }
    w.gameEnded(run.result!)
    return w
}

@Suite struct RecordTests {
    @Test func writesAndReadsBack() throws {
        let url = scratch.appendingPathComponent("a.jsonl")
        try playCoins(seed: 7, to: url)
        let r = try RecordReader<Coins>.read(url)
        #expect(r.header.game == "coins" && r.header.rules == "coins-r1" && r.header.seed == "7" && r.format == RecordFormat.version)
        #expect(r.header.started == "2025-11-14T19:02:03.120-08:00")
        #expect(r.steps.count == 1 + 3 * (1 + 4))
        #expect(r.steps.map(\.seq) == Array(1...16))
        #expect(r.steps.first?.hand == nil && r.steps.last?.hand == 3)
        #expect(r.steps.dropFirst().allSatisfy { $0.action != nil })
        #expect(r.notes.count == 1 && r.notes[0].after == 2 && r.notes[0].name == "hint")
        #expect(try r.notes[0].data(as: [String: String].self) == ["shown": "calls"])
        #expect(r.finished && !r.truncated)
        // Every line is one JSON object with its kind.
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        #expect(lines.first!.contains(#""kind":"header""#) && lines.last!.contains(#""kind":"end""#))
    }

    @Test func verifiesAndReplaysScripted() throws {
        let url = scratch.appendingPathComponent("b.jsonl")
        try playCoins(seed: 11, to: url)
        let r = try RecordReader<Coins>.read(url)
        let v = Replayer.check(r, mode: .verify), s = Replayer.check(r, mode: .scripted)
        #expect(v.ok, "\(v)"); #expect(s.ok, "\(s)")
        #expect(v.steps == 16)
    }

    @Test func stepsThrough() throws {
        let url = scratch.appendingPathComponent("c.jsonl")
        try playCoins(seed: 3, to: url)
        var rp = try Replayer(try RecordReader<Coins>.read(url))
        var n = 1
        while let st = try rp.step() { n += 1; #expect(st.seq == n) }
        #expect(rp.done && rp.run.result != nil)
    }

    /// A changed generator breaks verify but not scripted: here the seed stands in for it.
    @Test func scriptedSurvivesAGeneratorChange() throws {
        let url = scratch.appendingPathComponent("d.jsonl")
        try playCoins(seed: 5, to: url)
        let r = try RecordReader<Coins>.read(url)
        var h = r.header; h.seed = "6"
        let changed = Record(url: nil, header: h, format: r.format, steps: r.steps, stepTimes: r.stepTimes, notes: [], end: r.end, truncated: false)
        #expect(!Replayer.check(changed, mode: .verify).ok)
        #expect(Replayer.check(changed, mode: .scripted).ok)
    }

    @Test func catchesAChangedEvent() throws {
        let url = scratch.appendingPathComponent("e.jsonl")
        try playCoins(seed: 9, to: url)
        var text = try String(contentsOf: url, encoding: .utf8)
        // Flip the first coin's recorded outcome.
        let lines = text.split(separator: "\n").map(String.init)
        let i = lines.firstIndex { $0.contains(#""flip""#) }!
        let flipped = lines[i].contains(#""heads":true"#) ? lines[i].replacingOccurrences(of: #""heads":true"#, with: #""heads":false"#) : lines[i].replacingOccurrences(of: #""heads":false"#, with: #""heads":true"#)
        text = (lines[..<i] + [flipped] + lines[(i + 1)...]).joined(separator: "\n")
        let r = try RecordReader<Coins>.read(Data(text.utf8))
        let rep = Replayer.check(r)
        #expect(!rep.ok)
        #expect(rep.mismatch?.seq == r.steps.first { $0.events.contains { if case .flip = $0 { true } else { false } } }?.seq)
        // Scripted: the recorded roll no longer fits its event.
        #expect(!Replayer.check(r, mode: .scripted).ok)
    }

    /// ARCHITECTURE.md › Testing: the same seed and actions give byte-identical records.
    @Test func sameGameSameBytes() throws {
        let a = scratch.appendingPathComponent("f1.jsonl"), b = scratch.appendingPathComponent("f2.jsonl")
        try playCoins(seed: 21, to: a); try playCoins(seed: 21, to: b)
        #expect(try Data(contentsOf: a) == Data(contentsOf: b))
    }

    @Test func keepsWhatCameBeforeACutLine() throws {
        let url = scratch.appendingPathComponent("g.jsonl")
        try playCoins(seed: 2, to: url)
        var data = try Data(contentsOf: url)
        data.removeLast(30)   // the end line, cut short
        let r = try RecordReader<Coins>.read(data)
        #expect(r.truncated && !r.finished && r.steps.count == 16)
        #expect(Replayer.check(r).ok)
    }

    @Test func readsAFolderOfOneGame() throws {
        let dir = scratch.appendingPathComponent("folder", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        let start = fixedClock()
        let p1 = RecordWriter<Coins>.path(in: dir, started: start, timeZone: utcMinus8)
        #expect(p1.path.hasSuffix("2025-11-14/190203-coins.jsonl"))
        try playCoins(seed: 1, to: p1)
        let p2 = RecordWriter<Coins>.path(in: dir, started: start, timeZone: utcMinus8)
        #expect(p2.lastPathComponent == "190203-coins-2.jsonl")
        try playCoins(seed: 2, to: p2)
        try Data(#"{"kind":"header","format":1,"game":"other"}"#.utf8).write(to: dir.appendingPathComponent("x.jsonl"))
        let all = RecordReader<Coins>.readAll(dir)
        #expect(all.records.count == 2 && all.skipped.count == 1)
    }

    @Test func counts() throws {
        let url = scratch.appendingPathComponent("h.jsonl")
        try playCoins(seed: 4, to: url)
        var c = Counts()
        c.add(try RecordReader<Coins>.read(url))
        #expect(c.games == 1 && c.finished == 1 && c.hands == 3 && c.steps == 16 && c.actions == 15)
        #expect(c.events["flip"] == 12 && c.events["handStart"] == 3 && c.events["gameEnd"] == 1)
        #expect(c.actionTypes == ["startHand": 3, "call": 12])
        #expect(c.rolls == ["coin/flip": 12])
        #expect(c.rollValues["coin/flip"]!.values.reduce(0, +) == 12)
        #expect(c.gaps == 14 && c.gapMeanMs == 1500)
    }

    @Test func illegalActionsChangeNothing() throws {
        var (run, _) = GameRun<Coins>.start(.init(), seed: 1, players: [.human(0)])
        #expect(throws: IllegalAction.self) { try run.send(.call(heads: true), by: 0, clockMs: 0) }
        #expect(run.seq == 1)
    }
}
