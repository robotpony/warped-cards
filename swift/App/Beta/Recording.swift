// Beta only: each game is written as a GameRecord file, one JSON line per step, under
// Application Support/<Edition.name>/Records/<YYYY-MM-DD>/<HHmmss>-crib-maze.jsonl.
// `cribmaze-sim replay <file>` checks one. Records from before 0.15.0 (one .json file per match
// turn, in the same folder) are left where they are; GameRecord doesn't read them.
import CribMaze
import Foundation
import GameKit
import GameRecord

@MainActor enum Recording {
    static func recorder() -> (any GameRecorder)? { BetaRecorder() }

    /// Versions and context for the header: nothing personal, only a random install ID.
    static var stamp: AppStamp {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return AppStamp(app: info["CFBundleShortVersionString"] as? String ?? "?", build: (info["CFBundleVersion"] as? String).flatMap(Int.init),
                        commit: info["GitCommit"] as? String, platform: "macOS \(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : ""),
                        install: installID)
    }

    /// A random ID made on first launch (ARCHITECTURE.md › File format).
    static var installID: String {
        let key = "recordInstallID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = "r-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    static func folder() throws -> URL {
        let fm = FileManager.default
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let app = support.appendingPathComponent(Edition.name, isDirectory: true)
        // The beta was called Crib Maze Beta until 0.9.1: bring its records along once.
        let old = support.appendingPathComponent("Crib Maze Beta/records", isDirectory: true)
        let dir = app.appendingPathComponent("Records", isDirectory: true)
        if !fm.fileExists(atPath: dir.path), fm.fileExists(atPath: old.path) {
            try fm.createDirectory(at: app, withIntermediateDirectories: true)
            try fm.moveItem(at: old, to: dir)
        }
        return dir
    }
}

/// Holds a game's steps back until the player makes a choice, so a game opened and left (or the
/// one the app starts on launch) leaves no file. From then on every step is written as it happens.
@MainActor final class BetaRecorder: GameRecorder {
    private var header: GameHeader<CribMazeGame>?
    private var held: [(Step<CribMazeGame>, Date)] = []
    private var writer: RecordWriter<CribMazeGame>?
    private var failed = false
    var url: URL? { writer?.url }

    func started(_ run: GameRun<CribMazeGame>) {
        header = GameHeader(run, stamp: Recording.stamp, started: RecordFormat.timestamp(Date()))
    }

    func record(_ step: Step<CribMazeGame>) {
        if let w = writer { w.record(step); return }
        held.append((step, Date()))
        if let a = step.action, case .startHand = a { return }
        if step.action != nil { open() }
    }

    func note<T: Encodable>(_ name: String, _ data: T) { writer?.note(name, data) }

    func ended(_ result: CribMazeGame.Result) { writer?.gameEnded(result) }

    private func open() {
        guard !failed, let h = header, let first = held.first else { return }
        do {
            let w = try RecordWriter<CribMazeGame>(url: RecordWriter<CribMazeGame>.path(in: Recording.folder(), started: first.1), clock: { Date() })
            w.gameStarted(h)
            for (s, at) in held { w.record(s, at: at) }
            held = []
            writer = w
        } catch {
            failed = true
            NSLog("Couldn't start the game record: \(error)")
        }
    }
}
