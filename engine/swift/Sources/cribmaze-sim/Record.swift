// `cribmaze-sim record --games 3 [--seed 1] [--level medium] [--out <folder or file.jsonl>] [--config <folder>]`
//
// Plays whole games with a bot in the player's seat (as `game` does: classic keep at each deal,
// warned, reaches end after 5 actions) and writes each as a GameRecord. The game clock moves on
// timing.json's human `trace` per action. Default out: ./records.
//
// `cribmaze-sim replay <file or folder>... [--scripted] [--counts]`
//
// Replays records (ARCHITECTURE.md › Replay). Verify, the default, plays each from its seed and
// checks every roll and event; --scripted feeds the recorded rolls back instead. --counts prints
// events by type and rolls by stream and purpose over every record read. Exits 1 if any differ.
import CribMaze
import CribMazeBots
import Foundation
import GameKit
import GameRecord

func runRecord(_ args: [String]) {
    var games = 1, level = "medium", seed: UInt64 = 1, out = "records", folder = "../../cribbage/minigames/config"
    var i = 0
    func value() -> String { i += 1; guard i < args.count else { usage("\(args[i - 1]) needs a value") }; return args[i] }
    while i < args.count {
        switch args[i] {
        case "--games": guard let n = Int(value()), n > 0 else { usage("--games needs a positive number") }; games = n
        case "--level": level = value()
        case "--seed": guard let n = UInt64(value()) else { usage("--seed needs a number") }; seed = n
        case "--out": out = value()
        case "--config": folder = value()
        default: usage("unknown option \(args[i])")
        }
        i += 1
    }
    let config: Config
    do { config = try Config.load(from: URL(fileURLWithPath: folder)) } catch { usage("config: \(error)") }
    guard let bot = MatchBot(config: config, id: level) else { usage("no bot level \(level) in bots.json") }
    let ms = Int(humanTraceMs(folder))
    let outURL = URL(fileURLWithPath: out)
    for gi in 0..<games {
        let s = seed &+ UInt64(gi)
        let url = outURL.pathExtension == "jsonl" && games == 1 ? outURL : RecordWriter<CribMazeGame>.path(in: outURL, started: Date())
        do {
            let w = try RecordWriter<CribMazeGame>(url: url, clock: { Date() })
            var (run, opening) = GameRun<CribMazeGame>.start(.init(config), seed: s, players: [.bot(0, level: level), .bot(1, level: "classic")])
            w.gameStarted(GameHeader(run, stamp: AppStamp(app: "cribmaze-sim", platform: platform()), started: w.stamp(Date())))
            w.record(opening)
            var botDice = Dice(seed: s)
            try bot.play(&run, options: .init(deal: true, warned: true), dice: &botDice, msPerAction: ms) { w.record($0) }
            if let r = run.result { w.gameEnded(r) }
            if let e = w.error { usage("writing \(url.path): \(e)") }
            print("seed \(s) · \(run.result?.hands.count ?? 0) hands · \(run.result?.steps ?? 0) steps scored · \(url.path)")
        } catch { usage("seed \(s): \(error)") }
    }
}

func runReplay(_ args: [String]) {
    var paths: [String] = [], mode = ReplayMode.verify, counts = false
    for a in args {
        switch a {
        case "--scripted": mode = .scripted
        case "--verify": mode = .verify
        case "--counts": counts = true
        default: if a.hasPrefix("--") { usage("unknown option \(a)") } else { paths.append(a) }
        }
    }
    if paths.isEmpty { usage("replay needs a record file or folder") }
    var ok = 0, bad = 0, c = Counts()
    for p in paths {
        let (records, skipped) = RecordReader<CribMazeGame>.readAll(URL(fileURLWithPath: p))
        for s in skipped { print("skipped  \(s.url.path): \(s.why)"); bad += 1 }
        for r in records {
            let rep = Replayer.check(r, mode: mode)
            if rep.ok { ok += 1 } else { bad += 1 }
            let h = r.header
            print("\(rep.ok ? "ok      " : "DIFFERS ") \(r.url?.path ?? "?") · seed \(h.seed) · \(h.rules) · \(h.stamp.app) · \(r.finished ? "finished" : "unfinished")\(r.truncated ? ", cut short" : "") · \(rep)")
            c.add(r)
        }
    }
    print("\(mode.rawValue): \(ok) ok, \(bad) not")
    if counts {
        print("games \(c.games) (\(c.finished) finished) · hands \(c.hands) · steps \(c.steps) · actions \(c.actions)")
        if let m = c.gapMeanMs { print("time between actions  mean \(Int(m)) ms · min \(c.gapMinMs!) · max \(c.gapMaxMs!)") }
        print("actions  " + c.actionTypes.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · "))
        print("events   " + c.events.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · "))
        print("rolls    " + c.rolls.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: " · "))
    }
    exit(bad == 0 ? 0 : 1)
}

/// A person's pace per action: timing.json › profiles.human.trace, in ms.
func humanTraceMs(_ folder: String) -> Double {
    let url = URL(fileURLWithPath: folder).appendingPathComponent("timing.json")
    guard let d = try? Data(contentsOf: url), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let p = j["profiles"] as? [String: Any], let h = p["human"] as? [String: Any], let ms = h["trace"] as? Double else { return 4000 }
    return ms
}

func platform() -> String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return "macOS \(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : "")
}
