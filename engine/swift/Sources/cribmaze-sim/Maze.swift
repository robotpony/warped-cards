// `cribmaze-sim maze [--seed 1] [--to 20] [--config <folder>]`
//
// Builds each seed's maze (maze.md › The board) and prints one JSON line a seed: size, start,
// goal, golden length, doors (key cells, strength, suit, variant, shortcut), variants, switches,
// stars and junction arrows, in the shape `fixtures/mazes.json` holds, for checking against the mock.
import CribMaze
import Foundation
import GameKit

func mazeSummary(_ m: MazeBoard, seed: UInt64) -> [String: Any] {
    let doors: [[Any]] = m.doors.map { k, d in let (a, b) = m.cells(ofKey: k); return ["\(a):\(b)", d.strength, d.suit as Any, d.variant, d.shortcut] }
    let switches = m.switches.map { s -> [String] in let (a, b) = m.cells(ofKey: s.a), (c, d) = m.cells(ofKey: s.b); return ["\(a):\(b)", "\(c):\(d)"] }
    let arrows = (0..<m.n).filter { m.liveExits($0).count >= 2 }
    return ["seed": Int(seed), "size": m.w, "start": m.start, "goal": m.goal, "route": m.route.count - 1, "routeHead": Array(m.route.prefix(8)),
            "doors": doors.count, "doorList": doors, "variants": m.variants.count, "golden": m.variants.filter { $0.door > 0 }.count,
            "shortcuts": m.variants.filter { $0.door == 0 }.count, "switches": switches, "stars": m.stars.sorted(), "arrows": arrows.count,
            "ptr": arrows.map { "\($0):\(m.arrow[$0].rawValue)" }]
}

func runMaze(_ args: [String]) {
    var seed: UInt64 = 1, to: UInt64?, folder = "../../cribbage/minigames/config"
    var i = 0
    func value() -> String { i += 1; guard i < args.count else { usage("\(args[i - 1]) needs a value") }; return args[i] }
    while i < args.count {
        switch args[i] {
        case "--seed": guard let n = UInt64(value()) else { usage("--seed needs a number") }; seed = n
        case "--to": guard let n = UInt64(value()) else { usage("--to needs a number") }; to = n
        case "--config": folder = value()
        default: usage("unknown option \(args[i])")
        }
        i += 1
    }
    let config: Config
    do { config = try Config.load(from: URL(fileURLWithPath: folder)) } catch { usage("config: \(error)") }
    guard let mc = config.maze else { usage("no maze.json in \(folder)") }
    var out: [[String: Any]] = []
    for s in seed...(to ?? seed) {
        var dice = Dice(seed: s)
        out.append(mazeSummary(MazeBoard.generate(mc.board, dice: &dice), seed: s))
    }
    let data = try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!)
}
