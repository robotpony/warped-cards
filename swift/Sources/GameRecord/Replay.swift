// Replaying a record (ARCHITECTURE.md › Replay). Verify plays the recorded actions from the seed and
// checks every roll and event; scripted feeds the recorded rolls back instead of drawing them, so a
// game still replays after the generator or a stream changes. Either can step through one action
// at a time, for a replay viewer.
import Foundation
import GameKit

public enum ReplayMode: String, Sendable, CaseIterable {
    case verify, scripted
}

/// Where a replay first differs from its record.
public struct ReplayMismatch: Error, CustomStringConvertible, Sendable {
    public let seq: Int
    public let what: String
    public var description: String { "step \(seq): \(what)" }
}

public struct ReplayReport: Sendable, CustomStringConvertible {
    public let mode: ReplayMode
    /// Steps that matched, the opening step included.
    public let steps: Int
    public let mismatch: ReplayMismatch?
    /// Set when the record was made under other rules than this engine's.
    public let rulesNote: String?
    public var ok: Bool { mismatch == nil }
    public var description: String {
        (ok ? "ok, \(steps) steps" : "differs at \(mismatch!)") + (rulesNote.map { " (\($0))" } ?? "")
    }
}

public struct Replayer<G: GameRules> {
    public let record: Record<G>
    public let mode: ReplayMode
    /// The game as replayed so far.
    public private(set) var run: GameRun<G>
    /// The next recorded step to play (1 after the opening step).
    public private(set) var next = 1
    private let encoder = RecordFormat.encoder()

    /// Starts the replay and checks the opening step.
    public init(_ record: Record<G>, mode: ReplayMode = .verify) throws {
        guard let seed = record.header.seedValue else { throw RecordError("the seed \(record.header.seed) isn't a number") }
        guard let opening = record.steps.first, opening.action == nil else { throw RecordError("the record has no opening step") }
        self.record = record; self.mode = mode
        let dice: Dice? = mode == .scripted ? Dice(scripted: record.steps.flatMap(\.rolls), seed: seed) : nil
        let (run, step) = GameRun<G>.start(record.header.config, seed: seed, players: record.header.players, dice: dice, clockMs: opening.clockMs)
        self.run = run
        try check(step, against: opening)
    }

    public var done: Bool { next >= record.steps.count }

    /// Plays the next recorded action and checks what it did. Returns nil once every step is played.
    @discardableResult
    public mutating func step() throws -> Step<G>? {
        guard !done else { return nil }
        let want = record.steps[next]
        guard let action = want.action else { throw ReplayMismatch(seq: want.seq, what: "a step with no action after the opening") }
        let got: Step<G>
        do { got = try run.send(action, by: want.player, clockMs: want.clockMs) } catch { throw ReplayMismatch(seq: want.seq, what: "the engine refused the action: \(error)") }
        try check(got, against: want)
        next += 1
        return got
    }

    /// Plays every step, then checks the end: the result, and in scripted mode that every roll was used.
    public mutating func finish() throws {
        while try step() != nil {}
        let last = record.steps.last?.seq ?? 0
        if mode == .scripted, run.dice.scriptLeft > 0 { throw ReplayMismatch(seq: last, what: "\(run.dice.scriptLeft) recorded rolls left over") }
        switch (record.end, run.result) {
        case (let e?, let r?):
            if try json(e.result) != json(r) { throw ReplayMismatch(seq: last, what: "the result differs") }
        case (.some, nil): throw ReplayMismatch(seq: last, what: "the record ends the game, the replay doesn't")
        case (nil, .some) where !record.truncated: throw ReplayMismatch(seq: last, what: "the replay ends the game, the record doesn't")
        default: break
        }
    }

    /// Replays a whole record and says whether, and where, it differs.
    public static func check(_ record: Record<G>, mode: ReplayMode = .verify) -> ReplayReport {
        let note = record.header.rules == G.rulesVersion ? nil : "recorded under \(record.header.rules), engine is \(G.rulesVersion)"
        do {
            var r = try Replayer(record, mode: mode)
            try r.finish()
            return ReplayReport(mode: mode, steps: record.steps.count, mismatch: nil, rulesNote: note)
        } catch let m as ReplayMismatch {
            return ReplayReport(mode: mode, steps: m.seq - 1, mismatch: m, rulesNote: note)
        } catch {
            return ReplayReport(mode: mode, steps: 0, mismatch: ReplayMismatch(seq: 1, what: "\(error)"), rulesNote: note)
        }
    }

    private func check(_ got: Step<G>, against want: Step<G>) throws {
        func fail(_ what: String) -> ReplayMismatch { ReplayMismatch(seq: want.seq, what: what) }
        if let p = run.dice.scriptProblem { throw fail("scripted rolls out of step at \(p)") }
        if got.seq != want.seq { throw fail("the replay is at step \(got.seq)") }
        if got.hand != want.hand { throw fail("hand \(got.hand.map(String.init) ?? "none"), recorded \(want.hand.map(String.init) ?? "none")") }
        if got.rolls != want.rolls {
            let i = zip(got.rolls, want.rolls).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? min(got.rolls.count, want.rolls.count)
            throw fail("roll \(i + 1) of \(want.rolls.count) differs: \(i < got.rolls.count ? "\(got.rolls[i])" : "none") against \(i < want.rolls.count ? "\(want.rolls[i])" : "none")")
        }
        let g = try got.events.map(json), w = try want.events.map(json)
        if g != w {
            let i = zip(g, w).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? min(g.count, w.count)
            func text(_ list: [String]) -> String { i < list.count ? String(list[i].prefix(240)) : "none" }
            throw fail("event \(i + 1) of \(w.count) differs:\n  replay \(text(g))\n  record \(text(w))")
        }
    }

    private func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
}
