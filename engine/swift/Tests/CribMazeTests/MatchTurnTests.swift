import CardKit
import Foundation
import GameKit
import Testing
@testable import CribMaze
import CribMazeBots

let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../..").standardized
let configFolder = repo.appendingPathComponent("cribbage/minigames/config")
func loadConfig() throws -> Config { try Config.load(from: configFolder) }
func json<T: Encodable>(_ v: T) -> String { let e = JSONEncoder(); e.outputFormatting = .sortedKeys; return String(data: try! e.encode(v), encoding: .utf8)! }

@Suite struct ConfigTests {
    @Test func repoConfigLoads() throws {
        let c = try loadConfig()
        #expect(c.rules.rulesVersion == MatchTurn.rulesVersion)
        #expect(c.rules.match.maxSet == 4)
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
        guard case .turnStart(_, let dealer, let hand, _, _, _, _, _, _, _, let tray, _) = ev[0] else { Issue.record("first event"); return }
        #expect(!dealer && hand.count == 4 && tray == ["swapper": 2, "bomb": 1, "reach": 1, "burn": 1])
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
                case .opening(_, _, _, _, _, _, let p, _): steps += p
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
        let src = repo.appendingPathComponent("engine/swift/Sources")
        let files = FileManager.default.enumerator(at: src, includingPropertiesForKeys: nil)!.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" && !$0.path.contains("cribmaze-sim") }
        for f in files {
            let text = try String(contentsOf: f, encoding: .utf8)
            for b in banned { #expect(!text.contains(b), "\(f.lastPathComponent) uses \(b)") }
        }
    }
}

/// Match rules r16: the starter counts with every set.
@Suite struct StarterJoinsTests {
    func config(_ joins: Bool) throws -> Config { var c = try loadConfig(); c.rules.match.starterJoins = joins; return c }

    @Test func starterCountsWithEverySet() throws {
        let c = try config(true)
        var sawUsed = false, sawUnused = false
        for seed in UInt64(1)...40 {
            let (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: seed, fixedHand: ["AH", "AC", "AS", "JD"], fixedStarter: "5D"))
            for set in MatchTurn.sets(maxSize: 3) where !set.contains(Board.starter) && t.traceProblem(set) == nil {
                guard let v = t.value(of: set) else { continue }
                #expect(v.counted == set + [Board.starter])
                let used = v.count.combos.contains { $0.cards.contains(set.count) }
                #expect(v.inSet == (used ? v.counted : set))
                #expect(v.leftOver == v.count.leftOver.filter { $0 != set.count }.count)   // never left over
                if used { sawUsed = true } else { sawUnused = true }
            }
        }
        #expect(sawUsed && sawUnused)
    }

    @Test func starterIsFreeUnderTheCounter() throws {
        let c = try config(true)
        let (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: 3))
        let four = [Board.g(3, 3), Board.g(3, 2), Board.g(2, 3), Board.g(2, 2)]
        #expect(t.traceProblem(four + [Board.starter]) != "size")
        #expect(t.traceProblem(four + [Board.g(3, 1)]) == "size")   // a fifth picked card is over the limit
        #expect(t.traceProblem([Board.g(3, 3), Board.starter]) == "size")   // one picked card isn't a set
        #expect(t.picked(four + [Board.starter]) == four && t.pickLimit == 4)
    }

    @Test func scoreNamesTheStarterOnlyWhenItScores() throws {
        let c = try config(true)
        var checked = 0
        for seed in UInt64(1)...30 {
            var (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: seed, warned: true, fixedHand: ["AH", "AC", "AS", "JD"], fixedStarter: "5D"))
            guard let set = MatchTurn.sets(maxSize: 2).first(where: { !$0.contains(Board.starter) && t.traceProblem($0) == nil && !(t.value(of: $0)?.count.combos.isEmpty ?? true) }),
                  let v = t.value(of: set) else { continue }
            let before = t.state.power[Board.starter]
            let ev = try t.apply(.trace(positions: set))
            guard case .score(let names, _, _, _, _, _, _, _, let points, _, _, _) = ev[0] else { Issue.record("no score"); continue }
            #expect(points == v.points)
            #expect(names.contains("s") == v.inSet.contains(Board.starter))
            #expect(t.state.power[Board.starter] == before + (v.inSet.contains(Board.starter) ? 1 : 0))
            checked += 1
        }
        #expect(checked > 10)
    }

    @Test func offByDefault() throws {
        let (t, _) = MatchTurn.start(config: try config(false), setup: TurnSetup(seed: 3))
        #expect(!t.starterJoins)
        let set = [Board.g(0, 0), Board.g(0, 1)]
        #expect(t.value(of: set)?.counted == set)
    }
}

