import CardKit
import CribbageKit
import Foundation
import GameKit
import GameRecord
import Testing
@testable import CribMaze
import CribMazeBots

/// A maze on seed 1's board with these seats' plays, seat 0's turn.
func testMaze(_ config: Config, seats: Int = 1, plays: [[MazePlay]]) -> Maze {
    let mc = config.maze!
    var m = Maze(config: mc, board: Maze.build(mc, seed: 1), seats: (0..<seats).map { PlayerSeat.bot($0, level: "medium") }, dice: Dice(seed: 1))
    _ = m.startHand(1, dealer: seats - 1, plays: plays, kept: [], jokers: [], gridSteps: [])
    return m
}

func play(_ id: Int, _ steps: Int, _ suit: String?) -> MazePlay { MazePlay(id: id, steps: steps, suit: suit, cards: [], from: "set") }

@Suite struct MazeWalkTests {
    let config = try! loadConfig()

    @Test func aWalkSpendsEveryStepOneCellAStep() throws {
        var m = testMaze(config, plays: [[play(1, 40, nil)]])
        let ev = try m.apply(.mazeWalk(play: 1, ways: nil), by: 0)
        guard case .walk(_, _, _, let path, let junctions, _, _, _, let end, _, _) = ev.first else { Issue.record("walk"); return }
        #expect(path.count + m.board.route.count > 0)
        var at = m.board.start
        for c in path { #expect(m.board.manhattan(at, c) == 1); at = c }
        #expect(end == at && m.tokens[0].pos == end)
        #expect(path.count <= 40)
        // Each junction crossed turned its arrow on, away from the way taken.
        for j in junctions { #expect(m.board.arrow[j.cell] != j.dir || m.board.liveExits(j.cell).count < 2) }
        #expect(m.turn == nil)   // the only play is used: the hand is done
    }

    /// A golden door whose cell before it has just the way back and the door.
    func doorAhead(_ m: Maze) -> (at: Int, door: Passage)? {
        let r = m.board.route
        for at in 2..<r.count {
            guard let k = m.board.key(r[at - 1], r[at]), let d = m.board.passages[k], d.kind == .door, d.suit != nil else { continue }
            if m.board.exits(r[at - 1]).count == 2 { return (at, d) }
        }
        return nil
    }

    @Test func aWrongSuitDoorStopsTheWalk() throws {
        var m = testMaze(config, plays: [[play(1, 30, nil), play(2, 30, "S")]])
        guard let (at, d) = doorAhead(m) else { Issue.record("no door"); return }
        let r = m.board.route
        m.tokens[0].pos = r[at - 1]; m.tokens[0].from = r[at - 2]
        let other = ["S", "H", "D", "C"].first { $0 != d.suit }!
        m.tokens[0].plays = [play(1, 30, other)]
        let ev = try m.apply(.mazeWalk(play: 1, ways: nil), by: 0)
        guard case .walk(_, _, _, let path, _, let doors, let stopped, _, let end, _, _) = ev.first else { Issue.record("walk"); return }
        #expect(stopped && path.isEmpty && doors.isEmpty && end == r[at - 1])
        #expect(m.tokens[0].atDoor && m.tokens[0].from == nil)
    }

    @Test func aDoorOfYourSuitBreaksMidWalk() throws {
        var m = testMaze(config, plays: [[play(1, 40, nil)]])
        guard let (at, d) = doorAhead(m) else { Issue.record("no door"); return }
        let r = m.board.route
        m.tokens[0].pos = r[at - 1]; m.tokens[0].from = r[at - 2]
        m.tokens[0].plays = [play(1, d.strength + 5, d.suit)]
        let before = m.preview(seat: 0, play: 1)!
        let ev = try m.apply(.mazeWalk(play: 1, ways: nil), by: 0)
        guard case .walk(_, _, _, let path, _, let doors, let stopped, _, let end, _, _) = ev.first else { Issue.record("walk"); return }
        #expect(!stopped && doors.count == 1 && doors[0].broke && doors[0].hit == d.strength && doors[0].at == 0)
        #expect(path.count == 5 && path[0] == r[at] && end == path.last)
        #expect(before.walk.path == path)   // the preview showed exactly this
        let k = m.board.key(r[at - 1], r[at])!
        #expect(m.board.passages[k]!.kind == .open && m.board.passages[k]!.broken)
    }

    @Test func aPreviewChangesNothing() throws {
        let m = testMaze(config, plays: [[play(1, 60, "H")]])
        let p = m.preview(seat: 0, play: 1)!
        #expect(m.tokens[0].pos == m.board.start)
        #expect(p.cost == m.costField()[p.walk.end])
    }

    @Test func closingAndFlipping() throws {
        var m = testMaze(config, seats: 2, plays: [[play(1, 9, "H"), play(2, 5, nil)], [play(3, 4, nil), play(4, 5, nil)]])
        #expect(m.turn == 0)
        let r = m.board.route
        // The passage beside the start holds a token: it can't be closed.
        #expect(!m.canClose(0, key: m.board.key(r[0], r[1])!))
        let ev = try m.apply(.mazeClose(play: 1, passage: [r[5], r[6]]), by: 0)
        #expect(ev.first == .doorClosed(seat: 0, play: 1, passage: [min(r[5], r[6]), max(r[5], r[6])], suit: "H", strength: 9))
        #expect(m.turn == 1)
        #expect(throws: IllegalAction.self) { try m.apply(.mazeWalk(play: 2, ways: nil), by: 0) }   // not seat 0's turn
        _ = try m.apply(.mazeFlip(play: 3, letter: "A"), by: 1)
        #expect(m.turn == 0)
        #expect(throws: IllegalAction.self) { try m.apply(.mazeFlip(play: 2, letter: "A"), by: 0) }   // once a hand
        #expect(throws: IllegalAction.self) { try m.apply(.mazeClose(play: 2, passage: [r[7], r[8]]), by: 0) }   // no suit
    }

    @Test func theCostFieldCountsDoors() {
        let m = testMaze(config, plays: [[]])
        let f = m.costField()
        #expect(f[m.board.goal] == 0)
        let doors = m.board.route.indices.dropFirst().compactMap { i -> Passage? in let p = m.board.passages[m.board.key(m.board.route[i - 1], m.board.route[i])!]!; return p.kind == .door ? p : nil }
        // Along the golden path alone: a step a cell, plus each door's strength and its suit's extra.
        #expect(f[m.board.start] <= m.board.route.count - 1 + doors.reduce(0) { $0 + $1.strength + 8 })
    }
}

@Suite struct MazeGameTests {
    @Test func aGameAroundTheMazeEnds() throws {
        let c = shortConfig(hands: 3)
        let (run, steps) = try mazeGame(c, seed: 4)
        let ends = steps.flatMap(\.events).compactMap(\.mazeEvent).filter { if case .mazeEnd = $0 { true } else { false } }
        #expect(run.result != nil && ends.count == 1)
        #expect(steps.flatMap(\.events).contains { if case .maze(.mazeBuilt) = $0 { true } else { false } })
    }

    @Test func aMazeGameRecordReplays() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cribmaze-maze-\(ProcessInfo.processInfo.processIdentifier).jsonl")
        let w = try RecordWriter<CribMazeGame>(url: url, clock: { Date(timeIntervalSince1970: 0) })
        _ = try mazeGame(shortConfig(hands: 2), seed: 6, writer: w)
        let r = try RecordReader<CribMazeGame>.read(url)
        #expect(r.finished)
        let v = Replayer.check(r, mode: .verify), s = Replayer.check(r, mode: .scripted)
        #expect(v.ok, "\(v)")
        #expect(s.ok, "\(s)")
    }
}

@Suite struct MazeJokerTests {
    let config = try! loadConfig()

