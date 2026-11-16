// The app's game state: one match turn, the player's input mode and the timer.
// The engine decides everything; this only sends actions and keeps the events.
import CardKit
import CribMaze
import CribMazeBots
import CribbageKit
import Foundation
import GameKit
import Observation
import SwiftUI

enum InputMode: Equatable { case trace, swap, bomb }

struct FeedLine: Identifiable { let id: Int; let text: String; let points: Int?; var prize = false }

/// The last score, for the breakdown panel.
struct Breakdown {
    let cards: [String]
    let lines: [(String, Int)]
    let comboPoints: Int, percent: Int, leftOver: Int, cost: Int, points: Int
}

struct TurnSettings: Equatable {
    var dealer = true
    var timer = true
    var hand = "random"   // or "strong"
    var budget = 0        // 0 is the whole stock
    var breakdown = true  // play each score's breakdown; off is a quick flash
    var hints = true      // nudge the player when they seem stuck (Hints.swift)
}

@MainActor @Observable
final class GameSession {
    private(set) var config: Config?
    private(set) var loadError: String?
    private(set) var turn: MatchTurn?
    private(set) var events: [MatchEvent] = []
    private(set) var actions: [MatchAction] = []
    private(set) var feed: [FeedLine] = []
    private(set) var breakdown: Breakdown?
    private(set) var toast: String?
    /// The first-time left-over warning: the cards left over, until "Got it".
    private(set) var warning: [String]?
    /// An info card the player opened by tapping a word tag or the card counter.
    var info: InfoTopic?
    /// Input waits while a card covers the board.
    var blocked: Bool { over || busy || warning != nil || info != nil }
    func dismissWarning() { warning = nil }
    /// Cards popping before they clear: scored sets in gold, bomb blasts in red.
    private(set) var flash: Set<Pos> = []
    private(set) var flashIsBomb = false
    /// While a move plays out, input waits.
    private(set) var busy = false
    /// Cards drawn into each grid column by the last move, so new cards drop in from above as a block.
    private(set) var drawnPerColumn = [Int](repeating: 0, count: 4)
    /// Off for snapshots: moves apply at once.
    var animate = true
    /// The score breakdown as it plays, and its timing.
    let playback = Playback()
    let meter = FrameMeter()
    var slowMotion = false { didSet { Motion.scale = slowMotion ? 5 : 1 } }
    var timing = BreakdownTiming()
    private(set) var secondsLeft = 0
    private(set) var savedRecord: URL?
    var settings = TurnSettings()
    var mode: InputMode = .trace
    /// The cards traced or tapped so far, in order.
    var selection: [Pos] = []
    private(set) var armedSource: Pos?
    var seed: UInt64 = 1
    var seedText = ""
    private var timerTask: Task<Void, Never>?
    private var deadTask: Task<Void, Never>?
    /// Seconds before a board with no sets left ends the turn, while power jokers could still help.
    private(set) var graceLeft: Int?
    /// How long a stuck board waits for a power joker (there's no End turn button).
    static let graceSeconds = 25
    private var toastTask: Task<Void, Never>?

    init() {
        defer { meter.moving = { [weak self] in self?.busy ?? false } }
        do {
            guard let folder = Bundle.main.url(forResource: "config", withExtension: nil) else { throw ConfigError(description: "config folder missing from the app") }
            config = try Config.load(from: folder)
        } catch { loadError = "\(error)" }
        newTurn()
    }

    var state: MatchState? { turn?.state }
    var over: Bool { turn?.state.over ?? true }

    func newTurn(seed fixed: UInt64? = nil) {
        guard var c = config else { return }
        c.rules.match.cardBudget = settings.budget
        c.rules.match.timerSeconds = settings.timer ? c.rules.match.timerSeconds : 0
        seed = fixed ?? UInt64(seedText) ?? UInt64.random(in: 1...999_999)   // app only: the engine never draws its own randomness
        seedText = ""
        playback.reset(); info = nil; deadTask?.cancel(); graceLeft = nil; reachTask?.cancel(); reachTask = nil; reachLeft = [:]
        let strong = settings.hand == "strong"
        let setup = TurnSetup(seed: seed, dealer: settings.dealer,
                              fixedHand: strong ? ["4H", "5C", "6D", "JS"] : nil, fixedStarter: strong ? "5S" : nil)
        let (t, ev) = MatchTurn.start(config: c, setup: setup)
        turn = t; events = ev; actions = []; feed = []; breakdown = nil; mode = .trace; savedRecord = nil; selection = []; armedSource = nil; warning = nil; toast = nil
        for e in ev { describe(e) }
        secondsLeft = c.rules.match.timerSeconds
        startTimer()
    }