/// r18: flushes count like a classic hand, and a joining starter never costs a set points.
@Suite struct HandFlushTests {
    func turn(_ hand: [String], _ starter: String, handFlush: Bool = true) throws -> MatchTurn {
        var c = try loadConfig(); c.rules.match.starterJoins = true; c.rules.match.handFlush = handFlush
        return MatchTurn.start(config: c, setup: TurnSetup(seed: 1, fixedHand: hand, fixedStarter: starter)).0
    }
    func flush(_ v: SetValue?) -> Int? { v?.count.combos.first { $0.kind == .flush }?.size }

    // The hand row's 4 cards are counted directly (value(of:) doesn't need a legal trace).
    @Test func fourPickedOfOneSuitAreAFlushWhateverTheStarter() throws {
        #expect(flush(try turn(["2H", "4H", "8H", "QH"], "KS").value(of: Array(Board.hand))) == 4)
        #expect(flush(try turn(["2H", "4H", "8H", "QH"], "KH").value(of: Array(Board.hand))) == 5)
        #expect(flush(try turn(["2H", "4H", "8H", "QH"], "KS", handFlush: false).value(of: Array(Board.hand))) == nil)   // r17
    }

    @Test func noThreeCardFlushes() throws {
        let three = Array(Board.hand.prefix(3))
        #expect(flush(try turn(["2H", "4H", "8H", "QC"], "KS").value(of: three)) == nil)
        #expect(flush(try turn(["2H", "4H", "8H", "QC"], "KH").value(of: three)) == 4)   // with a matching starter
    }

    @Test func theStarterNeverCostsPoints() throws {
        var c = try loadConfig(); c.rules.match.starterJoins = true; c.rules.match.handFlush = true
        for seed in UInt64(1)...6 {
            let t = MatchTurn.start(config: c, setup: TurnSetup(seed: seed)).0
            for set in MatchTurn.sets(maxSize: 4) where !set.contains(Board.starter) && t.traceProblem(set) == nil {
                guard let v = t.value(of: set) else { continue }
                var off = c; off.rules.match.starterJoins = false
                let alone = MatchTurn.start(config: off, setup: TurnSetup(seed: seed)).0.value(of: set)
                #expect(v.points >= (alone?.points ?? .min))
            }
        }
    }
}


/// r19: the reach joker raises the pick limit until the app (or the simulator) ends it.
@Suite struct ReachJokerTests {
    func turn(seed: UInt64 = 1) throws -> MatchTurn {
        MatchTurn.start(config: try loadConfig(), setup: TurnSetup(seed: seed, tray: ["reach": 2])).0
    }

    @Test func reachRaisesThePickLimitUntilItsOver() throws {
        var t = try turn()
        let base = t.pickLimit
        let ev = try t.apply(.reach(source: nil))
        guard case .reach(let id, let cards, let seconds, let limit, let source) = ev[0] else { Issue.record("no reach event"); return }
        let cfg = t.config.rules.specials.reach!
        #expect(cfg.cards.map { $0[0] }.contains(cards) && cfg.seconds.map { $0[0] }.contains(seconds))
        #expect(limit == base + cards && t.pickLimit == base + cards && source == "tray")
        #expect(t.state.tray["reach"] == 1 && t.state.totals.reaches == 1)
        let over = try t.apply(.reachOver(id: id))
        guard case .reachOver(id, let after) = over[0] else { Issue.record("no reachOver event"); return }
        #expect(after == base && t.pickLimit == base)
        #expect(throws: IllegalAction.self) { try t.apply(.reachOver(id: id)) }   // already over
    }

