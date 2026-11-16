// GameRecord: one JSON Lines file per game (ARCHITECTURE.md › GameRecord). The first line is the
// header, then one line per step, notes from the app where it has them, and an end line when the
// game finishes. Generic over GameRules, so another card game can use it unchanged.
//
// GameRecord never reads the clock itself: the writer is handed one, so tests write byte-identical
// records.
import Foundation
import GameKit

public enum RecordFormat {
    /// The record format's version, in every header.
    public static let version = 1

    /// Wall time as ISO 8601 with milliseconds and the local offset: 2026-11-14T19:02:03.120-08:00.
    public static func timestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = timeZone
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    /// Sorted keys, so the same game always writes the same bytes.
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }
}

/// A note from the app, outside the rules (the deal's hint, arming a joker): kept, never replayed.
public struct RecordNote: Sendable {
    /// The step it follows.
    public let after: Int
    public let at: String?
    public let name: String
    /// The whole line, to decode `data` from.
    public let line: Data

    public func data<T: Decodable>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(NoteData<T>.self, from: line).data
    }
}

/// The end line: how the game came out.
public struct RecordEnd<G: GameRules>: Codable, Sendable {
    public let at: String?
    public let clockMs: Int
    public let result: G.Result
}

/// One game's record, as read back.
public struct Record<G: GameRules>: Sendable {
    public let url: URL?
    public let header: GameHeader<G>
    public let format: Int
    public let steps: [Step<G>]
    /// Wall times of the steps, in the same order.
    public let stepTimes: [String?]
    public let notes: [RecordNote]
    public let end: RecordEnd<G>?
    /// The last line was cut short (the app stopped mid-write); everything before it is kept.
    public let truncated: Bool

    public var finished: Bool { end != nil }
}

// MARK: - Lines

struct Kind: Decodable { let kind: String }

struct HeaderLine<G: GameRules>: Codable {
    let format: Int
    let header: GameHeader<G>
    enum Keys: String, CodingKey { case kind, format }
    init(format: Int, header: GameHeader<G>) { self.format = format; self.header = header }
    init(from decoder: Decoder) throws {
        format = try decoder.container(keyedBy: Keys.self).decode(Int.self, forKey: .format)
        header = try GameHeader(from: decoder)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode("header", forKey: .kind)
        try c.encode(format, forKey: .format)
        try header.encode(to: encoder)
    }
}

struct StepLine<G: GameRules>: Codable {
    let at: String?
    let step: Step<G>
    enum Keys: String, CodingKey { case kind, at }
    init(at: String?, step: Step<G>) { self.at = at; self.step = step }
    init(from decoder: Decoder) throws {
        at = try decoder.container(keyedBy: Keys.self).decodeIfPresent(String.self, forKey: .at)
        step = try Step(from: decoder)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode("step", forKey: .kind)
        try c.encodeIfPresent(at, forKey: .at)
        try step.encode(to: encoder)
    }
}

struct NoteLine<T: Encodable>: Encodable {
    var kind = "note"
    let after: Int
    let at: String?
    let name: String
    let data: T
}

struct NoteData<T: Decodable>: Decodable { let data: T }
struct NoteHead: Decodable { let after: Int; let at: String?; let name: String }

struct EndLine<G: GameRules>: Codable {
    var kind = "end"
    let at: String?
    let clockMs: Int
    let result: G.Result
}

// MARK: - Writer

/// Writes a game as it's played, one line per step, each written straight to the file so a crash
/// keeps everything up to the last move.
public final class RecordWriter<G: GameRules>: StepObserver {
    public let url: URL
    public let clock: @Sendable () -> Date
    public let timeZone: TimeZone
    /// The first write that failed, if any; the observer calls can't throw.
    public private(set) var error: Error?
    private let handle: FileHandle
    private var lastSeq = 0, lastClockMs = 0
    private let encoder = RecordFormat.encoder()

