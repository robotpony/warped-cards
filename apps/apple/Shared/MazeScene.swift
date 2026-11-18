// The maze phase on screen (ui.md › Scene: Maze; maze.md › The screen): what the maze shows, the
// player's choices, the bots' turns, and the cues each maze event plays. The engine decides
// everything; this sends actions and presents their events one step at a time, so the board on
// screen (`shown`) lags the engine's while a walk hops or a card holds.
import CardKit
import CribMaze
import CribMazeBots
import CribbageKit
import Foundation
import GameKit
import Observation
import SwiftUI

@MainActor @Observable
final class MazeScene {
    weak var session: GameSession?

    /// What a tap on the board picks, after Close a door, Flip a switch, or an armed joker.
    enum Mode: Equatable { case none, close, flip, bomb, burn, swapper }

    /// A token hopping along a walk: its cells (the start, then the path), the cell it's on, and
    /// whether it's in the air towards the next since `since`.
    struct Hop: Equatable { let seat: Int; let cells: [Int]; var junctions: [MazeWay] = []; var index = 0; var moving = false; var since = Date() }
    /// The hazard pause: "FIRE!" or "BOOM!", what happened, and the plays lost.
    struct HazardPop: Equatable { let title: String; let text: String; let lost: [MazePlay]; let fire: Bool }
    /// A card over the maze until it's tapped: the stir, a bots' duel, plays owed, the hand's end.
    struct EventCard: Equatable { let title: String; let text: String; var button: String? = nil }
    /// A tap-to-explain card.
    struct Tip: Equatable { let lines: [(String, String)]
        static func == (a: Tip, b: Tip) -> Bool { a.lines.map(\.0) == b.lines.map(\.0) && a.lines.map(\.1) == b.lines.map(\.1) }
    }
    /// The duel as shown, built from its events.
    struct DuelShow: Equatable {
        let why: String
        let seats: [Int]
        var game = 1
        var hands: [[Card]]
        /// The cards since the count last started, with who played them.
        var run: [(seat: Int, card: Card)] = []
        var count = 0
        var scores = [0, 0]
        var said: String?
        var games: [[Int]] = []
        var turn: Int?
        var result: Result?
        var restart = false
        struct Result: Equatable { let winner: Int; let coin: Bool; let took: MazePlay?; let opened: String?; let scores: [[Int]] }
        static func == (a: DuelShow, b: DuelShow) -> Bool {
            a.game == b.game && a.hands == b.hands && a.run.map(\.card) == b.run.map(\.card) && a.count == b.count && a.scores == b.scores
                && a.said == b.said && a.result == b.result && a.turn == b.turn
        }
    }
    /// The game's end.
    struct Ended: Equatable { let winner: Int; let reason: String }

    /// The maze scene covers the phone.
    private(set) var on = false
    /// The maze as shown, and its cost field.
    private(set) var shown: Maze?
    private(set) var field: [Int] = []
    /// A token's cost at the start, for the header's % to go.
    private(set) var startCost = 1
    /// Overrides while a walk hops: doors it has worn or broken so far, hazards gone off.
    private(set) var doorsHit: [Int: (left: Int, broke: Bool)] = [:]
    private(set) var hazardsGone: Set<Int> = []
    private(set) var hop: Hop?
    private(set) var hazard: HazardPop?
    private(set) var card: EventCard?
    var tip: Tip?
    private(set) var duel: DuelShow?
    private(set) var ended: Ended?
    /// A short line about what just happened, in place of the status line.
    private(set) var flash: String?
    /// Events are playing out; the player's input waits.
    private(set) var busy = false
    var selected: Int?
    var mode: Mode = .none { didSet { wake() } }
    /// A reach's junctions the player turned, for the selected play.
    var ways: [MazeWay] = []
    /// The camera is easing: the board redraws every frame until it settles.
    private(set) var moving = false

    /// Snapshots: cues play at once, cards don't wait for a tap, and a bot plays the player's seat too.
    var instant = false
    var autoplay = false
    /// The grid turn's last step, which started the maze: the maze before it, and its maze events.
    var pending: (before: Maze, events: [MazeEvent])?

    /// The camera, eased every frame (MazeBoardView); not observed.
    @ObservationIgnored var cam: (cs: Double, x: Double, y: Double, t: Date)?

