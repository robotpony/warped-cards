// A bot playing a whole game in the player's seat, step by step, as the simulator and the tests run
// it: each deal it keeps its best classic hand, then plays the match turn. A reach ends after
// `reachActions` of its actions (about 20 s at a person's pace), and its dice start again each hand
// from the hand's seed, both as `cribmaze-sim game` has them, so the two play the same games.
import CribMaze
import GameKit

extension MatchBot {
    /// Plays `run` to the end of the game. Every step, the opening one aside, goes to `onStep`.
    /// The game clock moves on `msPerAction` per action. The bot draws from `dice`, its own.
    public func play(_ run: inout GameRun<CribMazeGame>, options: CribMazeGame.HandOptions, dice: inout Dice, msPerAction: Int,
                     reachActions: Int = 5, onStep: (Step<CribMazeGame>) throws -> Void) throws {
        var clock = 0, acted = 0, ends: [Int: Int] = [:]
        func send(_ a: CribMazeGame.Action, by player: PlayerID?) throws {
            clock += msPerAction
            let step = try run.send(a, by: player, clockMs: clock)
            try onStep(step)
            for e in step.events { if case .match(.reach(let id, _, _, _, _)) = e { ends[id] = acted + reachActions } }
        }
        while run.result == nil {
            let s = run.state
            switch s.stage {
            case .ready, .handOver:
                acted = 0; ends = [:]
                dice.reseed(s.game.turnSeed)
                try send(.startHand(options), by: seat)
            case .dealing(let dealt, _, _):
                let thrown = Deal.classicKeep(dealt.player, scoring: s.config.files.rules.scoring).thrown
                try send(.discard(thrown: thrown.map(CardRef.init)), by: seat)
            case .playing(let t):
                acted += 1
                try send(.match(choose(t, dice: &dice)), by: seat)
                for (id, end) in ends.sorted(by: { $0.key < $1.key }) where end <= acted {
                    guard case .playing = run.state.stage else { break }
                    ends[id] = nil
                    try send(.match(.reachOver(id: id)), by: nil)
                }
            case .over: return
            }
        }
    }
}