    // MARK: Input

    /// One move by a bot, through the same path as the player's (used by the demo).
    func botMove(_ id: String = "medium") {
        guard !busy, warning == nil, info == nil, var t = turn, !t.state.over, let c = config, let bot = MatchBot(config: c, id: id) else { return }
        var d = t.dice
        let a = bot.choose(t, dice: &d)
        t.dice = d
        turn = t
        send(a)
    }

    func send(_ action: MatchAction) {
        guard !busy, let old = turn, !old.state.over else { return }
        var t = old
        do {
            let ev = try t.apply(action)
            actions.append(action); events += ev
            // What pops first: the scored set, or the cards a bomb hits.
            var hit: Set<Pos> = [], bomb = false
            for e in ev {
                if case .score(let ps, _, _, _, _, _, _, _, _, _, _, _) = e { hit = Set(ps.compactMap(Board.parse)) }
                if case .bomb(_, _, let cleared, _) = e {
                    let ids = Set(cleared.map(\.id)); bomb = true
                    hit = Set((0..<Board.count).filter { old.state.cells[$0].map { ids.contains($0.id) } ?? false })
                }
            }
            guard animate, !hit.isEmpty else { commit(t, ev); return }
            if !bomb, settings.breakdown, let score = ev.first(where: { if case .score = $0 { return true }; return false }) {
                busy = true; selection = []
                Task { [weak self] in
                    guard let self else { return }
                    await self.playBreakdown(score, before: old.state)
                    withAnimation(.easeOut(duration: Motion.t(0.2))) { self.playback.reset() }
                    self.commit(t, ev)
                    withAnimation(.spring(duration: Motion.t(0.26))) { self.playback.bump = true }
                    try? await Task.sleep(for: .milliseconds(Motion.ms(320)))
                    withAnimation(.easeOut(duration: Motion.t(0.2))) { self.playback.bump = false }
                    self.busy = false
                }
                return
            }
            busy = true; flash = hit; flashIsBomb = bomb
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(Motion.ms(bomb ? 380 : 340)))
                guard let self else { return }
                self.flash = []
                self.commit(t, ev)
                try? await Task.sleep(for: .milliseconds(Motion.ms(320)))
                self.busy = false
            }
        } catch {
            show("\(error)")
        }
    }

    /// Shows the move's result: cards clear, fall and drop in, animated.
    private func commit(_ t: MatchTurn, _ ev: [MatchEvent]) {
        var drawn = [Int](repeating: 0, count: 4)
        for e in ev { if case .boardChanged(_, _, let d) = e { for x in d { if let p = Board.parse(x.cell), Board.isGrid(p) { drawn[p % 4] += 1 } } } }
        drawnPerColumn = drawn
        if animate { withAnimation(.easeOut(duration: Motion.t(0.3))) { turn = t } } else { turn = t }
        for e in ev { describe(e) }
        watchReaches()
        if t.state.over { finish() } else { watchDeadBoard() }
    }

    /// No End turn button: a board with no sets left ends the turn by itself. With no power
    /// jokers it ends at once (after a beat); with some, the player gets a few seconds to use one.
    func watchDeadBoard() {
        deadTask?.cancel(); graceLeft = nil
        guard let t = turn, t.state.dead, !t.state.over else { return }
        let hasJokers = t.state.tray.values.contains { $0 > 0 }
        deadTask = Task { [weak self] in
            guard let self else { return }
            if !hasJokers {
                try? await Task.sleep(for: .milliseconds(Motion.ms(1500)))
                while self.busy { try? await Task.sleep(for: .milliseconds(100)) }
                if !Task.isCancelled, self.turn?.state.dead == true, !self.over { self.send(.endTurn) }
                return
            }
            self.graceLeft = Self.graceSeconds
            while !Task.isCancelled, let left = self.graceLeft {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, !self.over, self.turn?.state.dead == true else { self.graceLeft = nil; return }
                if self.busy || self.mode != .trace || self.warning != nil || self.info != nil { continue }   // waits while a joker is armed
                if left <= 1 { self.graceLeft = nil; self.send(.endTurn); return }
                self.graceLeft = left - 1
            }
        }
    }

    func submit(_ ps: [Pos]) {
        switch mode {
        case .trace: send(.trace(positions: ps))
        case .swap:
            if MatchTurn.isLine(ps) { mode = .trace; send(.swap(line: ps, source: pendingSource)) } else { show("Trace a straight line of 2 to 4 grid cards") }
        case .bomb:
            if let p = ps.first, Board.isGrid(p) { mode = .trace; send(.bomb(target: p, source: pendingSource)) }
        }
        pendingSource = nil; armedSource = nil
    }

    private var pendingSource: Pos? { get { armedSource } set { armedSource = newValue } }
    /// Tapping a special joker on the board arms it. A reach joker needs no target, so it's used at once.
    func arm(_ kind: String, from source: Pos? = nil) {
        if kind == "reach" { selection = []; send(.reach(source: source)); return }
        pendingSource = source
        mode = kind == "swapper" ? .swap : .bomb
        show(kind == "swapper" ? "Trace a straight line to reverse it" : "Tap a grid card to blast it")
    }
    func disarm() { mode = .trace; pendingSource = nil; selection = [] }

    /// Selected cards in a combo light up. With a swapper armed, the whole line does.
    var litPositions: Set<Pos> {
        let ps = selection
        if mode == .swap { return Set(ps) }
        guard mode == .trace, let t = turn, ps.count >= 2, ps.allSatisfy({ t.state.cells[$0]?.isPlaying == true }), let v = t.value(of: ps) else { return [] }
        var lit = Set<Int>()
        for c in v.count.combos { lit.formUnion(c.cards) }
        return Set(lit.map { v.counted[$0] })   // the starter lights too when it joins a combo
    }

    /// The edge power multiplier for a level, as the engine works it out: ×1.1, ×1.2, up to the cap.
    func multiplierText(_ level: Int) -> String {
        let ep = config?.rules.match.edgePower
        var pct = 100 + (ep?.percentPerLevel ?? 50) * level
        if let cap = ep?.capPercent, cap > 0 { pct = min(pct, cap) }
        return multiplierText(percent: pct)
    }

    var dead: Bool { turn?.state.dead ?? false }

    /// The card counter: cards picked so far, and how many a set may pick (the starter is free when it joins).
    var pickCount: Int { turn.map { $0.picked(selection).count } ?? 0 }
    var pickLimit: Int { turn?.pickLimit ?? (config?.rules.match.maxSet ?? 5) }

    /// The line under the board (the mock's pick message).
    var pickMessage: String {
        if mode == .bomb { return "Bomb armed: tap a grid card to blow it up. Tap the bomb again to cancel." }
        if mode == .swap && selection.isEmpty { return "Swapper armed: trace a straight line of 2 to 4 grid cards to reverse it. Tap the swapper again to cancel." }
        guard let t = turn else { return "" }
        if selection.isEmpty {
            if t.state.dead {
                if graceLeft != nil { return "No sets left. Use a power joker before the clock fills." }
                return "No sets left on the board. The turn is over."
            }
            return ""   // help moves to an intro or help page later
        }
        let cards = selection.compactMap { t.state.cells[$0] }
        var msg = cards.map(\.face).joined(separator: " ") + "  (sum \(cards.filter(\.isPlaying).reduce(0) { $0 + $1.value }))"
        if mode == .swap { return msg + (MatchTurn.isLine(selection) ? ": reverse this line" : ": not a straight line") }
        guard selection.count >= 2 else { return msg }
        if let why = t.traceProblem(selection) {
            let text = ["no_grid_card": "needs a grid card", "already_scored": "already scored", "not_touching": "cards must touch", "special": "a special joker can't score"][why]
            return text.map { msg + ": " + $0 } ?? msg
        }
        guard let v = t.value(of: selection) else { return msg }
        let names = v.count.combos.map { Self.comboName($0) }.joined(separator: " + ")
        let picked = t.picked(selection)
        let left = Set(picked.indices).subtracting(v.count.combos.flatMap(\.cards)).sorted().compactMap { t.state.cells[picked[$0]]?.face }.joined(separator: " ")
        let cost = (config?.rules.match.leftOverCost ?? 2) * v.leftOver
        if v.count.combos.isEmpty { msg += ": no combo" + (t.state.warned ? " (−\(cost))" : "") }
        else if v.leftOver == 0 { msg += ": \(names) (+\(v.points))" }
        else if t.state.warned { msg += ": \(names) (+\(v.multiplied)), \(left) left over (−\(cost)) = \(v.points >= 0 ? "+" : "")\(v.points)" }
        else { msg += ": \(left) left over" }
        return msg
    }

    static func comboName(_ c: CribbageKit.Combo) -> String { comboName(kind: c.kind, size: c.size, multiplier: c.multiplier) }
    static func comboName(kind: ComboKind, size: Int?, multiplier: Int?) -> String {
        switch kind {
        case .fifteen: return "fifteen"
        case .pair: return ["3": "pair royal", "4": "double pair royal"][String(size ?? 2)] ?? "pair"
        case .run: return "run of \(size ?? 3)" + ((multiplier ?? 1) > 1 ? " ×\(multiplier!)" : "")
        case .flush: return "flush of \(size ?? 4)"
        case .nobs: return "his nobs"
        }
    }

    private func faces(_ refs: [CardRef]) -> String { refs.map { Card.parse($0.card)?.face ?? $0.card.capitalized }.joined(separator: " ") }

    func multiplierText(percent pct: Int) -> String { "×" + (pct % 100 == 0 ? "\(pct / 100)" : String(format: "%g", Double(pct) / 100)) }

    // MARK: Timer

    /// Seconds left on each reach joker in effect, by its ID. They count down on their own clock,
    /// which waits while a move plays, like the turn's, and runs with the turn's timer off too.
    private(set) var reachLeft: [Int: (left: Int, total: Int)] = [:]
    /// The share of time left on the reach that ends first, for the card counter; nil with none in effect.
    var reachFraction: Double? {
        reachLeft.values.min { $0.left < $1.left }.map { Double(max(0, $0.left)) / Double(max(1, $0.total)) }
    }
    private var reachTask: Task<Void, Never>?

    private func watchReaches() {
        for r in turn?.state.reaches ?? [] where reachLeft[r.id] == nil { reachLeft[r.id] = (r.seconds, r.seconds) }
        for id in reachLeft.keys where !(turn?.state.reaches.contains { $0.id == id } ?? false) { reachLeft[id] = nil }
        guard !reachLeft.isEmpty, reachTask == nil else { return }
        reachTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, !self.over else { self?.reachTask = nil; return }
                if self.busy || self.warning != nil || self.info != nil { continue }
                for (id, r) in self.reachLeft { self.reachLeft[id] = (r.left - 1, r.total) }
                if let done = self.reachLeft.first(where: { $0.value.left <= 0 })?.key {
                    self.reachLeft[done] = nil
                    self.send(.reachOver(id: done))
                }
                if self.reachLeft.isEmpty { self.reachTask = nil; return }
            }
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        guard secondsLeft > 0 else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, !self.over else { return }
                if self.busy || self.warning != nil || self.info != nil { continue }   // the clock waits while a move plays or the warning shows
                self.secondsLeft -= 1
                if self.secondsLeft <= 0 { self.send(.timeUp); return }
            }
        }
    }

    // MARK: Feed

    private func line(_ text: String, _ points: Int? = nil, prize: Bool = false) { feed.insert(FeedLine(id: feed.count, text: text, points: points, prize: prize), at: 0) }

    func show(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    private func describe(_ e: MatchEvent) {
        switch e {
        case .traceRejected(_, let reason):
            let why = ["size": "Sets are 2 to \(pickLimit) cards", "special": "A special joker can't be in a set", "no_grid_card": "Every set needs a grid card",
                       "not_touching": "The cards must touch", "already_scored": "That set already scored"][reason] ?? reason
            show(why)
        case .leftoverWarning(let names, _):
            let ps = names.compactMap(Board.parse)
            if let t = turn, let v = t.value(of: ps) {
                let used = Set(v.count.combos.flatMap(\.cards)), picked = t.picked(ps)
                warning = picked.indices.filter { !used.contains($0) }.compactMap { t.state.cells[picked[$0]]?.face }
            } else { warning = [] }
        case .leftoverPenalty(let names, _, let cost):
            let faces = names.compactMap(Board.parse).compactMap { turn?.state.cells[$0]?.face }.joined(separator: " ")
            line("\(faces)  no combo: \(faces) left over  −\(cost)")
        case .score(_, let cards, let combos, let cp, let pct, let mult, let left, let cost, let pts, _, let suit, _):
            let names = cards.map { Card.parse($0.card)?.face ?? $0.card }
            let lines = combos.map { c -> (String, Int) in
                let label: String
                switch c.kind {
                case .fifteen: label = "Fifteen"
                case .pair: label = ["2": "Pair", "3": "Pair royal", "4": "Double pair royal"][String(c.size ?? 2)] ?? "Pair"
                case .run: label = "Run of \(c.size ?? 3)" + ((c.multiplier ?? 1) > 1 ? " ×\(c.multiplier!)" : "")
                case .flush: label = "Flush of \(c.size ?? 4)"
                case .nobs: label = "His nobs"
                }
                return (label, c.points)
            }
            breakdown = Breakdown(cards: names, lines: lines, comboPoints: cp, percent: pct, leftOver: left, cost: cost, points: pts)
            let what = (combos.count > 1 ? "multi ×\(combos.count): " : "single: ") + combos.map { Self.comboName(kind: $0.kind, size: $0.size, multiplier: $0.multiplier) }.joined(separator: " + ")
            let used = Set(combos.flatMap(\.cards))
            let leftNames = names.indices.filter { !used.contains($0) }.map { names[$0] }.joined(separator: " ")
            let amount = left > 0 ? "+\(mult) −\(cost) (\(leftNames) left over) = \(pts)" : "+\(pts)"
            let suitText = suit.flatMap { Suit(letter: $0)?.glyph } ?? "no suit"
            line("\(names.joined(separator: " "))  \(what)  \(amount) \(suitText)" + (pct > 100 ? " (\(cp) \(multiplierText(percent: pct)) edge power)" : ""))
        case .extraDrawn(let card, let outcome, let tier, let prize, let goes, _):
            let where_ = ["board": "on the board", "stock": "shuffled into the stock", "tray": "to your tray", "steps": ""][goes] ?? goes
            let kind = ["amber": "Amber joker", "teal": "Teal joker", "title": "Title card", "blank": "Blank card"][card.card] ?? card.card.capitalized
            let text = outcome == "steps" ? prize : "\(Card.parse(prize)?.face ?? prize) \(where_)"
            line("\(kind): \(text) (\(tier))", prize: true)
            show("\(kind): \(text)")
        case .swap(_, let before, let after, _):
            line("Swapped \(faces(before))  to  \(faces(after))")
        case .bomb(_, _, let cleared, _): line("Bomb: cleared \(faces(cleared))")
        case .stockOut(let reason, _): line((reason == "stock_empty" ? "Stock empty" : "Card budget used") + ": play out the board")
        case .reach(_, let cards, let seconds, let limit, _):
            line("Reach: hand size +\(cards) for \(seconds) s (now \(limit))")
            show("Reach: hand size +\(cards) for \(seconds) s")
        case .reachOver(_, let limit): line("Reach over: hand size back to \(limit)")
        case .noSetsLeft(_, let tray):
            show(tray.values.contains { $0 > 0 } ? "No sets score: use a power joker" : "No sets score")
        case .boardCleared(_, let amount): line("Board cleared! +\(amount) steps", prize: true)
        case .prizeWon(let tier, let best, _, let special): line("Prize: \(tier) (best set \(best)), wins a \(special)", prize: true)
        case .turnEnd(let reason, let totals):
            let why = ["player": "You ended the turn", "timer": "Time's up", "board_cleared": "Board cleared"][reason] ?? reason
            line("\(why): \(totals.steps) steps")
        default: break
        }
    }

    // MARK: Records (beta only: local files)

    private func finish() {
        timerTask?.cancel()
        guard Edition.isBeta, let t = turn else { return }
        struct Record: Encodable {
            let rulesVersion: String, seed: UInt64, dealer: Bool, app: String
            let actions: [MatchAction]; let rolls: [Roll]; let events: [MatchEvent]
        }
        let app = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") + ")"
        let rec = Record(rulesVersion: MatchTurn.rulesVersion, seed: seed, dealer: t.state.dealer, app: app, actions: actions, rolls: t.dice.rolls, events: events)
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = support.appendingPathComponent("\(Edition.name)/records", isDirectory: true)
            // The beta was called Crib Maze Beta until 0.9.1: bring its records along once.
            let old = support.appendingPathComponent("Crib Maze Beta/records", isDirectory: true)
            if Edition.isBeta, !FileManager.default.fileExists(atPath: dir.path), FileManager.default.fileExists(atPath: old.path) {
                try FileManager.default.createDirectory(at: dir.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: old, to: dir)
            }
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd-HHmmss"
            let url = dir.appendingPathComponent("match-\(f.string(from: Date()))-seed\(seed).json")
            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(rec).write(to: url)
            savedRecord = url
        } catch { show("Couldn't save the record: \(error.localizedDescription)") }
    }
}