    private var gen = 0
    private var queue: [(events: [MazeEvent], before: Maze, after: Maze)] = []
    private var draining = false
    private var resume: CheckedContinuation<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var botTask: Task<Void, Never>?

    var config: MazeConfig? { session?.config?.maze }
    var timing: MazeConfig.Timing? { config?.timing }
    /// The maze as the engine has it.
    var engine: Maze? { session?.run?.state.maze }
    static let names = ["You", "Bot 1", "Bot 2"]
    func name(_ s: Int) -> String { s < Self.names.count ? Self.names[s] : "Seat \(s)" }
    var hand: Int { session?.run?.state.hand ?? 0 }

    // MARK: State for the screen

    /// The player's turn, with nothing playing out or covering the board.
    var myTurn: Bool {
        guard on, !busy, ended == nil, duel == nil, card == nil, hazard == nil, let m = engine else { return false }
        return m.turn == 0 && m.duel == nil && m.winner == nil
    }
    /// The play is used, and a joker is still possible: the turn waits for one or End turn.
    var afterPlay: Bool { myTurn && engine?.played == true }
    var myPlays: [MazePlay] { shown?.tokens.first?.plays ?? [] }
    var selectedPlay: MazePlay? { selected.flatMap { id in engine?.tokens.first?.plays.first { $0.id == id } } }
    /// Where a token is drawn: hopping, or its cell.
    func position(_ s: Int) -> Int? {
        if let h = hop, h.seat == s { return h.cells[h.index] }
        return shown.map { $0.tokens[s].pos }
    }

    /// The selected play's walk preview, with the reach's turned junctions.
    var preview: (walk: Maze.Walk, cost: Int)? {
        guard myTurn, !afterPlay, mode == .none, let p = selected, let m = engine else { return nil }
        return m.preview(seat: 0, play: p, ways: ways)
    }

    /// The status line: what's happening, or the hand's line.
    var status: String {
        if let f = flash { return f }
        if ended != nil { return "" }
        if let h = hop { return h.seat == 0 ? "You walk" : "\(name(h.seat)) walks" }
        guard let m = engine else { return "" }
        if let t = m.turn, t != 0 { return "\(name(t)) is choosing a play" }
        if myTurn {
            switch mode {
            case .close: return "Tap a passage to close"
            case .flip: return "Pick a switch to flip (its letter is on the maze)"
            case .bomb: return "Tap a door to blast it (it opens at \(config?.jokers.bombPower ?? 12) or less), or a ringed cell for a mine"
            case .burn: return "Tap a ringed cell on another player's way to set a fire"
            case .swapper: return "Pick a player to trade places with"
            case .none: break
            }
            if let p = selectedPlay, let pv = preview {
                return "\(p.steps) steps: " + (pv.walk.won ? "reaches the goal!" : "ends \(pv.cost) from the goal") + (pv.walk.doors.isEmpty ? "" : " · hits a door")
            }
        }
        return handLine
    }
    /// "Hand 3: your grid made 14 plays, 237 steps".
    var handLine: String {
        let plays = session?.handPlays[0] ?? []
        guard hand > 0 else { return "" }
        return "Hand \(hand): your grid made \(plays.count) play\(plays.count == 1 ? "" : "s"), \(plays.reduce(0) { $0 + $1.steps }) steps"
    }

    // MARK: Entering and leaving

    func reset() {
        gen += 1
        on = false; shown = nil; hop = nil; hazard = nil; card = nil; tip = nil; duel = nil; ended = nil; flash = nil
        busy = false; selected = nil; mode = .none; ways = []; queue = []; draining = false; pending = nil
        doorsHit = [:]; hazardsGone = []; cam = nil
        resume?.resume(); resume = nil
        botTask?.cancel(); botTask = nil
    }

    /// Shows the maze: the board as it was before the grid turn's last step, then that step's maze
    /// events (plays owed, the stir, a stuck duel), then the first turn.
    func enter() {
        guard let m = engine else { return }
        on = true; ended = nil
        let start = pending ?? (m, [])
        pending = nil
        setShown(start.before)
        startCost = max(1, field.indices.contains(start.before.board.start) ? field[start.before.board.start] : 1)
        cam = nil
        enqueue(start.events, before: start.before, after: m)
    }

    private func setShown(_ m: Maze) {
        shown = m; field = m.costField(); doorsHit = [:]; hazardsGone = []
        wake()
    }

