// The app's game state: a game of match turns (its deck lasts the game), the turn being played,
// the player's input mode and the timer.
// The engine decides everything; this only sends actions and keeps the events. The game runs
// through GameKit's GameRun, so every step can go to a recorder (the beta's GameRecord file).
import CardKit
import CribMaze
import CribMazeBots
import CribbageKit
import Foundation
import GameKit
import Observation
import SwiftUI

enum InputMode: Equatable {
    case trace, swap, bomb, burn
    /// The mode a power joker arms; a reach or a key needs no target, so it has none.
    static func arming(_ kind: String) -> InputMode? { ["swapper": .swap, "bomb": .bomb, "burn": .burn][kind] }
    /// Whether a tap on one grid card fires it.
    var targetsACard: Bool { self == .bomb || self == .burn }
}

struct FeedLine: Identifiable { let id: Int; let text: String; let points: Int?; var prize = false }

/// The last score, for the breakdown panel.
struct Breakdown {
    let cards: [String]
    let lines: [(String, Int)]
    let comboPoints: Int, percent: Int, leftOver: Int, cost: Int, points: Int
}

struct TurnSettings: Equatable {
    var dealer = true     // the player deals the game's first turn; the deal then alternates
    var timer = true
    var hand = "random"   // or "strong"
    var budget = 0        // 0 is the whole stock
    var breakdown = true  // play each score's breakdown; off is a quick flash
    var hints = true      // nudge the player when they seem stuck (Hints.swift)
    var deal = true       // deal 6 and pick 2 for the crib before each turn
    var sharedDeck = true // deck building: changed cards go into the shared deck (rules.json deck.shared)
    var mazeGame = true   // a game around the maze (maze.md): a bot's grid turn, then the maze, hand after hand
    var mazeStyle = "balanced"   // the bot's maze style, from bots.json › maze
}

/// The deal before a turn: your 6, the 2 you've picked for the crib, and the hint, if one showed.
struct DealState {
    let dealt: Dealt
    /// The bot's throw, decided up front (its best classic hand); shown face down once you throw.
    let botThrown: [Card]
    var picked: [Card] = []
    /// Your 6 in the order you've sorted them (r24); the 4 you keep go along the hand row in this order.
    var order: [Card]
    init(dealt: Dealt, botThrown: [Card]) { self.dealt = dealt; self.botThrown = botThrown; order = dealt.player }
    /// The cards still in your hand, in your order.
    var held: [Card] { order.filter { !picked.contains($0) } }
    let started = Date()
    var changed = Date()
    var hint: PrincipleHit?
    var hintAt: Date?
    var asked = false
}

