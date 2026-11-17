// Counts any game has (ARCHITECTURE.md › Stats): events by type, actions by type, rolls by stream
// and purpose (with their values, to check a chance table lands as weighted), and time between
// actions. Game-specific stats build on records in their own module.
import Foundation
import GameKit

public struct Counts: Codable, Sendable, Equatable {
    public var games = 0, finished = 0, hands = 0, steps = 0, actions = 0
    public var events: [String: Int] = [:]
    public var actionTypes: [String: Int] = [:]
    /// Rolls by "stream/purpose".
    public var rolls: [String: Int] = [:]
    /// Roll values by "stream/purpose", then by value.
    public var rollValues: [String: [Int: Int]] = [:]
    /// Game time between one action and the next, in ms.
    public var gaps = 0, gapTotalMs = 0
    public var gapMinMs: Int?, gapMaxMs: Int?

    public init() {}

    public var gapMeanMs: Double? { gaps == 0 ? nil : Double(gapTotalMs) / Double(gaps) }

    public mutating func add<G: GameRules>(_ record: Record<G>) {
        games += 1
        if record.finished { finished += 1 }
        hands += Set(record.steps.compactMap(\.hand)).count
        var lastAction: Int?
        for s in record.steps {
            steps += 1
            if let a = s.action {
                actions += 1
                actionTypes[Self.typeName(a), default: 0] += 1
                if let l = lastAction {
                    let gap = s.clockMs - l
                    gaps += 1; gapTotalMs += gap
                    gapMinMs = min(gapMinMs ?? gap, gap); gapMaxMs = max(gapMaxMs ?? gap, gap)
                }
                lastAction = s.clockMs
            }
            for e in s.events { events[Self.typeName(e), default: 0] += 1 }
            for r in s.rolls {
                let k = "\(r.stream)/\(r.purpose)"
                rolls[k, default: 0] += 1
                rollValues[k, default: [:]][r.value, default: 0] += 1
            }
        }
    }

    /// An action's or event's type: its JSON key (`{"trace": …}` is a trace), or the value itself
    /// for a bare string.
    public static func typeName<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value), let obj = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else { return "?" }
        if let d = obj as? [String: Any] { return d.keys.sorted().first ?? "?" }
        if let s = obj as? String { return s }
        return "?"
    }
}
