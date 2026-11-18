import CardKit
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
