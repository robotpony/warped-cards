// The engine as Godot sees it. Everything crosses as JSON in the engine's own encoding
// (engine.md › Records › Encoding), so the Godot side is written from engine.md, not from Swift types.
import CardKit
import CribMaze
import Foundation
import GameKit
import GameRecord
import SwiftGodot

@Godot
class CribEngine: RefCounted {
    private var config: Config?
    private var run: GameRun<CribMazeGame>?

    private static func json<T: Encodable>(_ value: T) -> String {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? String(decoding: e.encode(value), as: UTF8.self)) ?? #"{"error":"encoding failed"}"#
    }

    private static func error(_ what: String) -> String { json(["error": what]) }

    /// The versions this build of the engine implements: {"game", "rules", "spec"}.
    @Callable func versions() -> String {
        Self.json(["game": CribMazeGame.gameID, "rules": CribMazeGame.rulesVersion, "spec": "\(CribMazeGame.specVersion)"])
    }

    /// Loads config from the shared folder (cribbage/minigames/config). Answers "" when it loads, else the error.
    @Callable func loadConfig(folder: String) -> String {
        do {
            config = try Config.load(from: URL(fileURLWithPath: folder))
            return ""
        } catch {
            return "\(error)"
        }
    }

    /// Starts a game: the player in seat 0, a bot of `botLevel` in seat 1. Answers the opening step.
    @Callable func newGame(seed: Int, botLevel: String) -> String { newGameWith(seed: seed, botLevel: botLevel, firstDealer: true, sharedDeck: true) }

    /// Starts a game with the settings a game keeps: who deals first and whether the deck is shared.
    @Callable func newGameWith(seed: Int, botLevel: String, firstDealer: Bool, sharedDeck: Bool) -> String {
        guard var config else { return Self.error("config not loaded") }
        guard seed > 0 else { return Self.error("seed must be above 0") }
        config.rules.deck = .init(shared: sharedDeck, minSize: config.rules.deck?.minSize)
        let (r, opening) = GameRun<CribMazeGame>.start(.init(config, firstDealer: firstDealer), seed: UInt64(seed), players: [.human(0), .bot(1, level: botLevel)])
        run = r
        return Self.json(opening)
    }

    /// Sends an action, given as JSON in engine.md's encoding, for a player at a game time in ms.
    /// Answers the step, or {"error"} if the action can't be read or isn't legal now.
    @Callable func send(action: String, player: Int, clockMs: Int) -> String {
        guard var r = run else { return Self.error("no game") }
        let decoded: CribMazeGame.Action
        do {
            decoded = try JSONDecoder().decode(CribMazeGame.Action.self, from: Data(action.utf8))
        } catch {
            return Self.error("can't read the action: \(error)")
        }
        do {
            let step = try r.send(decoded, by: player, clockMs: clockMs)
            run = r
            return Self.json(step)
        } catch {
            return Self.error("\(error)")
        }
    }

    // MARK: What the screen reads between steps
    //
    // Steps carry events; these answer what the screen needs to draw and to explain a trace before
    // it's sent. Their shapes are this bridge's own (apps/linux/README.md › The bridge), with cards
    // as engine.md card references and positions as indexes.

    private static func ref(_ c: Card?) -> CardRef? { c.map(CardRef.init) }

    private struct TurnView: Encodable {
        let dealer: Bool
        let cells: [CardRef?]
        let power: [Int]
        let steps: Int
        let tray: [String: Int]
        let drawable: Int
        let stockOut: Bool, dead: Bool, over: Bool
        let endReason: String?
        let warned: Bool
        let reaches: [ActiveReach]
        let pickLimit: Int
        let starterJoins: Bool
        let canBurn: Bool
        let deckSize: Int
        let timerSeconds: Int
        let made: [CardRef], burned: [CardRef]
        let totals: TurnTotals
    }

    /// The match turn as it stands, or {} with none: cells by position index (null when empty),
    /// power by position index, and what the rules derive (pick limit, whether the starter joins).
    @Callable func turnState() -> String {
        guard let t = run?.state.turn else { return "{}" }
        let s = t.state
        return Self.json(TurnView(dealer: s.dealer, cells: s.cells.map(Self.ref), power: s.power, steps: s.steps, tray: s.tray, drawable: t.drawable,
                                  stockOut: s.stockOut, dead: s.dead, over: s.over, endReason: s.endReason, warned: s.warned, reaches: s.reaches,
                                  pickLimit: t.pickLimit, starterJoins: t.starterJoins, canBurn: t.canBurn, deckSize: s.deckSize,
                                  timerSeconds: t.config.rules.match.timerSeconds,
                                  made: s.made.map(CardRef.init), burned: s.burned.map(CardRef.init), totals: s.totals))
    }

    private struct ComboView: Encodable { let kind: String; let points: Int; let cards: [Int]; let size: Int?; let multiplier: Int? }
    private struct ValueView: Encodable {
        let combos: [ComboView]
        let comboPoints: Int, percent: Int, edgePercent: Int, madePercent: Int, multiplied: Int, leftOver: Int, points: Int
        let suit: String?
        let counted: [Int], inSet: [Int]
        /// Picked positions in no combo (the starter is never left over).
        let leftOverPositions: [Int]
    }
    private struct PreviewView: Encodable { let picked: [Int]; let problem: String?; let value: ValueView? }

    /// What a trace of these positions (a JSON list of indexes, in traced order) would do now,
    /// without changing anything: the picked positions (less a joining starter), the rule it breaks
    /// (engine.md › Trace reasons) and what it would score.
    @Callable func preview(positions: String) -> String {
        guard let t = run?.state.turn else { return Self.error("no match turn") }
        guard let ps = try? JSONDecoder().decode([Int].self, from: Data(positions.utf8)), ps.allSatisfy({ (0..<Board.count).contains($0) }) else {
            return Self.error("positions must be a list of indexes 0 to 24")
        }
        let picked = t.picked(ps)
        let problem = ps.count >= 2 ? t.traceProblem(ps) : nil
        var value: ValueView?
        if ps.allSatisfy({ t.state.cells[$0]?.isPlaying == true }), let v = t.value(of: ps) {
            let used = Set(v.count.combos.flatMap(\.cards))
            value = ValueView(combos: v.count.combos.map { ComboView(kind: $0.kind.rawValue, points: $0.points, cards: $0.cards, size: $0.size, multiplier: $0.multiplier) },
                              comboPoints: v.comboPoints, percent: v.percent, edgePercent: v.edgePercent, madePercent: v.madePercent,
                              multiplied: v.multiplied, leftOver: v.leftOver, points: v.points, suit: v.suit?.letter,
                              counted: v.counted, inSet: v.inSet,
                              leftOverPositions: v.counted.indices.filter { !used.contains($0) && v.counted[$0] != Board.starter }.map { v.counted[$0] })
        }
        return Self.json(PreviewView(picked: picked, problem: problem, value: value))
    }

    /// Whether these positions (a JSON list of indexes) are a straight line a swapper can reverse.
    @Callable func isLine(positions: String) -> Bool {
        guard let ps = try? JSONDecoder().decode([Int].self, from: Data(positions.utf8)) else { return false }
        return MatchTurn.isLine(ps)
    }

    private struct DeckView: Encodable { let count: Int; let made: [CardRef]; let burned: [CardRef] }
    private struct DealView: Encodable { let player: [CardRef]; let bot: [CardRef]; let starter: CardRef }
    private struct GameView: Encodable {
        let stage: String
        let turn: Int, turns: Int
        let dealer: Bool
        let over: Bool
        let steps: Int
        let shared: Bool
        let seed: String
        let deck: DeckView
        let results: [TurnResult]
        let dealing: DealView?
    }

    /// The game around the turn: its stage (ready, dealing, playing, handOver, over), whose deal it
    /// is, the deck that lasts the game and each finished turn's result.
    @Callable func gameState() -> String {
        guard let r = run else { return "{}" }
        let g = r.state.game
        var stage = "ready", dealing: DealView?
        switch r.state.stage {
        case .ready: stage = "ready"
        case .dealing(let d, _, _):
            stage = "dealing"
            dealing = DealView(player: d.player.map(CardRef.init), bot: d.bot.map(CardRef.init), starter: CardRef(d.starter))
        case .playing: stage = "playing"
        case .handOver: stage = "handOver"
        case .over: stage = "over"
        }
        return Self.json(GameView(stage: stage, turn: g.turn, turns: g.turns, dealer: g.dealer, over: g.over, steps: g.steps, shared: g.shared,
                                  seed: String(r.seed), deck: DeckView(count: g.deck.count, made: g.deck.made.map(CardRef.init), burned: g.deck.burned.map(CardRef.init)),
                                  results: g.results, dealing: dealing))
    }

    private struct HintView: Encodable { let principle: String; let line: String; let cards: [CardRef] }

    /// The deal's hint (concept.md › Discard principles): the one principle worth showing for the
    /// player's 6, with its line and the cards it's about, or {} when nothing stands out.
    @Callable func dealHint() -> String {
        guard let r = run, case .dealing(let d, _, _) = r.state.stage, let h = config?.hints?.discard,
              let hit = Principles.best(for: d.player, hints: h) else { return "{}" }
        return Self.json(HintView(principle: hit.principle.rawValue, line: hit.principle.line, cards: hit.cards.map(CardRef.init)))
    }

    /// Replays a record file in verify mode. Answers "ok, N steps" or where it differs.
    @Callable func verifyRecord(path: String) -> String {
        do {
            return Replayer<CribMazeGame>.check(try RecordReader<CribMazeGame>.read(URL(fileURLWithPath: path))).description
        } catch {
            return "read failed: \(error)"
        }
    }
}

#initSwiftExtension(cdecl: "swift_entry_point", types: [CribEngine.self])