    @Test func reachesStackAndRollTheSameForTheSameSeed() throws {
        var a = try turn(seed: 7), b = try turn(seed: 7)
        let e1 = try a.apply(.reach(source: nil)) + a.apply(.reach(source: nil))
        let e2 = try b.apply(.reach(source: nil)) + b.apply(.reach(source: nil))
        #expect(e1 == e2)
        #expect(a.pickLimit == a.config.rules.match.maxSet + a.state.reaches.map(\.cards).reduce(0, +) && a.state.reaches.count == 2)
        #expect(throws: IllegalAction.self) { try a.apply(.reach(source: nil)) }   // the tray is empty
    }

    @Test func aSetOverTheBaseLimitScoresOnlyUnderAReach() throws {
        var t = try turn()
        let five = MatchTurn.sets(maxSize: 6).first { t.picked($0).count == t.pickLimit + 1 && !$0.contains(where: { t.state.cells[$0]?.isSpecial ?? true }) && $0.contains(where: Board.isGrid) }!
        #expect(t.traceProblem(five) == "size")
        while t.pickLimit < t.picked(five).count { _ = try t.apply(.reach(source: nil)) }
        #expect(t.traceProblem(five) == nil)
    }

    @Test func configChecksTheReachTables() throws {
        var c = try loadConfig()
        c.rules.specials.reach?.cards = [[3, 10]]   // 4 + 3 is over 6
        #expect(throws: ConfigError.self) { try c.validate() }
        c.rules.specials.reach = nil
        #expect(throws: ConfigError.self) { try c.validate() }
    }
}

/// r20: a card a joker makes carries a small multiplier, which multiplies the sets it's in.
@Suite struct MadeMultiplierTests {
    @Test func madeCardsCarryAMultiplierThatMultipliesTheirSets() throws {
        let c = try loadConfig()
        let table = Set(c.jokers.madeWeights.map(\.0))
        let bot = MatchBot(config: c, id: "medium")!
        var made = 0, scored = 0
        for seed in UInt64(1)...25 {
            var (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: seed, warned: true))
            var steps = 0
            while !t.state.over && steps < 80 {
                steps += 1
                var d = t.dice
                let a = bot.choose(t, dice: &d)
                t.dice = d
                if case .trace(let ps) = a, let v = t.value(of: ps) {
                    var m = 100
                    for p in v.inSet { if let pct = t.state.cells[p]?.percent { m = (m * pct + 50) / 100 } }
                    m = min(m, c.jokers.madeCapPercent ?? m)
                    #expect(v.madePercent == m && v.percent == (v.edgePercent * m + 50) / 100)
                    if m > 100 { scored += 1 }
                }
                _ = try t.apply(a)
                for p in Board.grid { if let card = t.state.cells[p], card.kind == .made { #expect(card.percent.map(table.contains) == true); made += 1 } }
            }
        }
        #expect(made > 0 && scored > 0)
    }
}

/// Discard principles (concept.md › Hints): which apply to a deal, and which one a hint shows.
@Suite struct PrincipleTests {
    func deal(_ s: String) -> [Card] { s.split(separator: " ").compactMap { Card.parse(String($0)) } }

    @Test func principlesFindTheirCards() {
        let hits = Dictionary(Principles.applying(to: deal("4H 5C 6D 6S KC 9D")).map { ($0.principle, $0.cards.map(\.notation)) }, uniquingKeysWith: { a, _ in a })
        #expect(hits[.keepFives] == ["5C"])
        #expect(hits[.runMiddle] == ["5C"])
        #expect(hits[.twoWays] != nil && hits[.noFlushChase] == nil)
        let flush = Principles.applying(to: deal("2H 4H 8H QH 5C KS")).first { $0.principle == .noFlushChase }
        #expect(flush?.cards.count == 4)
        #expect(Principles.follows(deal("4H QH 5C KS"), flush!) && !Principles.follows(deal("2H 4H 8H QH"), flush!))
    }

