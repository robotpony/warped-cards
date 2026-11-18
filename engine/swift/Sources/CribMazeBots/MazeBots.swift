// Maze bots (maze.md › Bots; engine.md › Maze bots): each seat's choice on the maze, sent by the
// session as an action for that seat, so a record replays without them.
import CribMaze
import GameKit

public struct MazeBot: Sendable {
    public init() {}

    /// The bot's action for the seat whose turn it is.
    public func choose(_ m: Maze) -> MazeAction {
        guard let s = m.turn else { return .mazeEndTurn }
        if m.played { return .mazeEndTurn }
        return .mazeWalk(play: m.tokens[s].plays[0].id, ways: nil)
    }
}
