// The game protocol every game implements (ARCHITECTURE.md › Core protocol).

public typealias PlayerID = Int

/// A step: one action and everything it caused. Records and the presenter consume steps.
public struct Step<Action: Codable & Sendable, Event: Codable & Sendable>: Codable, Sendable {
    public let seq: Int
    public let clockMs: Int
    public let player: PlayerID?
    public let action: Action?
    public let rolls: [Roll]
    public let events: [Event]
    public init(seq: Int, clockMs: Int, player: PlayerID?, action: Action?, rolls: [Roll], events: [Event]) {
        self.seq = seq; self.clockMs = clockMs; self.player = player; self.action = action; self.rolls = rolls; self.events = events
    }
}

/// A rule error: the app and bots must only send legal actions.
public struct IllegalAction: Error, CustomStringConvertible, Sendable {
    public let description: String
    public init(_ description: String) { self.description = description }
}
