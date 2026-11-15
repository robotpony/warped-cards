import CardKit
import Foundation
import GameKit
import Testing
@testable import CribMaze

let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../..").standardized
let configFolder = repo.appendingPathComponent("cribbage/minigames/config")
func loadConfig() throws -> Config { try Config.load(from: configFolder) }
func json<T: Encodable>(_ v: T) -> String { let e = JSONEncoder(); e.outputFormatting = .sortedKeys; return String(data: try! e.encode(v), encoding: .utf8)! }

@Suite struct ConfigTests {
    @Test func repoConfigLoads() throws {
        let c = try loadConfig()
        #expect(c.rules.rulesVersion == MatchTurn.rulesVersion)
        #expect(c.rules.match.maxSet == 5)
        #expect(c.jokers.tables["amber"]?.entries.map(\.1) == [90, 9, 1])
    }
    @Test func badConfigFails() throws {
        var c = try loadConfig()
        c.rules.match.prize.epicAt = 1
        #expect(throws: ConfigError.self) { try c.validate() }
    }
}

@Suite struct BoardTests {
    @Test func positions() {
        #expect(Board.name(0) == "g00" && Board.name(15) == "g33" && Board.name(16) == "h0" && Board.name(20) == "c0" && Board.name(24) == "s")
        #expect(Board.touching(Board.g(3, 3), Board.starter))
        #expect(Board.touching(Board.g(3, 0), 16) && Board.touching(Board.g(3, 0), 17) && !Board.touching(Board.g(3, 0), 18))
        #expect(Board.touching(Board.g(0, 3), 20) && !Board.touching(16, 20))
    }
    @Test func lines() {
        #expect(MatchTurn.isLine([0, 1, 2, 3]))
        #expect(MatchTurn.isLine([0, 5, 10, 15]))
        #expect(MatchTurn.isLine([3, 6]))
        #expect(!MatchTurn.isLine([0, 2]))
        #expect(!MatchTurn.isLine([0, 1, 5]))
        #expect(!MatchTurn.isLine([15, 24]))
    }
    @Test func connectedSetsAreConnectedAndOrdered() {
        let sets = MatchTurn.sets(maxSize: 3)
        #expect(sets.allSatisfy { Board.connected($0) && $0 == $0.sorted() })
        #expect(sets.first == [0, 1])
        #expect(Set(sets.map { $0.description }).count == sets.count)
    }
}

@Suite struct MatchTurnTests {
    @Test func sameSeedSameTurn() throws {
        let c = try loadConfig()
        let (a, ea) = MatchTurn.start(config: c, setup: TurnSetup(seed: 7))
        let (b, eb) = MatchTurn.start(config: c, setup: TurnSetup(seed: 7))
        #expect(json(ea) == json(eb))
        #expect(a.state == b.state)
        let (_, ec) = MatchTurn.start(config: c, setup: TurnSetup(seed: 8))
        #expect(json(ea) != json(ec))
    }

    @Test func setupShape() throws {
        let c = try loadConfig()
        let (t, ev) = MatchTurn.start(config: c, setup: TurnSetup(seed: 1, dealer: false, fixedHand: ["5H", "5C", "5S", "JD"], fixedStarter: "5D"))
        #expect(t.state.cells[16]?.notation == "5H" && t.state.cells[24]?.notation == "5D")
        #expect(Board.crib.allSatisfy { t.state.cells[$0] == nil })
        #expect(Board.grid.allSatisfy { t.state.cells[$0]?.isPlaying == true })   // extras resolved
        guard case .turnStart(_, let dealer, let hand, _, _, _, _, _, _, _, let tray) = ev[0] else { Issue.record("first event"); return }
        #expect(!dealer && hand.count == 4 && tray == ["swapper": 2, "bomb": 1])
    }