    @Test func aHintShowsTheMostValuableProvenPrinciple() throws {
        let hints = try #require(try loadConfig().hints).discard
        let best = Principles.best(for: deal("4H 5C 6D 6S KC 9D"), hints: hints)
        #expect(best?.principle == .twoWays)
        // The flush principle isn't shown: it hasn't been shown to pay.
        #expect(Principles.best(for: deal("2H 4H 8H QH 7C KS"), hints: hints)?.principle != .noFlushChase)
    }
}

/// The deal before a match turn: 6 each, 2 each to the crib, the bot keeping its best classic hand.
@Suite struct DealTests {
    @Test func aDealSetsUpTheTurnWithTheKeptHandsAndCrib() throws {
        let c = try loadConfig()
        let d = Deal.deal(seed: 9)
        #expect(d == Deal.deal(seed: 9))
        #expect(Set((d.player + d.bot + [d.starter]).map(\.id)).count == 13)
        let mine = Array(d.player.suffix(2)), bot = Deal.classicKeep(d.bot)
        #expect(bot.keep.count == 4 && bot.thrown.count == 2)
        for dealer in [true, false] {
            let (t, _) = MatchTurn.start(config: c, setup: Deal.setup(seed: 9, dealer: dealer, dealt: d, thrown: mine, botThrown: bot.thrown))
            #expect(Board.hand.map { t.state.cells[$0]!.id } == d.player.prefix(4).map(\.id))
            #expect(t.state.cells[Board.starter]?.id == d.starter.id)
            if dealer { #expect(Set(Board.crib.map { t.state.cells[$0]!.id }) == Set((mine + bot.thrown).map(\.id))) }
            // Nothing dealt is in the stock or on the grid.
            let onBoard = Board.grid.compactMap { t.state.cells[$0]?.id } + t.state.stock.map(\.id)
            #expect(Set(onBoard).isDisjoint(with: (d.player + d.bot + [d.starter]).map(\.id)))
        }
    }

    @Test func classicKeepTakesTheBestHand() {
        let six = "4H 5C 6D 6S KC 9D".split(separator: " ").compactMap { Card.parse(String($0)) }
        #expect(Set(Deal.classicKeep(six).thrown.map(\.notation)) == ["KC", "9D"])
    }
}

// Match rules r24: the opening count, the hand and crib limit in a set, and the kept order.
@Suite struct OpeningTests {
    @Test func countsHandAndCribBeforeTheGrid() throws {
        let c = try loadConfig()
        var setup = TurnSetup(seed: 3, dealer: true, warned: true, fixedHand: ["5H", "5D", "10S", "JC"], fixedStarter: "5C")
        setup.fixedCrib = ["AH", "2H", "3H", "4H"]
        let (t, ev) = MatchTurn.start(config: c, setup: setup)
        let openings = ev.compactMap { e -> (String, Int, [String])? in
            if case .opening(let w, let ps, _, _, _, _, let p, _) = e { return (w, p, ps) } else { return nil }
        }
        #expect(openings.map(\.0) == ["hand", "crib"])
        // 5 5 5 10 J: fifteens 5+10 ×3, 5+J ×3, 5+5+5 = 14; three 5s = 6; nobs (JC, 5C) = 1. 21 in all.
        #expect(openings[0].1 == 21)
        #expect(openings[0].2 == ["h0", "h1", "h2", "h3", "s"])
        // A 2 3 4 hearts, 5C: run of 5 = 5, fifteen A+2+3+4+5 = 2; no crib flush without the starter. 7.
        #expect(openings[1].1 == 7)
        #expect(t.state.totals.openingSteps == 28)
        #expect(t.state.steps >= 28)
        #expect(t.state.bestPoints == nil)
        // Nobody powers up from the opening count.
        #expect((16...24).allSatisfy { t.state.power[$0] == c.rules.match.edgePower.start })
    }