@MainActor @Observable
final class GameSession {
    private(set) var config: Config?
    private(set) var loadError: String?
    /// The game: its turns, the deck that lasts it, and the power jokers carried between turns.
    private(set) var game: MatchGame?
    /// The game as it was when this turn started, for the summary's deck before and after.
    private(set) var gameAtTurnStart: MatchGame?
    private(set) var turn: MatchTurn?
    private(set) var events: [MatchEvent] = []
    /// The game as the engine has it: always current, while `turn` shows what's been presented.
    private(set) var run: GameRun<CribMazeGame>?
    /// Where steps go besides the screen: the beta's record file; none in release or snapshots.
    private var recorder: (any GameRecorder)?
    /// Game time (engine.md › Clock and timer): since the game started, stopped whenever the turn
    /// timer is (a move playing, the warning, an info card), so actions are stamped in play time.
    private var clockBase: Duration = .zero
    private var clockSince: ContinuousClock.Instant? = ContinuousClock.now
    private var clockPaused: Bool { busy || warning != nil || info != nil }
    private func syncClock() {
        if clockPaused, let since = clockSince { clockBase += ContinuousClock.now - since; clockSince = nil }
        else if !clockPaused, clockSince == nil { clockSince = .now }
    }
    private var gameTime: Duration { clockBase + (clockSince.map { ContinuousClock.now - $0 } ?? .zero) }
    /// The demo bot's own dice, apart from the game's.
    private var botDice = Dice(seed: 1)
    private(set) var feed: [FeedLine] = []
    private(set) var breakdown: Breakdown?
    private(set) var toast: String?
    /// The first-time left-over warning: the cards left over, until "Got it".
    private(set) var warning: [String]? { didSet { syncClock() } }
    /// An info card the player opened by tapping a word tag or the card counter.
    var info: InfoTopic? { didSet { syncClock() } }
    /// Input waits while a card covers the board.
    var blocked: Bool { over || busy || warning != nil || info != nil }
    func dismissWarning() { warning = nil }
    /// Cards popping before they clear: scored sets in gold, bomb blasts in red.
    private(set) var flash: Set<Pos> = []
    private(set) var flashIsBomb = false
    /// Snapshots only: show cards mid-pop.
    func snapshotFlash(_ ps: Set<Pos>, bomb: Bool) { flash = ps; flashIsBomb = bomb }
    /// The opening count (r24): grid cards wait off the board while the hand and crib are counted.
    private(set) var gridHidden = false
    /// The grid filling in (ui.md › The grid fills): the grid cells shown so far, or nil for all, and
    /// the pattern they come in with.
    private(set) var gridShown: Set<Pos>?
    private(set) var fillPattern: FX.Fill.Pattern?
    /// Beta only: fill with this pattern instead of the turn's pick (`--fill`).
    var forcedFill: String?
    /// Beta only: skip the opening count and play only the fill (the `fill` film cue).
    var fillOnly = false
    func gridVisible(_ p: Pos) -> Bool { !Board.isGrid(p) || (!gridHidden && (gridShown?.contains(p) ?? true)) }

    /// The turn's fill pattern and the order its cells come in, as groups that land together. Picked
    /// from the turn's seed on its own stream, `fx.fill`, which the game never draws from.
    func fillPlan() -> (FX.Fill.Pattern, [[Pos]]) {
        var dice = DiceStream(gameSeed: game?.turnSeed ?? seed, name: "fx.fill")
        let all = fx.fill.patterns
        var pattern = all[dice.below(all.count)]
        if let f = forcedFill, let forced = all.first(where: { $0.name == f }) { pattern = forced }
        let g = { (r: Int, c: Int) in Board.g(r, c) }
        let groups: [[Pos]]
        switch pattern.order {
        case "columns": groups = (0..<4).map { c in (0..<4).map { g($0, c) } }
        case "spiral":
            let rc = [(0,0),(0,1),(0,2),(0,3),(1,3),(2,3),(3,3),(3,2),(3,1),(3,0),(2,0),(1,0),(1,1),(1,2),(2,2),(2,1)]
            groups = rc.map { [g($0.0, $0.1)] }
        case "diagonal":   // from the corner by the starter (bottom right) to the top left
            groups = (0...6).map { k in (0..<16).map { g($0 / 4, $0 % 4) }.filter { p in (3 - p / 4) + (3 - p % 4) == k } }
        case "random":
            var cells = (0..<16).map { g($0 / 4, $0 % 4) }
            for i in stride(from: cells.count - 1, through: 1, by: -1) { cells.swapAt(i, dice.below(i + 1)) }
            groups = cells.map { [$0] }
        default: groups = (0..<16).map { [g($0 / 4, $0 % 4)] }   // rows, in reading order
        }
        return (pattern, groups)
    }

    /// Beta films only: off to start a cue from the dealt board, with the counts' steps already in.
    var playsOpening = true
    /// Counts turns shown, so an opening count still playing stops when a new turn starts.
    private var turnGen = 0
    /// The step count while the opening count plays, before its steps have landed; nil shows the turn's.
    private(set) var stepsShown: Int?
    var shownSteps: Int { stepsShown ?? state?.steps ?? 0 }
    /// The grid intro (0.20.0): after the opening count, a card saying what the grid is for, held
    /// until Start is tapped. Nil when it isn't showing.
    struct GridIntro: Equatable { let counted: String; let steps: Int; let starterJoins: Bool; let maxEdgeCards: Int?; let timerSeconds: Int }
    private(set) var gridIntro: GridIntro?
    private var introResume: CheckedContinuation<Void, Never>?
    /// Start on the grid intro: the grid deals in and the timer starts.
    func startGrid() { gridIntro = nil; introResume?.resume(); introResume = nil }
    func snapshotIntro() {
        guard let t = turn else { return }
        gridHidden = true; gridIntro = intro(t)
    }
    private func intro(_ t: MatchTurn) -> GridIntro {
        let crib = events.contains { if case .opening("crib", _, _, _, _, _, _, _) = $0 { true } else { false } }
        let m = t.config.rules.match
        return GridIntro(counted: crib ? "hand and crib" : "hand", steps: t.state.totals.openingSteps, starterJoins: m.starterJoins ?? false,
                         maxEdgeCards: m.maxEdgeCards, timerSeconds: m.timerSeconds)
    }