    @Test func traceRejections() throws {
        let c = try loadConfig()
        var (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: 3))
        func reason(_ ps: [Pos]) throws -> String? {
            if case .traceRejected(_, let r) = try t.apply(.trace(positions: ps)).first { return r }
            return nil
        }
        #expect(try reason([0]) == "size")
        #expect(try reason([16, 17]) == "no_grid_card")
        #expect(try reason([0, 2]) == "not_touching")
        #expect(try reason([0, 0]) == "size")
    }

    @Test func scoringAndRules() throws {
        // Play every turn greedily with the first scoring set until it ends; check the totals add up.
        let c = try loadConfig()
        for seed in UInt64(1)...30 {
            var (t, events) = MatchTurn.start(config: c, setup: TurnSetup(seed: seed, warned: true))
            var guardN = 0
            while !t.state.over, guardN < 200 {
                guardN += 1
                let set = MatchTurn.sets(maxSize: 5).first { t.traceProblem($0) == nil && (t.value(of: $0)?.points ?? 0) > 0 }
                events += try t.apply(set.map { .trace(positions: $0) } ?? .endTurn)
            }
            #expect(t.state.over)
            var steps = 0
            for e in events {
                switch e {
                case .score(_, _, _, _, _, _, _, _, let p, _, _, _): steps += p
                case .leftoverPenalty(_, _, let cost): steps -= cost
                case .boardCleared(_, let a): steps += a
                case .extraDrawn(_, let o, _, _, _, _): if o == "steps" { steps += c.jokers.outcomes["steps"]!.amount! }
                default: break
                }
            }
            #expect(steps == t.state.steps, "seed \(seed)")
            guard case .turnEnd(_, let totals) = events.last else { Issue.record("last event"); continue }
            #expect(totals.steps == t.state.steps)
        }
    }

    @Test func leftOverWarningThenCost() throws {
        let c = try loadConfig()
        var (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: 5))
        // Find a set with combos and a card left over.
        guard let set = MatchTurn.sets(maxSize: 5).first(where: { t.traceProblem($0) == nil && (t.value(of: $0).map { !$0.count.combos.isEmpty && $0.leftOver > 0 } ?? false) }) else { return }
        let first = try t.apply(.trace(positions: set))
        guard case .leftoverWarning = first.first else { Issue.record("expected a warning"); return }
        let second = try t.apply(.trace(positions: set))
        guard case .score(_, _, _, _, _, _, let left, let cost, _, _, _, _) = second.first else { Issue.record("expected a score"); return }
        #expect(left > 0 && cost == left * c.rules.match.leftOverCost)
    }

    @Test func scriptedReplayMatches() throws {
        let c = try loadConfig()
        var (t, ev) = MatchTurn.start(config: c, setup: TurnSetup(seed: 11, warned: true))
        var actions: [MatchAction] = []
        while !t.state.over {
            let set = MatchTurn.sets(maxSize: 5).first { t.traceProblem($0) == nil && (t.value(of: $0)?.points ?? 0) > 0 }
            let a: MatchAction = set.map { .trace(positions: $0) } ?? .endTurn
            actions.append(a); ev += try t.apply(a)
        }
        let rolls = t.dice.rolls
        var (r, rev) = MatchTurn.start(config: c, setup: TurnSetup(seed: 11, warned: true), dice: Dice(scripted: rolls, seed: 0))
        for a in actions { rev += try r.apply(a) }
        #expect(json(ev) == json(rev))
    }

    @Test func specialsAreUsedUp() throws {
        let c = try loadConfig()
        var (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: 2))
        _ = try t.apply(.swap(line: [0, 1], source: nil))
        _ = try t.apply(.swap(line: [4, 5, 6], source: nil))
        #expect(throws: IllegalAction.self) { try t.apply(.swap(line: [0, 1], source: nil)) }
        _ = try t.apply(.bomb(target: 5, source: nil))
        #expect(t.state.tray["bomb"] == 0)
    }
}

@Suite struct EngineRules {
    /// ARCHITECTURE.md › Rules for the engine: no unseeded randomness, no wall clock.
    @Test func noBannedCalls() throws {
        let banned = ["SystemRandomNumberGenerator", "Int.random", ".random(in", "shuffled()", "UUID()", "Date()", "Date.now", "CFAbsoluteTime"]
        let src = repo.appendingPathComponent("swift/Sources")
        let files = FileManager.default.enumerator(at: src, includingPropertiesForKeys: nil)!.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" && !$0.path.contains("cribmaze-sim") }
        for f in files {
            let text = try String(contentsOf: f, encoding: .utf8)
            for b in banned { #expect(!text.contains(b), "\(f.lastPathComponent) uses \(b)") }
        }
    }
}