    // r26/r27: a power joker for every 5 points past 6, for each count on its own.
    @Test func aHighCountWinsPowerJokers() throws {
        let c = try loadConfig()
        var setup = TurnSetup(seed: 3, dealer: true, warned: true, fixedHand: ["5H", "5D", "10S", "JC"], fixedStarter: "5C")
        setup.fixedCrib = ["AH", "2H", "3H", "4H"]
        let (t, ev) = MatchTurn.start(config: c, setup: setup)
        let bonus = ev.compactMap { e -> [String]? in if case .opening(_, _, _, _, _, _, _, let b) = e { b } else { nil } }
        // The hand's 21 is 15 past 6: 3 jokers. The crib's 7 wins none.
        #expect(bonus.map(\.count) == [3, 0])
        #expect(bonus[0].allSatisfy { c.rules.specials.known.contains($0) })
        // The turnStart tray, before the counts, plus the 3 won.
        guard case .turnStart(_, _, _, _, _, _, _, _, _, _, let before, _) = ev[0] else { Issue.record("no turnStart"); return }
        var want = before; for k in bonus[0] { want[k, default: 0] += 1 }
        let extrasToTray = ev.contains { if case .extraDrawn(_, _, _, _, "tray", _) = $0 { true } else { false } }
        if !extrasToTray { #expect(t.state.tray == want) }
        #expect(t.state.totals.openingJokers == 3)
        // Exactly 11 is one joker; 10 none.
        for (pts, want) in [(10, 0), (11, 1), (15, 1), (16, 2), (29, 4)] {
            let b = c.rules.match.opening!.bonus!
            #expect((pts > b.from ? (pts - b.from) / b.per : 0) == want)
        }
    }

    @Test func nonDealerCountsOnlyTheHand() throws {
        let c = try loadConfig()
        let (_, ev) = MatchTurn.start(config: c, setup: TurnSetup(seed: 3, dealer: false, warned: true, fixedHand: ["5H", "5D", "10S", "JC"], fixedStarter: "5C"))
        let whats = ev.compactMap { e -> String? in if case .opening(let w, _, _, _, _, _, _, _) = e { w } else { nil } }
        #expect(whats == ["hand"])
    }

    @Test func aSetTakesOneHandOrCribCard() throws {
        let c = try loadConfig()
        var setup = TurnSetup(seed: 3, dealer: true, warned: true, fixedHand: ["5H", "5D", "10S", "JC"], fixedStarter: "5C")
        setup.fixedCrib = ["AH", "2H", "3H", "4H"]
        let (t, _) = MatchTurn.start(config: c, setup: setup)
        let h2 = Board.hand.lowerBound + 2, h3 = Board.hand.lowerBound + 3, c3 = Board.crib.lowerBound + 3
        let g32 = 14, g33 = 15
        #expect(t.traceProblem([g32, h2, h3]) == "edge_cards")
        #expect(t.traceProblem([g33, h3, c3]) == "edge_cards")
        #expect(t.traceProblem([g32, h3]) != "edge_cards")
    }

    @Test func keptOrderLaysTheHandRow() throws {
        let c = try loadConfig()
        var dice = Dice(seed: 9)
        var (state, _) = CribMazeGame.start(.init(c, firstDealer: true), players: [.human(0), .bot(1, level: "classic")], dice: &dice)
        let ev = try CribMazeGame.apply(.startHand(.init(deal: true, warned: true)), by: 0, to: &state, dice: &dice)
        guard case .deal(let player, _, _) = ev.last else { Issue.record("no deal"); return }
        let thrown = Array(player.prefix(2)), kept = Array(player.suffix(4).reversed())
        let e2 = try CribMazeGame.apply(.discard(thrown: thrown, kept: kept), by: 0, to: &state, dice: &dice)
        guard case .discard(let k, _, _, _) = e2.first else { Issue.record("no discard"); return }
        #expect(k.map(\.id) == kept.map(\.id))
        let hand = Board.hand.map { state.turn!.state.cells[$0]!.id }
        #expect(hand == kept.map(\.id))
        // kept must be the other 4, each once.
        var again = CribMazeGame.start(.init(c, firstDealer: true), players: [.human(0), .bot(1, level: "classic")], dice: &dice).0
        _ = try CribMazeGame.apply(.startHand(.init(deal: true, warned: true)), by: 0, to: &again, dice: &dice)
        guard case .dealing(let d, _, _) = again.stage else { Issue.record("not dealing"); return }
        let bad = [CardRef(d.player[2]), CardRef(d.player[2]), CardRef(d.player[3]), CardRef(d.player[4])]
        #expect(throws: IllegalAction.self) { try CribMazeGame.apply(.discard(thrown: d.player.prefix(2).map(CardRef.init), kept: bad), by: 0, to: &again, dice: &dice) }
    }
}

/// r28: the key joker raises the pick limit for the game, or for a while like a reach.
@Suite struct KeyJokerTests {
    /// A config whose keys always roll `lasts`.
    func config(_ lasts: String) throws -> Config {
        var c = try loadConfig()
        c.rules.specials.key?.lasts = Weights([(lasts, 1)])
        return c
    }