    /// The opening bonus (r26): the tray as shown while the counts play, before their jokers land.
    private(set) var trayShown: [String: Int]?
    func shownTray(_ kind: String) -> Int { (trayShown ?? state?.tray)?[kind] ?? 0 }
    /// Snapshots only: the board as the opening count shows it, the grid waiting and the steps before it.
    func snapshotOpening(steps: Int, unlanded: [String] = []) {
        gridHidden = true; stepsShown = steps
        var tray = state?.tray ?? [:]
        for k in unlanded { tray[k, default: 0] -= 1 }
        trayShown = tray
    }
    /// While a move plays out, input waits.
    private(set) var busy = false { didSet { syncClock() } }
    /// Cards drawn into each grid column by the last move, so new cards drop in from above as a block.
    private(set) var drawnPerColumn = [Int](repeating: 0, count: 4)
    /// Off for snapshots: moves apply at once.
    var animate = true
    /// The score breakdown as it plays, and its timing.
    let playback = Playback()
    let meter = FrameMeter()
    var slowMotion = false { didSet { Motion.scale = slowMotion ? fx.waits.slowMotion : 1 } }
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

    /// The maze phase's scene (MazeScene.swift): what it shows, and its bots.
    let mazeScene = MazeScene()
    /// This hand's bots' grid turns (their `botTurn` events), for the summary before the maze.
    private(set) var botResults: [CribMazeGame.Event] = []
    /// Each seat's plays for this hand's maze, from `handPlays`.
    private(set) var handPlays: [Int: [MazePlay]] = [:]
    /// Whether this game is a game around the maze.
    var mazeGame: Bool { run?.state.config.mazeGame ?? false }
    /// The hand's maze phase is waiting to be shown (the grid turn's summary is up).
    var mazeWaiting: Bool { if case .maze = run?.state.stage { !mazeScene.on } else { false } }
    /// From the grid turn's summary into the maze.
    func toMaze() { mazeScene.enter() }

    init() {
        defer { meter.moving = { [weak self] in self?.busy ?? false } }
        mazeScene.session = self
        do {
            guard let folder = Bundle.main.url(forResource: "config", withExtension: nil) else { throw ConfigError(description: "config folder missing from the app") }
            config = try Config.load(from: folder)
            timing = BreakdownTiming.load(from: folder)
        } catch { loadError = "\(error)" }
        newGame()
    }

    var state: MatchState? { turn?.state }
    /// Whether the player deals this turn (it alternates through a game).
    var dealer: Bool { game?.dealer ?? settings.dealer }
    /// Whether the game has more turns to play after this one.
    var moreTurns: Bool { !(game?.over ?? true) }
    var over: Bool { dealing == nil && botsFirst == nil && (turn?.state.over ?? true) }
    /// A maze game's hand: the bots' grid turns are shown first (concept.md › Phases › 5a), and
    /// your turn starts from this step once you've seen them (ui.md › Scene: Bots' turns).
    private(set) var botsFirst: Step<CribMazeGame>?
    /// After the bots' turns: your grid turn starts.
    func toGrid() {
        guard let step = botsFirst else { return }
        botsFirst = nil
        begin(step)
    }
    /// Starts your turn from a step, or shows the bots' turns first when they played some.
    private func beginOrBots(_ step: Step<CribMazeGame>) {
        if mazeGame && !botResults.isEmpty { botsFirst = step } else { begin(step) }
    }

