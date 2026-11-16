// `cribmaze-sim discard --hand 5H,5C,JD,QS,3C,9H [--level medium] [--samples 40] [--seed 1] [--config <folder>]`
//
// For a 6-card deal (non-dealer, 2 players), rates all 15 ways to keep 4:
// - classic: the mean hand count over all 46 possible starters, as classic discard advice does
//   (hand flushes count, his nobs counts; the crib, which isn't yours, is left out);
// - grid: the mean steps a bot scores in a match turn with that hand, over the same sample of
//   starters and seeds for every keep. (The 2 thrown cards stay in the stock; in a game they.d be in the crib.)
// The two rankings show where classic advice and grid play disagree (concept.md › Hints).
import CardKit
import CribbageKit
import CribMaze
import CribMazeBots
import Foundation
import GameKit

func runDiscard(_ args: [String]) {
    var hand: [Card] = [], level = "medium", samples = 40, seed: UInt64 = 1, folder = "../cribbage/minigames/config"
    var i = 0
    func value() -> String { i += 1; guard i < args.count else { usage("\(args[i - 1]) needs a value") }; return args[i] }
    while i < args.count {
        switch args[i] {
        case "--hand": hand = value().split(separator: ",").compactMap { Card.parse(String($0)) }
        case "--level": level = value()
        case "--samples": samples = Int(value()) ?? 40
        case "--seed": seed = UInt64(value()) ?? 1
        case "--config": folder = value()
        default: usage("unknown option \(args[i])")
        }
        i += 1
    }
    guard hand.count == 6, Set(hand.map(\.id)).count == 6 else { usage("--hand needs 6 different cards, like 5H,5C,JD,QS,3C,9H") }
    let config: Config
    do { config = try Config.load(from: URL(fileURLWithPath: folder)) } catch { usage("config: \(error)") }
    guard let bot = MatchBot(config: config, id: level) else { usage("no bot level \(level)") }

    let ids = Set(hand.map(\.id))
    var starters = (0..<52).filter { !ids.contains($0) }.map { Card(standard: $0) }
    var dice = Dice(seed: seed)
    dice.shuffle(&starters, stream: "sample", purpose: "starters")

    func classic(_ keep: [Card]) -> Double {
        var total = 0
        for st in starters {
            let cards = (keep + [st]).map { (rank: $0.rank, suit: $0.suit!) }
            var o = CountOptions(flushMin: 4, handFlush4: true)
            if let j = keep.firstIndex(where: { $0.rank == 11 && $0.suit == st.suit }) { o.nobs = [4, j] }
            total += count(cards, o, scoring: config.rules.scoring).total
        }
        return Double(total) / Double(starters.count)
    }

    func grid(_ keep: [Card]) -> Double { gridValue(keep, starters: starters, samples: samples, seed: seed, config: config, bot: bot) }

    var rows: [(keep: [Card], thrown: [Card], classic: Double, grid: Double)] = []
    for a in 0..<6 { for b in (a + 1)..<6 {
        let keep = hand.enumerated().filter { $0.offset != a && $0.offset != b }.map(\.element)
        rows.append((keep, [hand[a], hand[b]], classic(keep), grid(keep)))
    } }
    let byClassic = rows.sorted { $0.classic > $1.classic }.map { $0.thrown.map(\.face).joined(separator: " ") }
    let byGrid = rows.sorted { $0.grid > $1.grid }.map { $0.thrown.map(\.face).joined(separator: " ") }
    print("deal \(hand.map(\.face).joined(separator: " ")) · non-dealer · bot \(level) · \(samples) grid samples a keep")
    print("keep            throw      classic  rank   grid  rank")
    for r in rows.sorted(by: { $0.classic > $1.classic }) {
        let t = r.thrown.map(\.face).joined(separator: " ")
        print("\(r.keep.map(\.face).joined(separator: " ").padding(toLength: 16, withPad: " ", startingAt: 0))\(t.padding(toLength: 10, withPad: " ", startingAt: 0))\(String(format: "%7.2f", r.classic))  \(String(format: "%4d", byClassic.firstIndex(of: t)! + 1))  \(String(format: "%5.1f", r.grid))  \(String(format: "%4d", byGrid.firstIndex(of: t)! + 1))")
    }
}

