// `cribmaze-sim maze-game --games 300 [--seed 1] [--styles balanced,balanced] [--hands 15] [--config <folder>]`
//
// Plays whole games around the maze (maze.md; engine.md › The game around the maze): every seat a
// bot, MatchBot medium on the grid, each seat's maze style from --styles (bots.json › maze). Prints
// hands a game (min, median, max, and how many land in 6 to 12), how each game ended (goal or cap),
// each seat's wins, and per-game counts of the maze's events, for maze.md › Stats.
import CribMaze
import CribMazeBots
import Foundation
import GameKit

func runMazeGame(_ args: [String]) {
    var games = 300, seed: UInt64 = 1, styles = ["balanced", "balanced"], hands: Int?, folder = "../../cribbage/minigames/config"
    var i = 0
    func value() -> String { i += 1; guard i < args.count else { usage("\(args[i - 1]) needs a value") }; return args[i] }
    while i < args.count {
        switch args[i] {
        case "--games": guard let n = Int(value()), n > 0 else { usage("--games needs a positive number") }; games = n
        case "--seed": guard let n = UInt64(value()) else { usage("--seed needs a number") }; seed = n
        case "--styles": styles = value().split(separator: ",").map(String.init)
        case "--hands": guard let n = Int(value()), n > 0 else { usage("--hands needs a positive number") }; hands = n
        case "--config": folder = value()
        default: usage("unknown option \(args[i])")
        }
        i += 1
    }
    var config: Config
    do { config = try Config.load(from: URL(fileURLWithPath: folder)) } catch { usage("config: \(error)") }
    guard config.maze != nil else { usage("no maze.json in \(folder)") }
    if let hands { config.rules.game?.maxHands = hands }
    for s in styles where MazeBot(config: config, style: s) == nil { usage("no maze style \(s)") }
    guard (2...3).contains(styles.count) else { usage("--styles names 2 or 3 seats") }

    var handsA: [Int] = [], wins = [Int](repeating: 0, count: styles.count), reasons: [String: Int] = [:], counts: [String: Int] = [:]
    let started = Date()
    for g in 0..<games {
        let s = seed &+ UInt64(g)
        let seats = styles.indices.map { PlayerSeat.bot($0, level: "medium") }
        var (run, _) = GameRun<CribMazeGame>.start(.init(config, mazeGame: true), seed: s, players: seats)
        var dice = Dice(seed: s)
        var hand = 0
        do {
            try MatchBot(config: config, id: "medium")!.play(&run, options: .init(deal: true, warned: true), dice: &dice, msPerAction: 4000, mazeStyles: styles) { step in
                for e in step.events {
                    if case .handPlays(_, let p, _) = e { counts["plays dealt", default: 0] += p.count; counts["steps dealt", default: 0] += p.map(\.steps).reduce(0, +); if hand < 6 { counts["steps dealt in hand \(hand + 1) (both seats)", default: 0] += p.map(\.steps).reduce(0, +) } }
                    if case .botTurn(_, _, _, _, let prize, _, _, _) = e, prize != nil { counts["grid prizes (bots)", default: 0] += 1 }
                    guard let me = e.mazeEvent else { continue }
                    switch me {
                    case .mazeTurn(_, let h): hand = max(hand, h)
                    case .mazeEnd(let w, let r, _): wins[w] += 1; reasons[r, default: 0] += 1
                    case .walk(_, _, _, _, _, _, let stopped, _, _, _, _): if stopped { counts["stops at a door", default: 0] += 1 }
                    case .duelStart(let why, _, _, 1, _): counts["duels (\(why))", default: 0] += 1
                    case .hazardHit(_, let k, _, _, _, _, _): counts["\(k)s going off", default: 0] += 1
                    case .doorBombed: counts["doors bombed", default: 0] += 1
                    case .reachOn: counts["reaches used", default: 0] += 1
                    case .swapped: counts["swaps", default: 0] += 1
                    case .doorClosed: counts["doors closed", default: 0] += 1
                    case .switchFlipped: counts["switches flipped", default: 0] += 1
                    case .star: counts["stars taken", default: 0] += 1
                    case .stir(_, let o, _, _): counts["stirs (\(o))", default: 0] += 1
                    case .hazardSet(_, let k, _): counts["\(k)s set", default: 0] += 1
                    default: break
                    }
                }
            }
        } catch { usage("seed \(s): \(error)") }
        handsA.append(hand)
    }
    let sorted = handsA.sorted()
    let inRange = handsA.filter { (6...12).contains($0) }.count
    print("cribmaze-sim maze-game · \(styles.joined(separator: " vs ")) · \(games) games · seeds \(seed) to \(seed &+ UInt64(games - 1)) · \(String(format: "%.1f", Date().timeIntervalSince(started))) s")
    print("hands a game: \(sorted.first!) to \(sorted.last!), median \(sorted[(sorted.count - 1) / 2]), in 6 to 12: \(inRange) of \(games)")
    print("ended: " + reasons.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
    print("wins by seat: " + wins.enumerated().map { "\($0.offset) \(styles[$0.offset]) \($0.element)" }.joined(separator: ", "))
    print("per game:")
    for (k, v) in counts.sorted(by: { $0.key < $1.key }) { print("  \(k): \(String(format: "%.2f", Double(v) / Double(games)))") }
}