    // MARK: Deal

    /// The deal in progress, before the turn starts; nil once you've thrown to the crib.
    private(set) var dealing: DealState?
    /// What the deal was, for the turn's record.
    private(set) var dealRecord: DealRecord?
    private var hintTask: Task<Void, Never>?
    /// How long a pause before a discard hint shows (concept.md › Hints: subtle).
    static let hintAfter: TimeInterval = 8

    struct DealRecord: Codable {
        let dealt: [String], thrown: [String], botThrown: [String], starter: String
        let hint: String?, hintCards: [String], hintAsked: Bool, hintAfterMs: Int?, decideMs: Int
    }

    /// Picks or unpicks a card for the crib; at most 2.
    func togglePick(_ card: Card) {
        guard var d = dealing else { return }
        if let i = d.picked.firstIndex(of: card) { d.picked.remove(at: i) } else if d.picked.count < 2 { d.picked.append(card) }
        d.changed = Date()
        dealing = d
    }

    /// Moves a card in your hand to another place among the cards you hold (drag to sort).
    func moveHeld(_ card: Card, to index: Int) {
        guard var d = dealing, var held = Optional(d.held), let from = held.firstIndex(of: card) else { return }
        held.remove(at: from)
        held.insert(card, at: max(0, min(held.count, index)))
        d.order = held + d.picked
        d.changed = Date()
        dealing = d
    }

    /// Shows the deal's hint now (asked for, or after a pause).
    func showHint(asked: Bool = false) {
        guard var d = dealing, d.hint == nil, let h = config?.hints?.discard else { return }
        d.hint = Principles.best(for: d.dealt.player, hints: h)
        d.hintAt = Date(); d.asked = asked
        dealing = d
        if d.hint == nil && asked { show("Nothing stands out: keep cards that work together") }
    }