    /// The camera eases for a while after anything moves.
    func wake() {
        moving = true
        wakeTask?.cancel()
        let ms = fx.maze.camera.settleMs
        wakeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(Motion.t(ms))))
            guard let self, !Task.isCancelled, self.hop == nil else { return }
            self.moving = false
        }
    }

    // MARK: The player's input

    func select(_ id: Int) {
        guard myTurn, !afterPlay else { return }
        selected = selected == id ? nil : id
        mode = .none; ways = []; tip = nil
        wake()
    }

    func cancel() { selected = nil; mode = .none; ways = []; wake() }

    func walk() {
        guard let p = selected else { return }
        send(.mazeWalk(play: p, ways: engine?.reachOn(0) == true && !ways.isEmpty ? ways : nil))
    }

    func close(_ cells: [Int]) {
        guard mode == .close, let p = selected else { return }
        send(.mazeClose(play: p, passage: cells))
    }

    func flip(_ letter: String) {
        guard let p = selected else { return }
        send(.mazeFlip(play: p, letter: letter))
    }

    func endTurn() { send(.mazeEndTurn) }

    /// A tray joker: a reach goes at once; a bomb, burn or swapper waits for its target. Tapping it again cancels.
    func tapJoker(_ kind: String) {
        guard myTurn, canJoker(kind) else { return }
        let m: Mode = ["bomb": .bomb, "burn": .burn, "swapper": .swapper][kind] ?? .none
        if kind == "reach" { send(.mazeJoker(kind: "reach", target: nil, cell: nil, passage: nil)); return }
        mode = mode == m ? .none : m
        tip = nil
    }

    /// Whether a tray joker can be used now: one a turn, not while a play's sheet is open, and never the key (it works by itself).
    func canJoker(_ kind: String) -> Bool {
        guard myTurn, let m = engine, kind != "key", !m.jokerUsed, selected == nil || afterPlay else { return false }
        if kind == "reach" && m.reachOn(0) { return false }
        return m.tokens[0].jokers[kind, default: 0] > 0
    }

    func swap(with q: Int) { send(.mazeJoker(kind: "swapper", target: q, cell: nil, passage: nil)) }
    func bombDoor(_ cells: [Int]) { send(.mazeJoker(kind: "bomb", target: nil, cell: nil, passage: cells)) }
    func hazardAt(_ cell: Int) { send(.mazeJoker(kind: mode == .bomb ? "bomb" : "burn", target: nil, cell: cell, passage: nil)) }

    /// A reach's junction on the previewed path, tapped: it turns to its next way, for this play only.
    func turnJunction(_ cell: Int) {
        guard let m = engine, let pv = preview, let i = pv.walk.junctions.firstIndex(where: { $0.cell == cell }) else { return }
        let came = i == 0 ? nil : pv.walk.path.firstIndex(of: cell).flatMap { $0 > 0 ? pv.walk.path[$0 - 1] : m.tokens[0].pos }
        let back = (cell == m.tokens[0].pos ? m.tokens[0].from : came).flatMap { m.board.dir(cell, $0) }
        var ways = m.board.liveExits(cell).filter { $0 != back }
        if ways.count < 2 { ways = m.board.exits(cell).filter { $0 != back } }
        guard ways.count > 1 else { return }
        let now = pv.walk.junctions[i].dir
        let next = ways[((ways.firstIndex(of: now) ?? -1) + 1) % ways.count]
        self.ways.removeAll { $0.cell == cell }
        self.ways.append(MazeWay(cell: cell, dir: next))
        wake()
    }

    /// A duel card, when it's the player's to play.
    func duelPlay(_ card: Card) {
        guard let d = duel, d.result == nil, !busy, let m = engine?.duel, m.seats[m.peg.turn] == 0,
              m.peg.legal(m.peg.turn).contains(where: { $0.id == card.id }) else { return }
        send(.duelCard(card: CardRef(card)))
    }

    /// The cards the player may play in the duel now; empty while it isn't their turn.
    var duelLegal: Set<Int> {
        guard let d = duel, d.result == nil, !busy, let m = engine?.duel, m.seats[m.peg.turn] == 0 else { return [] }
        return Set(m.peg.legal(m.peg.turn).map(\.id))
    }

    /// A tap on an event card, a result, or the hazard card moves on.
    func dismiss() {
        tip = nil
        if instant { card = nil; if duel?.result != nil { duel = nil } }
        if let r = resume { resume = nil; r.resume() } else if !draining { next() }
    }

    private func send(_ a: MazeAction, seat: Int = 0) {
        guard let s = session, let before = engine else { return }
        tip = nil
        guard let step = s.act(.maze(a), by: seat), let after = engine else { return }
        if seat == 0 { selected = nil; mode = .none; ways = [] }
        enqueue(step.events.compactMap(\.mazeEvent), before: before, after: after)
    }

    // MARK: Presenting events

    private func enqueue(_ events: [MazeEvent], before: Maze, after: Maze) {
        queue.append((events, before, after))
        guard !draining else { return }
        draining = true; busy = true
        let g = gen
        Task { [weak self] in
            guard let self else { return }
            while self.gen == g, !self.queue.isEmpty {
                let s = self.queue.removeFirst()
                await self.present(s.events, before: s.before, after: s.after, gen: g)
            }
            guard self.gen == g else { return }
            self.draining = false; self.busy = false
            self.wake()
            self.next()
        }
    }

    private func sleep(_ ms: Int) async {
        guard !instant, ms > 0 else { return }
        try? await Task.sleep(for: .milliseconds(Motion.ms(Double(ms))))
    }

    /// Waits for a tap (or, in snapshots, not at all).
    private func waitTap() async {
        guard !instant else { return }
        await withCheckedContinuation { resume = $0 }
    }

    private func present(_ events: [MazeEvent], before: Maze, after: Maze, gen g: Int) async {
        if shown == nil { setShown(before) }
        if instant { hazard = nil; if card?.button == nil { card = nil } }
        var applied = false
        func apply() { if !applied { applied = true; setShown(after) } }
        let bot = timing?.botPegMs ?? 850
        for (i, e) in events.enumerated() {
            guard gen == g else { return }
            switch e {
            case .walk(let seat, _, _, let path, let junctions, let doors, let stopped, let key, _, let won, _):
                let hits: [MazeEvent] = events[(i + 1)...].filter { if case .hazardHit(seat, _, _, _, _, _, _) = $0 { true } else { false } }
                await animateWalk(seat: seat, from: before.tokens[seat].pos, path: path, junctions: junctions, doors: doors, hits: hits, before: before, gen: g)
                apply()
                if stopped { flashLine("\(name(seat)) \(seat == 0 ? "are" : "is") stopped by a door of another suit") }
                else if key { flashLine("A key lets \(seat == 0 ? "you" : name(seat)) through a door") }
                else if won { flashLine("") }
            case .doorClosed(let seat, _, _, let suit, let strength):
                apply(); flashLine("\(name(seat)) close\(seat == 0 ? "" : "s") a \(glyph(suit))\(strength) door")
                if seat != 0 { await sleep(bot) }
            case .switchFlipped(let seat, _, let letter):
                apply(); flashLine("\(name(seat)) flip\(seat == 0 ? "" : "s") switch \(letter)")
                if seat != 0 { await sleep(bot) }
            case .swapped(let seat, let target, _):
                apply(); flashLine(seat == 0 ? "You trade places with \(name(target))" : "\(name(seat)) trades places with \(target == 0 ? "you" : name(target))")
                await sleep(bot)
            case .doorBombed(let seat, _, let opened, let left):
                apply(); flashLine("\(name(seat)) bomb\(seat == 0 ? "" : "s") a door: " + (opened ? "it opens" : "\(left) left"))
                if seat != 0 { await sleep(bot) }
            case .hazardSet(let seat, let kind, _):
                apply(); flashLine("\(name(seat)) set\(seat == 0 ? "" : "s") a \(kind == "mine" ? "mine" : "fire") on " + (seat == 0 ? "\(name(1))'s way" : "your way"))
                if seat != 0 { await sleep(bot) }
            case .reachOn(let seat):
                apply(); flashLine(seat == 0 ? "Reach is on: your next play picks its ways" : "\(name(seat)) uses a reach")
                if seat != 0 { await sleep(bot) }
            case .star(let seat, _, let joker):
                apply()
                session?.show("\(seat == 0 ? "You land" : "\(name(seat)) lands") on a star: +1 \(Self.jokerName(joker))")
                await sleep(bot)
            case .hazardHit: apply()   // shown during the walk
            case .playsOwed(let seat, let lost, let owed):
                apply()
                guard !lost.isEmpty || owed > 0 else { continue }
                await showCard(EventCard(title: "Plays owed", text: "\(seat == 0 ? "Your" : "\(name(seat))'s") hazard damage from the last hand takes \(lost.count) of \(seat == 0 ? "your" : "its") new plays" + (owed > 0 ? ", and \(owed) more next hand." : ".")))
            case .stir(let seat, let opening, _, _):
                apply()
                await showCard(EventCard(title: "The maze stirs", text: stirText(seat, opening, before)))
            case .duelStart(let why, let seats, _, let game, let hands):
                apply()
                let cards = hands.map { $0.compactMap { r in Card.parse(r.card).map { c in Card(id: r.id, kind: c.kind, rank: c.rank, suit: c.suit) } } }
                if var d = duel, game > 1 {
                    d.games = d.games + [d.scores]; d.game = game; d.hands = cards; d.run = []; d.count = 0; d.scores = [0, 0]
                    d.said = "A tie: one more game, the other player leading"; duel = d
                    await sleep(bot)
                } else if seats.contains(0) {
                    duel = DuelShow(why: why, seats: seats, hands: cards)
                    await sleep(bot / 2)
                }
            case .duelCard(let seat, let ref, let count, let scores):
                guard var d = duel, let k = d.seats.firstIndex(of: seat) else { continue }
                if d.restart { d.run = []; d.restart = false }
                d.hands[k].removeAll { $0.id == ref.id }
                if let c = Card.parse(ref.card) { d.run.append((seat, Card(id: ref.id, kind: c.kind, rank: c.rank, suit: c.suit))) }
                d.count = count
                let pts = scores.reduce(0) { $0 + $1.points }
                d.scores[k] += pts
                d.said = pts > 0 ? "\(name(seat)): " + scores.map { "\(Self.pegName($0.kind)), \($0.points)" }.joined(separator: "; ") : nil
                if count == config?.duel.peg.maxCount { d.restart = true }
                duel = d
                await sleep(seat == 0 ? bot / 2 : bot)
            case .duelGo(let seat):
                guard var d = duel else { continue }
                d.said = "\(name(seat)): go"; duel = d
                await sleep(bot / 2)
            case .duelPoint(let seat, _, let points, _):
                guard var d = duel, let k = d.seats.firstIndex(of: seat) else { continue }
                d.scores[k] += points; d.said = "\(name(seat)): the go, \(points)"; d.restart = true; duel = d
                await sleep(bot)
            case .duelEnd(let why, let seats, let scores, let winner, let coin, let took, let opened):
                apply()
                let play = took.flatMap { id in after.tokens[winner].plays.first { $0.id == id } }
                if var d = duel {
                    d.result = .init(winner: winner, coin: coin, took: play, opened: opened, scores: scores); d.turn = nil; duel = d
                    await waitTap()
                    duel = nil
                } else {
                    // Two bots: the result shows as a card over the maze.
                    let s = scores.last ?? [0, 0]
                    await showCard(EventCard(title: "Duel: \(name(seats[0])) and \(name(seats[1]))",
                                             text: "\(name(winner)) wins \(s.max() ?? 0) to \(s.min() ?? 0)" + (coin ? " on a coin" : "") + (play.map { ", and takes a \($0.steps)-step play" } ?? "") + (why == "stuck" && opened != nil ? ". The way opens." : ".")))
                }
            case .mazeHandEnd(let h, _):
                apply()
                if (session?.run?.state.over ?? false) == false {
                    card = EventCard(title: "Hand \(h) is over", text: "Every play is used. Your power jokers go with you to the next grid.", button: "Deal hand \(h + 1)")
                }
            case .mazeEnd(let winner, let reason, _):
                apply()
                ended = Ended(winner: winner, reason: reason)
            case .mazeTurn, .mazeBuilt: apply()
            }
        }
        apply()
    }

    private func showCard(_ c: EventCard) async {
        card = c
        await waitTap()
        if !instant { card = nil }
    }

    /// A line in place of the status line, for a moment.
    private func flashLine(_ s: String) {
        flash = s.isEmpty ? nil : s
        guard !s.isEmpty else { return }
        let g = gen
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Motion.ms(fx.maze.eventHoldMs)))
            guard let self, self.gen == g, self.flash == s else { return }
            self.flash = nil
        }
    }

    private func animateWalk(seat: Int, from: Int, path: [Int], junctions: [MazeWay], doors: [WalkDoor], hits: [MazeEvent], before: Maze, gen g: Int) async {
        let t = timing
        let step = t?.stepMs ?? 90
        hop = Hop(seat: seat, cells: [from] + path, junctions: junctions)
        wake()
        await sleep(t?.walkDelayMs ?? 350)
        for k in 0...path.count {
            guard gen == g else { return }
            // Doors met before this cell: their damage shows as the token reaches them.
            for d in doors where d.at == k {
                if let key = before.board.key(d.passage[0], d.passage[1]), let p = before.board.passages[key] {
                    doorsHit[key] = (p.left - d.hit, d.broke)
                }
                await sleep(step)
            }
            guard k < path.count else { break }
            hop?.moving = true; hop?.since = Date()
            await sleep(step)
            hop?.index = k + 1; hop?.moving = false
            let c = path[k]
            for h in hits {
                guard case .hazardHit(_, let kind, c, let landed, let lose, let lost, let owed) = h else { continue }
                hazardsGone.insert(c)
                let fire = kind == "fire"
                let plays = lost.compactMap { id in before.tokens[seat].plays.first { $0.id == id } }
                let who = seat == 0 ? "You" : name(seat)
                let verb = landed ? (seat == 0 ? "stop on" : "stops on") : (seat == 0 ? "run over" : "runs over")
                let what = "\(lose) play" + (lose == 1 ? (fire ? " burns" : " blows up") : (fire ? "s burn" : "s blow up"))
                hazard = HazardPop(title: fire ? "FIRE!" : "BOOM!", text: "\(who) \(verb) a \(fire ? "fire" : "mine"): \(what)" + (owed > 0 ? ", \(owed) owed from the next hand" : ""), lost: plays, fire: fire)
                await sleep(landed ? (t?.hazardLandHoldMs ?? 2200) : (t?.hazardHoldMs ?? 1800))
                if !instant { hazard = nil }
            }
        }
        hop = nil
    }

    // MARK: Bots

    /// After events play out: a bot's turn goes after a pause; the player's waits for input.
    private func next() {
        guard on, ended == nil, card == nil, let m = engine, m.winner == nil, let c = session?.config else { return }
        let seat: Int
        if let d = m.duel { seat = d.seats[d.peg.turn] } else if let t = m.turn { seat = t } else { return }
        guard seat != 0 || autoplay else { return }
        let style = seat == 0 ? "balanced" : (session?.settings.mazeStyle ?? "balanced")
        guard let bot = MazeBot(config: c, style: style) ?? MazeBot(config: c, style: "balanced") else { return }
        let g = gen
        botTask = Task { [weak self] in
            guard let self else { return }
            await self.sleep(self.timing?.botPegMs ?? 850)
            guard self.gen == g, !self.busy, let m = self.engine else { return }
            let a = bot.choose(m)
            if seat == 0, case .mazeEndTurn = a, !m.played { return }
            self.send(a, seat: seat)
            // An action the engine refused would stall the turn: walk the first play instead.
            if !self.busy, self.engine?.turn == seat, self.engine?.played == false, let p = self.engine?.tokens[seat].plays.first {
                self.send(.mazeWalk(play: p.id, ways: nil), seat: seat)
            }
        }
    }

    /// Snapshots and the demo: a balanced bot plays the player's seat for one action.
    func autoAct() {
        guard let c = session?.config, let m = engine, let bot = MazeBot(config: c, style: "balanced") else { return }
        send(bot.choose(m), seat: 0)
    }
    /// Whether the scene waits on the player: their turn or duel card, a card to tap, or the end.
    var waitingOnPlayer: Bool {
        guard !busy else { return false }
        if ended != nil || card != nil { return true }
        guard let m = engine else { return true }
        if let d = m.duel { return d.seats[d.peg.turn] == 0 }
        return m.turn == 0 || m.turn == nil
    }

    /// The hand-end card's button: the next hand's deal.
    func nextHand() {
        card = nil
        session?.nextTurn()
    }

    // MARK: Words

    static func jokerName(_ k: String) -> String { ["swapper": "swapper", "bomb": "bomb", "reach": "reach", "burn": "burn", "key": "key"][k] ?? k }
    static func pegName(_ k: String) -> String { ["fifteen": "fifteen", "thirty_one": "thirty-one", "pair": "pair", "run": "run", "last_card": "last card", "go": "go"][k] ?? k }
    func glyph(_ suit: String?) -> String { suit.flatMap { Suit(letter: $0)?.textGlyph } ?? "" }

    private func stirText(_ seat: Int, _ opening: String, _ before: Maze) -> String {
        let who = seat == 0 ? "you" : name(seat)
        switch opening {
        case "fade":
            let suit = before.wayAhead(seat).door.flatMap { before.board.passages[$0]?.suit }
            return "The \(glyph(suit)) door ahead of \(who) fades: it loses its suit, and half its strength."
        case "star": return "A star falls on \(seat == 0 ? "your" : "\(name(seat))'s") way, a few cells ahead."
        default: return "A wall beside \(who) opens."
        }
    }

    /// What a tapped spot on the board is (ui.md › Scene: Maze › Tap to explain).
    func explain(cell i: Int, side: Dir?) -> Tip? {
        guard let m = shown else { return nil }
        let b = m.board
        var out: [(String, String)] = []
        if let d = side, let k = b.key(i, d), let p = b.passages[k] {
            switch p.kind {
            case .door:
                let s = p.suit.map(glyph) ?? "no suit"
                out.append(("Door \(s), \(p.left) left (of \(p.strength)).",
                            "Only \(p.suit == nil ? "any" : glyph(p.suit)) steps wear it down, and steps spent on it don't move you. Another suit stops here and loses the rest of its walk."
                                + (p.shortcut ? " It guards a shortcut that saves \(p.saves ?? 0) steps." : "") + (p.closedBy.map { " Closed by \(name($0))." } ?? "")))
            case .switch:
                out.append(("Switch \(Maze.letters[p.sw ?? 0]), now \(p.on ? "open" : "shut").", "Flipping it (with a play) swaps it with its pair, for everyone, once a hand."))
            case .open where p.broken: out.append(("A broken door.", "Open for everyone."))
            default: break
            }
        }
        for t in m.tokens where t.pos == i {
            out.append((name(t.seat), "\(t.seat == 0 ? "" : "A balanced bot. ")\(field.indices.contains(i) ? field[i] : 0) steps to the goal, \(t.plays.count) plays left."))
        }
        if i == b.goal { out.append(("The goal.", "The first token here wins.")) }
        if i == b.start { out.append(("The start.", "Every token starts here.")) }
        if b.stars.contains(i) { out.append(("A star.", "End a walk here to win a power joker.")) }
        if let h = m.hazards.first(where: { $0.cell == i }) {
            let r = h.kind == "mine" ? config?.hazards.mine : config?.hazards.fire
            let pass = r.map { "\($0.pass[0]) or \($0.pass[1])" } ?? "", land = r.map { "\($0.land[0]) or \($0.land[1])" } ?? ""
            out.append((h.kind == "mine" ? "A mine, set by \(name(h.seat))." : "A fire, set by \(name(h.seat)).",
                        "The next token over it loses \(pass) plays; one that stops here loses \(land). Then it's gone."))
        }
        if b.liveExits(i).count >= 3 {
            let ways = ["up", "right", "down", "left"]
            out.append(("A junction.", "The next token through goes \(ways[b.arrow[i].rawValue]); then it turns to the next way, so the one after goes another way."))
        }
        if out.isEmpty { out.append(("An open path.", "")) }
        return Tip(lines: out)
    }

    /// A player in the header, tapped.
    func explain(seat s: Int) -> Tip? {
        guard let m = shown, s < m.tokens.count else { return nil }
        let t = m.tokens[s]
        let jokers = ["swapper", "bomb", "reach", "burn", "key"].filter { t.jokers[$0, default: 0] > 0 }
            .map { Self.jokerName($0) + (t.jokers[$0]! > 1 ? " ×\(t.jokers[$0]!)" : "") }.joined(separator: ", ")
        let cost = field.indices.contains(t.pos) ? field[t.pos] : 0
        return Tip(lines: [(name(s) + (s == 0 ? "" : " · a balanced bot") + (m.turn == s ? " · their turn" : ""),
                            "\(cost) steps to the goal. \(t.plays.count) play\(t.plays.count == 1 ? "" : "s") left, \(t.plays.reduce(0) { $0 + $1.steps }) steps in all. Power jokers: \(jokers.isEmpty ? "none" : jokers). Doors closed this hand: \(t.closed).")])
    }
}