    func twoSeats(_ plays: [[MazePlay]], human: Bool = false, jokers: [[String: Int]] = []) -> Maze {
        let mc = config.maze!
        let seats = [human ? PlayerSeat.human(0) : PlayerSeat.bot(0, level: "medium"), PlayerSeat.bot(1, level: "medium")]
        var m = Maze(config: mc, board: Maze.build(mc, seed: 1), seats: seats, dice: Dice(seed: 1))
        _ = m.startHand(1, dealer: 1, plays: plays, kept: [], jokers: jokers, gridSteps: [])
        return m
    }

    @Test func aFirePassedAndAMineLandedOn() throws {
        var m = twoSeats([[play(1, 12, nil), play(2, 3, nil)], [play(3, 5, nil)]])
        let pv = m.preview(seat: 0, play: 1)!.walk
        m.hazards = [.init(cell: pv.path[3], kind: "fire", seat: 1), .init(cell: pv.end, kind: "mine", seat: 1)]
        let ev = try m.apply(.mazeWalk(play: 1, ways: nil), by: 0)
        let hits = ev.compactMap { e -> (String, Bool, Int, [Int], Int)? in if case .hazardHit(_, let k, _, let l, let n, let lost, let owed) = e { (k, l, n, lost, owed) } else { nil } }
        #expect(hits.count == 2)
        #expect(hits[0].0 == "fire" && !hits[0].1 && (1...2).contains(hits[0].2))
        #expect(hits[0].3 == [2])   // the one play left burns
        #expect(hits[1].0 == "mine" && hits[1].1 && (6...7).contains(hits[1].2) && hits[1].3.isEmpty && hits[1].4 == hits[1].2)
        #expect(hits[0].4 == hits[0].2 - 1)
        #expect(m.hazards.isEmpty && m.tokens[0].plays.isEmpty)
        // What's owed comes off the next hand's plays as soon as they're dealt.
        let owed = m.tokens[0].owed
        let ev2 = m.startHand(2, dealer: 0, plays: [(10..<20).map { play($0, 5, nil) }, [play(30, 5, nil)]], kept: [], jokers: [], gridSteps: [])
        guard case .playsOwed(0, let lost, 0) = ev2.first else { Issue.record("owed"); return }
        #expect(lost.count == owed && m.tokens[0].plays.count == 10 - owed)
    }