    private func watchHint() {
        hintTask?.cancel()
        hintTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let d = self.dealing, d.hint == nil else { return }
                guard self.settings.hints else { continue }
                if Date().timeIntervalSince(d.changed) >= Self.hintAfter { self.showHint(); return }
            }
        }
    }

    /// Throws the 2 picked cards to the crib and starts the turn.
    func throwToCrib() {
        guard let d = dealing, d.picked.count == 2 else { return }
        hintTask?.cancel()
        let bot = (keep: d.dealt.bot.filter { !d.botThrown.contains($0) }, thrown: d.botThrown)
        let ms = { (t: Date) in Int(t.timeIntervalSince(d.started) * 1000) }
        dealRecord = DealRecord(dealt: d.dealt.player.map(\.notation), thrown: d.picked.map(\.notation), botThrown: bot.thrown.map(\.notation),
                                starter: d.dealt.starter.notation, hint: d.hint?.principle.rawValue, hintCards: d.hint?.cards.map(\.notation) ?? [],
                                hintAsked: d.asked, hintAfterMs: d.hintAt.map(ms), decideMs: ms(Date()))
        dealing = nil
        guard let step = act(.discard(thrown: d.picked.map(CardRef.init), kept: d.held.map(CardRef.init))) else { return }
        recorder?.note("deal_hint", dealRecord)
        beginOrBots(step)
    }

    // MARK: Turn

    /// Starts a game: its seed (typed, given, or random), the settings it keeps, and its first turn.
    func newGame(seed fixed: UInt64? = nil) {
        guard var c = config else { return }
        seed = fixed ?? UInt64(seedText) ?? UInt64.random(in: 1...999_999)   // app only: the engine never draws its own randomness
        seedText = ""
        c.rules.deck = .init(shared: settings.sharedDeck, minSize: c.rules.deck?.minSize)
        let maze = settings.mazeGame && c.maze != nil
        let (r, opening) = GameRun<CribMazeGame>.start(.init(c, firstDealer: settings.dealer, mazeGame: maze), seed: seed,
                                                       players: [.human(0), .bot(1, level: maze ? "medium" : "classic")])
        mazeScene.reset()
        run = r; game = r.state.game; clockBase = .zero; clockSince = clockPaused ? nil : .now; botDice = Dice(seed: seed); savedRecord = nil
        recorder = Edition.isBeta && animate ? Recording.recorder() : nil   // snapshots (animate off) save no records
        recorder?.started(r)
        recorder?.record(opening)
        startTurn()
    }
    /// The old name, for the snapshot tools: a new game.
    func newTurn(seed fixed: UInt64? = nil) { newGame(seed: fixed) }

    /// The game's next turn, after the summary.
    func nextTurn() { guard moreTurns, over else { return }; startTurn() }

    private func startTurn() {
        guard config != nil, let g = run?.state.game else { return }
        game = g; gameAtTurnStart = g
        dealRecord = nil; hintTask?.cancel()
        mazeScene.reset(); botResults = []; handPlays = [:]; botsFirst = nil
        let strong = settings.hand == "strong"
        // A game around the maze always deals: the bot's grid turn plays from its own 4 kept cards.
        let options = CribMazeGame.HandOptions(deal: (settings.deal || mazeGame) && !strong, fixedHand: strong ? ["4H", "5C", "6D", "JS"] : nil, fixedStarter: strong ? "5S" : nil,
                                               cardBudget: settings.budget, timerSeconds: settings.timer ? nil : 0)
        guard let step = act(.startHand(options)) else { return }
        if case .dealing(let dealt, let botThrown, _) = run?.state.stage {
            // Deal first: the turn starts once you've thrown to the crib.
            timerTask?.cancel(); reachTask?.cancel(); deadTask?.cancel()
            turn = nil; events = []; feed = []; breakdown = nil; selection = []; warning = nil; toast = nil; info = nil
            turnGen += 1; gridHidden = false; gridShown = nil; fillPattern = nil; stepsShown = nil; trayShown = nil; busy = false; startGrid()
            playback.reset()
            dealing = DealState(dealt: dealt, botThrown: botThrown)
            watchHint()
            return
        }
        dealing = nil
        beginOrBots(step)
    }

    /// Shows the turn a step started.
    private func begin(_ step: Step<CribMazeGame>) {
        guard let t = run?.state.turn else { return }
        turnGen += 1; gridHidden = false; gridShown = nil; fillPattern = nil; stepsShown = nil; trayShown = nil; busy = false; startGrid()
        playback.reset(); info = nil; deadTask?.cancel(); graceLeft = nil; reachTask?.cancel(); reachTask = nil; reachLeft = [:]; keyReaches = []
        let ev = step.events.compactMap(\.matchEvent)
        turn = t; events = ev; feed = []; breakdown = nil; mode = .trace; selection = []; armedSource = nil; warning = nil; toast = nil
        for e in ev { describe(e) }
        secondsLeft = t.config.rules.match.timerSeconds
        let openings = ev.filter { if case .opening = $0 { true } else { false } }
        guard animate, playsOpening, !openings.isEmpty || fillOnly else {
            let won = openings.map(bonusLine).filter { !$0.isEmpty }
            if !won.isEmpty { show(won.joined(separator: " · ")) }
            startTimer(); return
        }
        // r24: the hand and crib are counted over the empty board before the grid deals in.
        turnGen += 1
        let gen = turnGen
        busy = true; gridHidden = true
        stepsShown = t.state.steps - openings.reduce(0) { if case .opening(_, _, _, _, _, _, let p, _) = $1 { $0 + p } else { $0 } }
        var tray = t.state.tray
        for e in openings { if case .opening(_, _, _, _, _, _, _, let b) = e { for k in b { tray[k, default: 0] -= 1 } } }
        trayShown = tray
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Motion.ms(fx.waits.board.settle)))
            for e in (self.fillOnly ? [] : openings) {
                guard self.turnGen == gen else { return }
                guard case .opening(_, _, _, _, _, _, let points, let bonus) = e else { continue }
                if self.settings.breakdown {
                    await self.playOpening(e, cells: t.state.cells)
                    withAnimation(fx.motions.breakdown.tally.animation()) { self.playback.reset() }
                } else {
                    self.show(self.openingLine(e))
                    try? await Task.sleep(for: .milliseconds(Motion.ms(fx.waits.board.pop)))
                }
                self.stepsShown = (self.stepsShown ?? 0) + points
                withAnimation(fx.motions.board.stepsBump.animation()) { self.playback.bump = true }
                try? await Task.sleep(for: .milliseconds(Motion.ms(fx.waits.board.settle)))
                withAnimation(fx.motions.board.stepsUnbump.animation()) { self.playback.bump = false }
                // r26: a high count's power jokers land in the tray, one at a time.
                if !bonus.isEmpty {
                    self.show(self.bonusLine(e))
                    for k in bonus {
                        guard self.turnGen == gen else { return }
                        withAnimation(fx.motions.board.stepsBump.animation()) { self.trayShown?[k, default: 0] += 1 }
                        try? await Task.sleep(for: .milliseconds(Motion.ms(fx.waits.board.settle)))
                    }
                    try? await Task.sleep(for: .milliseconds(Motion.ms(fx.waits.board.pop)))
                }
            }
            self.trayShown = nil
            guard self.turnGen == gen else { return }
            // The grid intro: what the grid is for, until Start, on the game's first turn only
            // (the demo and films don't wait).
            if !self.playback.autoContinue, !self.fillOnly, (self.game?.results.isEmpty ?? true) {
                self.hideToast()
                withAnimation(fx.motions.breakdown.tally.animation()) { self.gridIntro = self.intro(t) }
                await withCheckedContinuation { self.introResume = $0 }
                guard self.turnGen == gen else { return }
            }
            // The grid fills in, in the turn's pattern (ui.md › The grid fills).
            let (pattern, groups) = self.fillPlan()
            self.fillPattern = pattern; self.gridShown = []; self.gridHidden = false
            self.drawnPerColumn = [4, 4, 4, 4]
            for group in groups {
                guard self.turnGen == gen else { return }
                withAnimation(fx.fill.card.animation()) { self.gridShown?.formUnion(group) }
                try? await Task.sleep(for: .milliseconds(Motion.ms(pattern.gap)))
            }
            self.stepsShown = nil
            try? await Task.sleep(for: .milliseconds(Motion.ms(fx.fill.card.ms)))
            self.gridShown = nil; self.fillPattern = nil
            try? await Task.sleep(for: .milliseconds(Motion.ms(fx.waits.board.settle)))
            guard self.turnGen == gen else { return }
            self.busy = false
            self.startTimer()
        }
    }

    /// The opening count's line, for the feed and the quick flash: "Hand: 12 steps".
    func openingLine(_ e: MatchEvent) -> String {
        guard case .opening(let what, _, _, _, _, _, let points, _) = e else { return "" }
        return "\(what == "crib" ? "Crib" : "Hand"): \(points) step\(points == 1 ? "" : "s")"
    }

    /// The opening bonus's line (r26): "Hand bonus: +2 power jokers (bomb, reach)".
    func bonusLine(_ e: MatchEvent) -> String {
        guard case .opening(let what, _, _, _, _, _, _, let bonus) = e, !bonus.isEmpty else { return "" }
        return "\(what == "crib" ? "Crib" : "Hand") bonus: +\(bonus.count) power joker\(bonus.count == 1 ? "" : "s") (\(bonus.joined(separator: ", ")))"
    }

    /// Sends an action to the engine, stamped with the game time, and hands the step to the recorder.
    /// A step that starts the maze (the grid turn's last) leaves its maze events for the maze scene.
    func act(_ action: CribMazeGame.Action, by player: PlayerID? = 0) -> Step<CribMazeGame>? {
        guard var r = run else { return nil }
        let d = gameTime
        let ms = Int(d.components.seconds) * 1000 + Int(d.components.attoseconds / 1_000_000_000_000_000)
        let mazeBefore = r.state.maze
        do {
            let step = try r.send(action, by: player, clockMs: ms)
            run = r
            for e in step.events {
                switch e {
                case .botTurn: botResults.append(e)
                case .handPlays(let seat, let plays, _): handPlays[seat] = plays
                default: break
                }
            }
            if case .maze = action { game = r.state.game } else if let before = mazeBefore {
                let ev = step.events.compactMap(\.mazeEvent)
                if !ev.isEmpty { mazeScene.pending = (before, ev) }
            }
            recorder?.record(step)
            if let result = r.result { recorder?.ended(result) }
            savedRecord = recorder?.url
            return step
        } catch {
            show("\(error)")
            return nil
        }
    }

    // MARK: Input

    /// One move by a bot, through the same path as the player's (used by the demo).
    func botMove(_ id: String = "medium") {
        guard !busy, warning == nil, info == nil, let t = turn, !t.state.over, let c = config, let bot = MatchBot(config: c, id: id) else { return }
        send(bot.choose(t, dice: &botDice))
    }

    func send(_ action: MatchAction) {
        guard !busy, let old = turn, !old.state.over else { return }
        // The timer, a reach running out and a stuck board are the session's, not the player's.
        let player: PlayerID? = switch action { case .timeUp, .reachOver, .endTurn: nil; default: 0 }
        guard let step = act(.match(action), by: player), let t = run?.state.turn else { return }
        let ev = step.events.compactMap(\.matchEvent)
        events += ev
        for e in ev { if case .key(let id?, _, _, _, _, _) = e { keyReaches.insert(id) } }
        // What pops first: the scored set, or the cards a bomb hits.
        var hit: Set<Pos> = [], bomb = false
        for e in ev {
            if case .score(let ps, _, _, _, _, _, _, _, _, _, _, _) = e { hit = Set(ps.compactMap(Board.parse)) }
            if case .bomb(_, _, let cleared, _) = e {
                let ids = Set(cleared.map(\.id)); bomb = true
                hit = Set((0..<Board.count).filter { old.state.cells[$0].map { ids.contains($0.id) } ?? false })
            }
            if case .burn(let target, _, _, _) = e, let p = Board.parse(target) { hit = [p]; bomb = true }
        }
        guard animate, !hit.isEmpty else { commit(t, ev); return }
        if !bomb, settings.breakdown, let score = ev.first(where: { if case .score = $0 { return true }; return false }) {
            busy = true; selection = []
            Task { [weak self] in
                guard let self else { return }
                await self.playBreakdown(score, before: old.state)
                withAnimation(fx.motions.breakdown.tally.animation()) { self.playback.reset() }
                self.commit(t, ev)
                withAnimation(fx.motions.board.stepsBump.animation()) { self.playback.bump = true }
                try? await Task.sleep(for: .milliseconds(Motion.ms(fx.waits.board.settle)))
                withAnimation(fx.motions.board.stepsUnbump.animation()) { self.playback.bump = false }
                self.busy = false
            }
            return
        }
        busy = true; flash = hit; flashIsBomb = bomb
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Motion.ms(bomb ? fx.waits.board.bombPop : fx.waits.board.pop)))
            guard let self else { return }
            self.flash = []
            self.commit(t, ev)
            try? await Task.sleep(for: .milliseconds(Motion.ms(fx.waits.board.settle)))
            self.busy = false
        }
    }

    /// Shows the move's result: cards clear, fall and drop in, animated.
    private func commit(_ t: MatchTurn, _ ev: [MatchEvent]) {
        var drawn = [Int](repeating: 0, count: 4)
        for e in ev { if case .boardChanged(_, _, let d) = e { for x in d { if let p = Board.parse(x.cell), Board.isGrid(p) { drawn[p % 4] += 1 } } } }
        drawnPerColumn = drawn
        if animate { withAnimation(fx.motions.board.change.animation()) { turn = t } } else { turn = t }
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
                try? await Task.sleep(for: .milliseconds(Motion.ms(timing.ending)))
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
        case .burn:
            if let p = ps.first, Board.isGrid(p), turn?.state.cells[p]?.isPlaying == true { mode = .trace; send(.burn(target: p, source: pendingSource)) }
            else { show("Tap a playing card on the grid to burn it"); return }
        }
        pendingSource = nil; armedSource = nil
    }

    private var pendingSource: Pos? { get { armedSource } set { armedSource = newValue } }
    /// Tapping a special joker on the board arms it. A reach or key joker needs no target, so it's used at once.
    func arm(_ kind: String, from source: Pos? = nil) {
        if kind == "reach" { selection = []; send(.reach(source: source)); return }
        if kind == "key" { selection = []; send(.key(source: source)); return }
        guard let m = InputMode.arming(kind) else { return }
        if m == .burn, turn?.canBurn == false { show("The deck is as small as it gets: \(turn?.state.deckSize ?? 0) cards"); return }
        pendingSource = source
        mode = m
        show(["swapper": "Trace a straight line to reverse it", "bomb": "Tap a grid card to blast it",
              "burn": "Tap a grid card to burn it out of the deck"][kind] ?? "")
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
        if mode == .burn { return "Burn armed: tap a grid card to take it out of the deck for the game. Tap the burn again to cancel." }
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
    /// Reaches that came from a timed key (r28), so the countdown shows on the key card instead.
    private var keyReaches: Set<Int> = []
    /// The share of time left on the reach or timed key that ends first, for its tray card; nil with none in effect.
    func countdown(_ kind: String) -> Double? {
        guard kind == "reach" || kind == "key" else { return nil }
        return reachLeft.filter { keyReaches.contains($0.key) == (kind == "key") }.values
            .min { $0.left < $1.left }.map { Double(max(0, $0.left)) / Double(max(1, $0.total)) }
    }
    /// Hand size from keys that last the game, for the card counter.
    var keyCards: Int { turn?.state.keyCards ?? 0 }
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

    func hideToast() { toastTask?.cancel(); toast = nil }

    func show(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(fx.waits.toast)))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    private func describe(_ e: MatchEvent) {
        switch e {
        case .traceRejected(_, let reason):
            let why = ["size": "Sets are 2 to \(pickLimit) cards", "special": "A special joker can't be in a set", "no_grid_card": "Every set needs a grid card", "edge_cards": "A set can use only one hand or crib card",
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
        case .burn(_, let card, let size, _):
            line("Burned \(faces([card])): out of the deck for the game (\(size) cards)")
            show("Burned \(faces([card])) for the game")
        case .stockOut(let reason, _): line((reason == "stock_empty" ? "Stock empty" : "Card budget used") + ": play out the board")
        case .reach(_, let cards, let seconds, let limit, _):
            line("Reach: hand size +\(cards) for \(seconds) s (now \(limit))")
            show("Reach: hand size +\(cards) for \(seconds) s")
        case .key(_, let cards, let lasts, let seconds, let limit, _):
            let how = lasts == "game" ? "for the rest of the game" : "for \(seconds ?? 0) s"
            line("Key: hand size +\(cards) \(how) (now \(limit))", prize: lasts == "game")
            show("Key: hand size +\(cards) \(how)")
        case .reachOver(let id, let limit): line((keyReaches.contains(id) ? "Key" : "Reach") + " over: hand size back to \(limit)")
        case .noSetsLeft(_, let tray):
            show(tray.values.contains { $0 > 0 } ? "No sets score: use a power joker" : "No sets score")
        case .opening(_, _, let cards, let combos, _, _, _, _):
            let what = combos.isEmpty ? "nothing to count" : combos.map { Self.comboName(kind: $0.kind, size: $0.size, multiplier: $0.multiplier) }.joined(separator: " + ")
            line("\(openingLine(e))  \(faces(cards))  \(what)")
            if case .opening(_, _, _, _, _, _, _, let b) = e, !b.isEmpty { line(bonusLine(e), prize: true) }
        case .boardCleared(_, let amount): line("Board cleared! +\(amount) steps", prize: true)
        case .prizeWon(let tier, let best, _, let special): line("Prize: \(tier) (best set \(best)), wins a \(special)", prize: true)
        case .turnEnd(let reason, let totals):
            let why = ["player": "You ended the turn", "timer": "Time's up", "board_cleared": "Board cleared"][reason] ?? reason
            line("\(why): \(totals.steps) steps")
        default: break
        }
    }

    // MARK: Game end

    private func finish() {
        timerTask?.cancel()
        // The engine has finished the hand: the turn's made and burned cards are in the game's deck,
        // its power jokers and prize carry on. The record was written as the game was played.
        game = run?.state.game
    }
}
