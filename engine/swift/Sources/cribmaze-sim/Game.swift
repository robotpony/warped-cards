// `cribmaze-sim game --games 500 [--level medium] [--seed 1] [--own] [--burn none|weak] [--fresh-tray] [--fresh-deck] [--no-key] [--config <folder>]`
//
// Plays whole games (match rules r23): game.turns match turns, the deal alternating, the deck lasting
// the game and power jokers carrying over with each turn's prize. Each turn deals from the game's
// deck; the player and the bot keep their best classic hands, and the bot plays the player's grid
// turn (bots count as warned). It prints each turn's mean steps and prizes, and how the deck grows.
//
// --burn weak: at a turn's start, while a burn joker is in the tray, burn the grid card in the
// fewest scoring sets. A rough stand-in for a player thinning the deck. Default none.
// --fresh-tray: every turn starts with the config's power jokers, to measure the deck alone.
// --fresh-deck: every turn deals from a standard deck, as a control for the deck lasting the game.
// --no-key: the key joker (r28) out of the game (known, prizes, start), as a control for measuring it.
import CardKit
import CribMaze
import CribMazeBots
import Foundation
import GameKit

func runGame(_ args: [String]) {
    var games = 500, level = "medium", seed: UInt64 = 1, own = false, burnDead = false, freshTray = false, freshDeck = false, noKey = false, folder = "../../cribbage/minigames/config"
    var i = 0
    func value() -> String { i += 1; guard i < args.count else { usage("\(args[i - 1]) needs a value") }; return args[i] }
    while i < args.count {
        switch args[i] {
        case "--games": guard let n = Int(value()), n > 0 else { usage("--games needs a positive number") }; games = n
        case "--level": level = value()
        case "--seed": guard let n = UInt64(value()) else { usage("--seed needs a number") }; seed = n
        case "--own": own = true
        case "--burn": switch value() { case "weak": burnDead = true; case "none": burnDead = false; default: usage("--burn is none or weak") }
        case "--fresh-tray": freshTray = true
        case "--fresh-deck": freshDeck = true
        case "--no-key": noKey = true
        case "--config": folder = value()
        default: usage("unknown option \(args[i])")
        }
        i += 1
    }
    var config: Config
    do { config = try Config.load(from: URL(fileURLWithPath: folder)) } catch { usage("config: \(error)") }
    if own { config.rules.deck = .init(shared: false, minSize: config.rules.deck?.minSize) }
    if noKey {
        config.rules.specials.known.removeAll { $0 == "key" }
        config.rules.specials.start["key"] = nil
        config.rules.match.prize.special.entries.removeAll { $0.0 == "key" }
    }
    guard let bot = MatchBot(config: config, id: level) else { usage("no bot level \(level)") }
    let turns = config.rules.game?.turns ?? 1

    struct PerTurn { var steps = 0, made = 0, madeScores = 0, stepsFromMade = 0, madeDealt = 0, burns = 0, keys = 0, keysForGame = 0, keyCards = 0; var prizes: [String: Int] = [:] }
    var per = [PerTurn](repeating: PerTurn(), count: turns)
    var gameKeys: [Int] = []
    var gameSteps: [Int] = [], deckEnd: [Int] = [], madeEnd: [Int] = []
    let started = Date()

    for gi in 0..<games {
        var g = MatchGame(config: config, seed: seed &+ UInt64(gi))
        var keys = 0
        while !g.over {
            let k = g.turn - 1
            let dealt = freshDeck ? Deal.deal(seed: g.turnSeed) : g.deal()
            let keep = Deal.classicKeep(dealt.player, scoring: config.rules.scoring), botKeep = Deal.classicKeep(dealt.bot, scoring: config.rules.scoring)
            per[k].madeDealt += (keep.keep + [dealt.starter]).filter { $0.kind == .made }.count
            var setup = g.setup(dealt: dealt, thrown: keep.thrown, botThrown: botKeep.thrown, kept: keep.keep.sorted { $0.id < $1.id }, warned: true)
            if freshTray { setup.tray = config.rules.specials.start }
            if freshDeck { setup.deck = nil; setup.dealt = nil }
            var (t, ev) = MatchTurn.start(config: config, setup: setup)
            per[k].keyCards += t.state.keyCards
            do {
                if burnDead, t.state.tray["burn", default: 0] > 0, t.canBurn, let p = deadCard(t) { ev += try t.apply(.burn(target: p, source: nil)) }
                ev += try playOut(&t, bot)
            } catch { usage("seed \(g.seed) turn \(g.turn): \(error)") }
            let tt = t.state.totals
            per[k].steps += tt.steps; per[k].made += tt.made; per[k].madeScores += tt.madeScores; per[k].stepsFromMade += tt.stepsFromMade; per[k].burns += tt.burns
            keys += tt.keys
            per[k].keys += tt.keys; per[k].keysForGame += tt.keysForGame
            let r = g.finish(t, events: ev)
            per[k].prizes[r.tier ?? "none", default: 0] += 1
        }
        gameKeys.append(keys)
        gameSteps.append(g.steps); deckEnd.append(g.deck.count); madeEnd.append(g.deck.made.count)
    }

    let n = Double(games), f1 = { (x: Double) in String(format: "%.1f", x) }, pc = { (x: Int) in String(format: "%.0f%%", 100 * Double(x) / n) }
    print("cribmaze-sim game · \(config.rules.rulesVersion) · bot \(level) · \(turns) turns · \(own ? "own decks" : "shared deck") · burn \(burnDead ? "weakest card" : "none")\(freshTray ? " · fresh tray" : "")\(freshDeck ? " · fresh deck" : "")\(noKey ? " · no key" : "") · seeds \(seed) to \(seed &+ UInt64(games - 1))")
    let head = ["turn", "dealer", "steps", "made", "made dealt", "scores w/ made", "steps from made", "burns", "keys", "for game", "key cards", "prizes c/r/e"]
    var rows = [head]
    for (k, p) in per.enumerated() {
        let prizes = ["common", "rare", "epic"].map { pc(p.prizes[$0, default: 0]) }.joined(separator: "/")
        rows.append(["\(k + 1)", k.isMultiple(of: 2) ? "you" : "bot", f1(Double(p.steps) / n), f1(Double(p.made) / n), f1(Double(p.madeDealt) / n),
                     f1(Double(p.madeScores) / n), f1(Double(p.stepsFromMade) / n), f1(Double(p.burns) / n),
                     f1(Double(p.keys) / n), f1(Double(p.keysForGame) / n), f1(Double(p.keyCards) / n), prizes])
    }
    let widths = head.indices.map { c in rows.map { $0[c].count }.max()! }
    for r in rows { print(r.indices.map { c in String(repeating: " ", count: widths[c] - r[c].count) + r[c] }.joined(separator: "  ")) }
    print("game steps       mean \(f1(Double(gameSteps.reduce(0, +)) / n))")
    let f2 = { (x: Double) in String(format: "%.2f", x) }
    print("keys used        mean \(f2(Double(gameKeys.reduce(0, +)) / n)) a game · in \(pc(gameKeys.filter { $0 > 0 }.count)) of games · \(f2(Double(per.map(\.keysForGame).reduce(0, +)) / n)) for the game")
    print("deck at the end  mean \(f1(Double(deckEnd.reduce(0, +)) / n)) cards · \(f1(Double(madeEnd.reduce(0, +)) / n)) made · min \(deckEnd.min()!) · max \(deckEnd.max()!)")
    print("time             \(f1(Date().timeIntervalSince(started))) s")
}