    @Test func aStarGivesAJoker() throws {
        var m = twoSeats([[play(1, 7, nil)], [play(2, 5, nil)]])
        let end = m.preview(seat: 0, play: 1)!.walk.end
        m.board.stars = [end]
        let ev = try m.apply(.mazeWalk(play: 1, ways: nil), by: 0)
        guard case .star(0, end, let j) = ev.last(where: { if case .star = $0 { true } else { false } }) else { Issue.record("star"); return }
        #expect(m.tokens[0].jokers[j] == 1 && m.board.stars.isEmpty)
    }

    @Test func swapsBombsBurnsAndReach() throws {
        var m = twoSeats([[play(1, 30, nil), play(2, 4, nil)], [play(3, 20, nil), play(4, 6, nil)]], human: true,
                         jokers: [["swapper": 2, "bomb": 1, "burn": 1, "reach": 1], ["swapper": 1]])
        _ = try m.apply(.mazeWalk(play: 1, ways: nil), by: 0)
        // A person with a joker left: the turn waits for one, or End turn.
        #expect(m.turn == 0)
        let ev = try m.apply(.mazeJoker(kind: "swapper", target: 1, cell: nil, passage: nil), by: 0)
        guard case .swapped(0, 1, _) = ev.first else { Issue.record("swap"); return }
        #expect(m.turn == 1 && m.tokens[1].pos != m.board.start)   // a joker after the play ends the turn
        #expect(!m.canSwap(1, 0))   // not the same pair back this hand
        _ = try m.apply(.mazeWalk(play: 3, ways: nil), by: 1)
        #expect(m.turn == 0)
        let cells = m.hazardCells(0)
        #expect(!cells.isEmpty)
        _ = try m.apply(.mazeJoker(kind: "burn", target: nil, cell: cells[0], passage: nil), by: 0)
        #expect(m.hazards == [.init(cell: cells[0], kind: "fire", seat: 0)])
        #expect(throws: IllegalAction.self) { try m.apply(.mazeJoker(kind: "reach", target: nil, cell: nil, passage: nil), by: 0) }   // one a turn
        _ = try m.apply(.mazeWalk(play: 2, ways: nil), by: 0)
        #expect(m.turn == 1)
    }
}

@Suite struct MazeDuelTests {
    let config = try! loadConfig()

    func seats(_ human: Bool) -> [PlayerSeat] { [human ? .human(0) : .bot(0, level: "medium"), .bot(1, level: "medium")] }
    func maze(human: Bool = false) -> Maze {
        let mc = config.maze!
        return Maze(config: mc, board: Maze.build(mc, seed: 1), seats: seats(human), dice: Dice(seed: 1))
    }
    let kept = [["5S", "5H", "JD", "QC"], ["4S", "6H", "7D", "8C"]].map { $0.map { Card.parse($0)! } }

