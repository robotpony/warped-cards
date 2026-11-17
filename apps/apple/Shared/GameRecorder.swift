// Where a game's steps go besides the screen (ARCHITECTURE.md › GameRecord › Interface). The beta
// writes them to a GameRecord file (Beta/Recording.swift); the release app has no recorder and
// doesn't link GameRecord.
import CribMaze
import Foundation
import GameKit

@MainActor protocol GameRecorder: AnyObject {
    /// The record's file, once there is one.
    var url: URL? { get }
    func started(_ run: GameRun<CribMazeGame>)
    func record(_ step: Step<CribMazeGame>)
    /// App behaviour that isn't an action (the deal's hint), kept beside the steps.
    func note<T: Encodable>(_ name: String, _ data: T)
    func ended(_ result: CribMazeGame.Result)
}
