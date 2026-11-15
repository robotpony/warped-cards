// cribmaze-sim: plays match turns with bots and prints the numbers.
//
//   cribmaze-sim run --level medium --turns 1000 --seed 1 [--dealer] [--config <folder>]
//
// Turn i plays from seed + i, bot seat 0, starting tray from config, warned set
// (bots count as already warned). Config defaults to ../cribbage/minigames/config.
import CribMaze
import CribMazeBots
import Foundation
import GameKit

struct Options {
    var level = "medium"
    var turns = 1000
    var seed: UInt64 = 1
    var dealer = false
    var config = "../cribbage/minigames/config"
}

func usage(_ why: String? = nil) -> Never {
    if let why { FileHandle.standardError.write(Data("cribmaze-sim: \(why)\n".utf8)) }
    print("usage: cribmaze-sim run --level <perfect|strong|medium|weak> --turns <n> --seed <n> [--dealer] [--config <folder>]")
    exit(why == nil ? 0 : 2)
}

func parse(_ args: [String]) -> Options {
    guard args.first == "run" else { usage(args.isEmpty || args.first == "--help" ? nil : "unknown command \(args.first!)") }
    var o = Options()
    var i = 1
    func value() -> String {
        i += 1
        guard i < args.count else { usage("\(args[i - 1]) needs a value") }
        return args[i]
    }
    while i < args.count {
        switch args[i] {
        case "--level": o.level = value()
        case "--turns": guard let n = Int(value()), n > 0 else { usage("--turns needs a positive number") }; o.turns = n
        case "--seed": guard let n = UInt64(value()) else { usage("--seed needs a number") }; o.seed = n
        case "--dealer": o.dealer = true
        case "--config": o.config = value()
        case "--help", "-h": usage()
        default: usage("unknown option \(args[i])")
        }
        i += 1
    }
    return o
}

struct Tally {
    var steps: [Int] = []
    var cleared = 0
    var prizes: [String: Int] = [:]
    var noPrize = 0
    var actions = 0, swaps = 0, bombs = 0
    var best: [Int] = []
    var fromPower = 0, scores = 0, starterIn = 0, flush4 = 0, flush5 = 0
}

let o = parse(Array(CommandLine.arguments.dropFirst()))
let config: Config
do { config = try Config.load(from: URL(fileURLWithPath: o.config)) } catch { usage("config: \(error)") }
guard let bot = MatchBot(config: config, id: o.level) else { usage("no bot level \(o.level) in bots.json") }

var t = Tally()
let started = Date()
for i in 0..<o.turns {
    var (turn, events) = MatchTurn.start(config: config, setup: TurnSetup(seed: o.seed &+ UInt64(i), dealer: o.dealer, warned: true))
    while !turn.state.over {
        var dice = turn.dice
        let action = bot.choose(turn, dice: &dice)
        turn.dice = dice
        do { events += try turn.apply(action) } catch {
            FileHandle.standardError.write(Data("cribmaze-sim: seed \(o.seed &+ UInt64(i)): illegal action \(action): \(error)\n".utf8))
            exit(1)
        }
        t.actions += 1
    }
    for e in events {
        switch e {
        case .prizeWon(let tier, _, _, _): t.prizes[tier, default: 0] += 1
        case .turnEnd(let reason, let totals):
            t.steps.append(totals.steps)
            if reason == "board_cleared" { t.cleared += 1 }
            t.swaps += totals.swaps; t.bombs += totals.bombs
            t.best.append(totals.best ?? 0); t.fromPower += totals.stepsFromEdgePower
        case .score(let positions, _, let combos, _, _, _, _, _, _, _, _, _):
            t.scores += 1; if positions.contains("s") { t.starterIn += 1 }
            for c in combos where c.kind == .flush { if (c.size ?? 0) >= 5 { t.flush5 += 1 } else { t.flush4 += 1 } }
        default: break
        }
    }
}
let secs = Date().timeIntervalSince(started)

let n = Double(t.steps.count)
let mean = Double(t.steps.reduce(0, +)) / n
let sorted = t.steps.sorted()
let pct = { (q: Double) in sorted[min(sorted.count - 1, Int(q * Double(sorted.count)))] }
let r = config.rules.match
print("cribmaze-sim · \(config.rules.rulesVersion) · bot \(o.level) · \(o.dealer ? "dealer" : "non-dealer") · seeds \(o.seed) to \(o.seed &+ UInt64(o.turns - 1))")
print("cardBudget \(r.cardBudget == 0 ? "whole stock" : String(r.cardBudget)) · no timer (bots don't send time_up)")
print("turns            \(o.turns)")
print("steps per turn   mean \(String(format: "%.1f", mean)) · min \(sorted.first!) · max \(sorted.last!) · median \(pct(0.5)) · p10 \(pct(0.1)) · p90 \(pct(0.9))")
print("boards cleared   \(t.cleared) (\(String(format: "%.1f", 100 * Double(t.cleared) / n))%)")
let tiers = ["common", "rare", "epic"].map { "\($0) \(t.prizes[$0, default: 0])" }.joined(separator: " · ")
print("prizes           \(tiers) · none \(o.turns - t.prizes.values.reduce(0, +))")
print("per turn         actions \(String(format: "%.1f", Double(t.actions) / n)) · swaps \(String(format: "%.2f", Double(t.swaps) / n)) · bombs \(String(format: "%.2f", Double(t.bombs) / n))")
let bs = t.best.sorted()
let bp = { (q: Double) in bs[min(bs.count - 1, Int(q * Double(bs.count)))] }
print("best set         mean \(String(format: "%.1f", Double(bs.reduce(0, +)) / n)) · p10 \(bp(0.1)) · p25 \(bp(0.25)) · median \(bp(0.5)) · p75 \(bp(0.75)) · p90 \(bp(0.9))")
print("edge power       \(String(format: "%.0f", 100 * Double(t.fromPower) / Double(max(1, t.steps.reduce(0, +)))))% of steps · starter in \(t.starterIn) of \(t.scores) scores (\(String(format: "%.0f", 100 * Double(t.starterIn) / Double(max(1, t.scores))))%)")
print("flushes          4-card \(t.flush4) · 5-card \(t.flush5) · in \(String(format: "%.1f", 100 * Double(t.flush4 + t.flush5) / Double(max(1, t.scores))))% of scores")
print("time             \(String(format: "%.1f", secs)) s")