    @Test func twoStuckPlayersDuel() throws {
        var m = maze()
        _ = m.startHand(1, dealer: 1, plays: [[play(1, 5, nil)], [play(2, 5, nil)]], kept: kept, jokers: [], gridSteps: [])
        // Nobody moved: at hand 2 both are stuck, and the two furthest from the goal duel.
        let ev = m.startHand(2, dealer: 0, plays: [[play(3, 9, nil), play(4, 3, nil)], [play(5, 7, nil)]], kept: kept, jokers: [], gridSteps: [])
        guard case .duelStart("stuck", let s, let lead, 1, _) = ev.first else { Issue.record("duel: \(ev)"); return }
        #expect(Set(s) == [0, 1] && lead == 1)   // seat 1 is first after the dealer
        guard case .duelEnd("stuck", _, let scores, let w, _, let took, let opened) = ev.first(where: { if case .duelEnd = $0 { true } else { false } }) else { Issue.record("end"); return }
        #expect(scores.count >= 1 && opened != nil && took != nil)
        #expect(m.tokens[w].plays.contains { $0.id == took })
        // Seat 1 moves first, unless it lost its only play.
        let first = m.tokens[1].plays.isEmpty ? 0 : 1
        #expect(m.duel == nil && m.turn == first)
        #expect(ev.filter { if case .mazeTurn = $0 { true } else { false } } == [.mazeTurn(seat: first, hand: 2)])
    }

    @Test func oneStuckPlayerStirsTheMaze() throws {
        var m = maze()
        _ = m.startHand(1, dealer: 1, plays: [[play(1, 5, nil)], [play(2, 5, nil)]], kept: kept, jokers: [], gridSteps: [])
        m.tokens[1].handStartCost = Int.max   // seat 1 got closer
        m.tokens[1].handStartCost = m.costField()[m.tokens[1].pos] + 1
        let ev = m.startHand(2, dealer: 0, plays: [[play(3, 9, nil)], [play(5, 7, nil)]], kept: kept, jokers: [], gridSteps: [])
        guard case .stir(0, let o, _, _) = ev.first else { Issue.record("stir: \(ev)"); return }
        #expect(["fade", "star", "shift"].contains(o))
    }

    @Test func landingDuelsAndAPersonsCards() throws {
        var m = maze(human: true)
        _ = m.startHand(1, dealer: 1, plays: [[play(1, 9, nil), play(2, 3, nil)], [play(3, 5, nil)]], kept: kept, jokers: [], gridSteps: [])
        let end = m.preview(seat: 0, play: 1)!.walk.end
        m.tokens[1].pos = end
        let ev = try m.apply(.mazeWalk(play: 1, ways: nil), by: 0)
        guard case .duelStart("landing", [0, 1], let lead, 1, _) = ev.first(where: { if case .duelStart = $0 { true } else { false } }) else { Issue.record("duel: \(ev)"); return }
        #expect(lead == 0)   // seat 0 is first after dealer 1
        // The duel waits for the person's card; nothing else is allowed meanwhile.
        #expect(m.duel != nil)
        #expect(throws: IllegalAction.self) { try m.apply(.mazeEndTurn, by: 0) }
        var guardN = 0
        while let d = m.duel, guardN < 20 {
            guardN += 1
            let c = d.peg.legal(d.peg.turn).first!
            #expect(d.seats[d.peg.turn] == 0)
            _ = try m.apply(.duelCard(card: CardRef(c)), by: 0)
        }
        #expect(m.duel == nil)
        // The walker's turn goes on: once a pair a hand, and its turn ends (it holds no joker).
        #expect(m.met == [[0, 1]] && m.turn == 1)
    }

    @Test func endTurnPassesAPersonsTurnWithAJokerLeft() throws {
        var m = maze(human: true)
        _ = m.startHand(1, dealer: 1, plays: [[play(1, 3, nil), play(2, 3, nil)], [play(3, 5, nil)]], kept: kept, jokers: [["reach": 1], [:]], gridSteps: [])
        #expect(m.turn == 0)
        #expect(throws: IllegalAction.self) { try m.apply(.mazeEndTurn, by: 0) }
        _ = try m.apply(.mazeWalk(play: 1, ways: nil), by: 0)
        #expect(m.turn == 0 && m.played)   // a reach could still be played: the turn waits
        let ev = try m.apply(.mazeEndTurn, by: 0)
        #expect(ev == [.mazeTurn(seat: 1, hand: 1)])
        #expect(m.turn == 1 && !m.played)
    }