    /// Creates the file (and its folder). `clock` gives each line's wall time.
    public init(url: URL, clock: @escaping @Sendable () -> Date, timeZone: TimeZone = .current) throws {
        self.url = url; self.clock = clock; self.timeZone = timeZone
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path]) }
        handle = try FileHandle(forWritingTo: url)
    }

    deinit { try? handle.close() }

    /// The usual place for a record: `<folder>/<YYYY-MM-DD>/<HHmmss>-<game>.jsonl`, in local time.
    public static func path(in folder: URL, started: Date, timeZone: TimeZone = .current) -> URL {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: started)
        let day = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        let time = String(format: "%02d%02d%02d", c.hour!, c.minute!, c.second!)
        var url = folder.appendingPathComponent(day, isDirectory: true).appendingPathComponent("\(time)-\(G.gameID).jsonl")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent(day, isDirectory: true).appendingPathComponent("\(time)-\(G.gameID)-\(n).jsonl"); n += 1
        }
        return url
    }

    public func gameStarted(_ header: GameHeader<G>) { write(HeaderLine(format: RecordFormat.version, header: header)) }

    public func record(_ step: Step<G>) { record(step, at: clock()) }

    /// A step with the wall time it happened at, for an app that holds steps back before writing.
    public func record(_ step: Step<G>, at date: Date) {
        lastSeq = step.seq; lastClockMs = step.clockMs
        write(StepLine(at: stamp(date), step: step))
    }

    /// An app note after the last step: not part of the rules, so replays skip it.
    public func note<T: Encodable>(_ name: String, _ data: T, at date: Date? = nil) {
        write(NoteLine(after: lastSeq, at: stamp(date ?? clock()), name: name, data: data))
    }

    public func gameEnded(_ result: G.Result) { write(EndLine<G>(at: stamp(clock()), clockMs: lastClockMs, result: result)) }

    public func stamp(_ date: Date) -> String { RecordFormat.timestamp(date, timeZone: timeZone) }

    private func write<T: Encodable>(_ line: T) {
        guard error == nil else { return }
        do {
            var data = try encoder.encode(line)
            data.append(0x0A)
            try handle.write(contentsOf: data)
        } catch { self.error = error }
    }
}

// MARK: - Reader

public struct RecordError: Error, CustomStringConvertible, Sendable {
    public let description: String
    public init(_ description: String) { self.description = description }
}

/// Reads records back: one file, or every `.jsonl` file under a folder.
public enum RecordReader<G: GameRules> {
    public static func read(_ url: URL) throws -> Record<G> {
        try read(Data(contentsOf: url), url: url)
    }

    public static func read(_ data: Data, url: URL? = nil) throws -> Record<G> {
        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        guard let first = lines.first else { throw RecordError("empty record") }
        let d = JSONDecoder()
        let head: HeaderLine<G>
        do {
            guard try d.decode(Kind.self, from: first).kind == "header" else { throw RecordError("the first line isn't a header") }
            let kind = try JSONSerialization.jsonObject(with: first) as? [String: Any]
            if let g = kind?["game"] as? String, g != G.gameID { throw RecordError("a \(g) record, not \(G.gameID)") }
            if let f = kind?["format"] as? Int, f > RecordFormat.version { throw RecordError("format \(f) is newer than this reader (\(RecordFormat.version))") }
            head = try d.decode(HeaderLine<G>.self, from: first)
        } catch let e as RecordError { throw e } catch { throw RecordError("header: \(error)") }
        var steps: [Step<G>] = [], times: [String?] = [], notes: [RecordNote] = [], end: RecordEnd<G>?, truncated = false
        for (i, raw) in lines.enumerated().dropFirst() {
            let line = Data(raw)
            do {
                switch try d.decode(Kind.self, from: line).kind {
                case "step":
                    let s = try d.decode(StepLine<G>.self, from: line)
                    steps.append(s.step); times.append(s.at)
                case "note":
                    let n = try d.decode(NoteHead.self, from: line)
                    notes.append(RecordNote(after: n.after, at: n.at, name: n.name, line: line))
                case "end":
                    let e = try d.decode(EndLine<G>.self, from: line)
                    end = RecordEnd(at: e.at, clockMs: e.clockMs, result: e.result)
                default: break   // a kind from a newer writer: skip it
                }
            } catch {
                // A last line cut short by a crash loses only itself.
                if i == lines.count - 1 { truncated = true } else { throw RecordError("line \(i + 1): \(error)") }
            }
        }
        return Record(url: url, header: head.header, format: head.format, steps: steps, stepTimes: times, notes: notes, end: end, truncated: truncated)
    }

    /// Every `.jsonl` record of this game under a folder (or the one file given), in path order.
    /// Files that aren't this game's records, or don't read, come back in `skipped` with why.
    public static func readAll(_ url: URL) -> (records: [Record<G>], skipped: [(url: URL, why: String)]) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return ([], [(url, "not found")]) }
        let files: [URL]
        if isDir.boolValue {
            let all = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
            files = all.filter { $0.pathExtension == "jsonl" }.sorted { $0.path < $1.path }
        } else {
            files = [url]
        }
        var records: [Record<G>] = [], skipped: [(URL, String)] = []
        for f in files {
            do { records.append(try read(f)) } catch { skipped.append((f, "\(error)")) }
        }
        return (records, skipped)
    }
}
