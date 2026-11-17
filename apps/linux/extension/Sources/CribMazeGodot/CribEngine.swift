// The engine as Godot sees it. Everything crosses as JSON in the engine's own encoding
// (engine.md › Records › Encoding), so the Godot side is written from engine.md, not from Swift types.
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
    @Callable func newGame(seed: Int, botLevel: String) -> String {
        guard let config else { return Self.error("config not loaded") }
        guard seed > 0 else { return Self.error("seed must be above 0") }
        let (r, opening) = GameRun<CribMazeGame>.start(.init(config), seed: UInt64(seed), players: [.human(0), .bot(1, level: botLevel)])
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