    @Test func aTieReplaysWithTheOtherLead() throws {
        // Equal hands score alike only sometimes; search kept hands for a first game that ties.
        var found = false
        var d = Dice(seed: 3)
        for _ in 0..<400 where !found {
            var deck = (0..<52).map { Card(standard: $0) }
            d.shuffle(&deck, stream: "t", purpose: "t")
            let hands = [Array(deck[0..<4]), Array(deck[4..<8])]
            var p = PegPlay(hands: hands, lead: 0, scoring: config.maze!.duel.peg)
            while !p.over { _ = p.play(p.botCard()!) }
            guard p.scores[0] == p.scores[1] else { continue }
            found = true
            var m = maze()
            _ = m.startHand(1, dealer: 1, plays: [[play(1, 5, nil)], [play(2, 5, nil)]], kept: hands, jokers: [], gridSteps: [])
            let ev = m.startDuel(0, 1, why: "landing", walker: nil)
            let starts = ev.compactMap { e -> (Int, Int)? in if case .duelStart(_, _, let lead, let g, _) = e { (lead, g) } else { nil } }
            #expect(starts.count == 2 && starts[0] != starts[1] && starts[1].1 == 2 && starts[0].0 != starts[1].0)
            guard case .duelEnd(_, _, let scores, _, _, _, nil) = ev.first(where: { if case .duelEnd = $0 { true } else { false } }) else { Issue.record("end"); return }
            #expect(scores.count == 2 && scores[0][0] == scores[0][1])
        }
        #expect(found)
    }
}

@Suite struct MazeBotTests {
    let config = try! loadConfig()

    func twoSeats(_ plays: [[MazePlay]], jokers: [[String: Int]] = []) -> Maze {
        let mc = config.maze!
        var m = Maze(config: mc, board: Maze.build(mc, seed: 1), seats: [.bot(0, level: "medium"), .bot(1, level: "medium")], dice: Dice(seed: 1))
        _ = m.startHand(1, dealer: 1, plays: plays, kept: [], jokers: jokers, gridSteps: [])
        return m
    }

    @Test func everyStyleLoads() {
        for id in ["balanced", "racer", "timer", "closer", "jokers"] { #expect(MazeBot(config: config, style: id) != nil) }
        #expect(MazeBot(config: config, style: "nobody") == nil)
    }

    @Test func aRacerWalksItsBiggestAndATimerItsBest() {
        let m = twoSeats([[play(1, 30, nil), play(2, 9, nil), play(3, 4, nil)], [play(4, 5, nil)]])
        #expect(MazeBot(config: config, style: "racer")!.choose(m) == .mazeWalk(play: 1, ways: nil))
        let b = MazeBot(config: config, style: "timer")!   // balanced may flip a switch first
        guard case .mazeWalk(let id, nil) = b.choose(m) else { Issue.record("walk"); return }
        let f = m.costField()
        let ends = [1, 2, 3].map { f[m.preview(seat: 0, play: $0)!.walk.end] }
        #expect(f[m.preview(seat: 0, play: id)!.walk.end] == ends.min())
    }

    @Test func aBotUsesAJokerFirstThenPlays() throws {
        // Seat 1 far ahead: a balanced seat 0 swaps with it before walking.
        var m = twoSeats([[play(1, 6, nil), play(2, 5, nil)], [play(3, 5, nil)]], jokers: [["swapper": 1], [:]])
        let f = m.costField()
        m.tokens[1].pos = (0..<f.count).filter { f[$0] > 0 && f[$0] < f[m.tokens[0].pos] - 100 }.min { f[$0] < f[$1] }!
        let b = MazeBot(config: config, style: "balanced")!
        #expect(b.choose(m) == .mazeJoker(kind: "swapper", target: 1, cell: nil, passage: nil))
        _ = try m.apply(b.choose(m), by: 0)
        guard case .mazeWalk = b.choose(m) else { Issue.record("then its play"); return }
    }
}