/// Mean steps a bot scores in a non-dealer match turn with this hand, over `samples` turns. Every
/// keep of a deal uses the same starters and seeds, so keeps compare fairly.
func gridValue(_ keep: [Card], starters: [Card], samples: Int, seed: UInt64, config: Config, bot: MatchBot) -> Double {
    var total = 0
    for k in 0..<samples {
        let st = starters[k % starters.count]
        var (turn, _) = MatchTurn.start(config: config, setup: TurnSetup(seed: seed &+ UInt64(k), dealer: false, warned: true,
                                                                       fixedHand: keep.map(\.notation), fixedStarter: st.notation))
        var acted = 0, ends: [Int: Int] = [:]
        while !turn.state.over {
            var d = turn.dice
            let a = bot.choose(turn, dice: &d)
            turn.dice = d
            guard let ev = try? turn.apply(a) else { break }
            acted += 1
            for e in ev { if case .reach(let id, _, let s, _, _) = e { ends[id] = acted + max(1, s / 4) } }
            for (id, end) in ends where end <= acted && !turn.state.over { ends[id] = nil; _ = try? turn.apply(.reachOver(id: id)) }
        }
        total += turn.state.steps
    }
    return Double(total) / Double(samples)
}

// `cribmaze-sim principles --deals 200 [--samples 20] [--seed 1] [--level medium] [--config <folder>]`
//
// Deals random 6-card hands. For each, every keep's grid value is measured (as `discard` does), and
// for each principle that applies, the worth of following it: mean grid steps of the keeps that
// follow it minus those that don't. Prints, per principle, how often it applies, its mean worth, and
// how often the deal's best keep follows it (concept.md › Hints).
func runPrinciples(_ args: [String]) {
    var deals = 200, samples = 20, seed: UInt64 = 1, level = "medium", folder = "../cribbage/minigames/config"
    var i = 0
    func value() -> String { i += 1; guard i < args.count else { usage("\(args[i - 1]) needs a value") }; return args[i] }
    while i < args.count {
        switch args[i] {
        case "--deals": deals = Int(value()) ?? 200
        case "--samples": samples = Int(value()) ?? 20
        case "--seed": seed = UInt64(value()) ?? 1
        case "--level": level = value()
        case "--config": folder = value()
        default: usage("unknown option \(args[i])")
        }
        i += 1
    }
    let config: Config
    do { config = try Config.load(from: URL(fileURLWithPath: folder)) } catch { usage("config: \(error)") }
    guard let bot = MatchBot(config: config, id: level) else { usage("no bot level \(level)") }
    var applies: [DiscardPrinciple: Int] = [:], worth: [DiscardPrinciple: Double] = [:], bestFollows: [DiscardPrinciple: Int] = [:]
    var dice = Dice(seed: seed)
    for d in 0..<deals {
        var deck = (0..<52).map { Card(standard: $0) }
        dice.shuffle(&deck, stream: "sample", purpose: "deal")
        let deal = Array(deck.prefix(6))
        var starters = Array(deck.dropFirst(6))
        dice.shuffle(&starters, stream: "sample", purpose: "starters")
        var keeps: [([Card], Double)] = []
        for a in 0..<6 { for b in (a + 1)..<6 {
            let keep = deal.enumerated().filter { $0.offset != a && $0.offset != b }.map(\.element)
            keeps.append((keep, gridValue(keep, starters: starters, samples: samples, seed: seed &+ UInt64(d) &* 1000, config: config, bot: bot)))
        } }
        let best = keeps.max { $0.1 < $1.1 }!.0
        for hit in Principles.applying(to: deal) {
            let yes = keeps.filter { Principles.follows($0.0, hit) }.map(\.1), no = keeps.filter { !Principles.follows($0.0, hit) }.map(\.1)
            guard !yes.isEmpty, !no.isEmpty else { continue }
            applies[hit.principle, default: 0] += 1
            worth[hit.principle, default: 0] += yes.reduce(0, +) / Double(yes.count) - no.reduce(0, +) / Double(no.count)
            if Principles.follows(best, hit) { bestFollows[hit.principle, default: 0] += 1 }
        }
    }
    print("principles · \(deals) deals · \(samples) grid samples a keep · bot \(level) · seed \(seed)")
    print("principle       applies   worth (steps)   best keep follows")
    for p in DiscardPrinciple.allCases {
        let n = applies[p] ?? 0
        let w = n > 0 ? worth[p]! / Double(n) : 0, f = n > 0 ? 100 * Double(bestFollows[p] ?? 0) / Double(n) : 0
        print("\(p.rawValue.padding(toLength: 16, withPad: " ", startingAt: 0))\(String(format: "%7d", n))   \(String(format: "%+13.1f", w))   \(String(format: "%16.0f%%", f))   sums \(String(format: "%.1f", worth[p] ?? 0)) \(bestFollows[p] ?? 0)")
    }
}