/// A bot plays a turn to its end. Reaches end after 5 actions (about 20 s at a person's pace).
func playOut(_ t: inout MatchTurn, _ bot: MatchBot) throws -> [MatchEvent] {
    var ev: [MatchEvent] = [], ends: [Int: Int] = [:], acted = 0
    while !t.state.over {
        var d = t.dice
        let a = bot.choose(t, dice: &d)
        t.dice = d
        let e = try t.apply(a)
        ev += e; acted += 1
        for x in e { if let (id, _) = x.startedReach { ends[id] = acted + 5 } }
        for (id, end) in ends where end <= acted && !t.state.over { ends[id] = nil; ev += try t.apply(.reachOver(id: id)) }
    }
    return ev
}

/// The grid card in the fewest sets that score now, first in position order on a tie.
func deadCard(_ t: MatchTurn) -> Pos? {
    var uses = [Int](repeating: 0, count: Board.count)
    for set in MatchTurn.sets(maxSize: t.pickLimit) where t.traceProblem(set) == nil {
        if let v = t.value(of: set), !v.count.combos.isEmpty, v.points > 0 { for p in set { uses[p] += 1 } }
    }
    return Board.grid.filter { t.state.cells[$0]?.isPlaying == true }.min { uses[$0] < uses[$1] }
}