    @Test func aTimedKeyIsAReachThatReachOverEnds() throws {
        var t = MatchTurn.start(config: try config("timed"), setup: TurnSetup(seed: 1, tray: ["key": 1])).0
        let base = t.pickLimit
        let ev = try t.apply(.key(source: nil))
        guard case .key(let id?, 1, "timed", let seconds?, let limit, "tray") = ev[0] else { Issue.record("no timed key event"); return }
        #expect(t.config.rules.specials.key!.seconds.map { $0[0] }.contains(seconds))
        #expect(limit == base + 1 && t.state.keyCards == 0 && t.state.tray["key"] == 0)
        #expect(ev[0].startedReach?.id == id)
        _ = try t.apply(.reachOver(id: id))
        #expect(t.pickLimit == base && t.state.totals.keys == 1 && t.state.totals.keysForGame == 0)
        #expect(throws: IllegalAction.self) { try t.apply(.key(source: nil)) }   // none left
    }

    @Test func aKeyForTheGameLastsIntoTheNextTurn() throws {
        let c = try config("game")
        var g = MatchGame(config: c, seed: 3)
        var setup = g.setup(); setup.tray = ["key": 1]
        var (t, ev) = MatchTurn.start(config: c, setup: setup)
        let base = t.pickLimit
        let e = try t.apply(.key(source: nil))
        guard case .key(nil, 1, "game", nil, let limit, "tray") = e[0] else { Issue.record("no game key event"); return }
        #expect(e[0].startedReach == nil && limit == base + 1 && t.state.reaches.isEmpty && t.state.totals.keysForGame == 1)
        ev += e
        ev += try t.apply(.endTurn)
        g.finish(t, events: ev)
        #expect(g.keyCards == 1)
        let (next, start) = MatchTurn.start(config: c, setup: g.setup())
        #expect(next.pickLimit == base + 1)
        guard case .turnStart(_, _, _, _, _, _, _, _, _, _, _, 1) = start[0] else { Issue.record("turnStart has no keyCards"); return }
    }

    @Test func thePickLimitStopsAtMaxPick() throws {
        let c = try config("game")
        var t = MatchTurn.start(config: c, setup: TurnSetup(seed: 1, tray: ["key": 4, "reach": 2])).0
        for _ in 0..<4 { _ = try t.apply(.key(source: nil)) }
        _ = try t.apply(.reach(source: nil)); _ = try t.apply(.reach(source: nil))
        #expect(t.state.keyCards == 4 && t.pickLimit == c.rules.match.maxPick!)
    }

    @Test func configChecksTheKey() throws {
        var c = try loadConfig()
        c.rules.specials.key?.lasts = Weights([("forever", 1)])
        #expect(throws: ConfigError.self) { try c.validate() }
        c = try loadConfig(); c.rules.match.maxPick = nil
        #expect(throws: ConfigError.self) { try c.validate() }
        c = try loadConfig(); c.rules.match.maxPick = 7
        #expect(throws: ConfigError.self) { try c.validate() }
        c = try loadConfig(); c.rules.specials.key = nil
        #expect(throws: ConfigError.self) { try c.validate() }
    }
}
