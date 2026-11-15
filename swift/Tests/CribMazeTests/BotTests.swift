import Foundation
import Testing
import GameKit
@testable import CribMaze
@testable import CribMazeBots

// configFolder is declared in MatchTurnTests.swift.

/// Plays one bot turn to the end. Returns every action and event, in order.
func playBotTurn(_ config: Config, level: String, seed: UInt64, dealer: Bool, maxActions: Int = 500) throws -> (actions: [MatchAction], events: [MatchEvent], turn: MatchTurn) {
    let bot = try #require(MatchBot(config: config, id: level))
    var (turn, events) = MatchTurn.start(config: config, setup: TurnSetup(seed: seed, dealer: dealer, warned: true))
    var actions: [MatchAction] = []
    while !turn.state.over {
        try #require(actions.count < maxActions, "turn never ended (seed \(seed), \(level))")
        var dice = turn.dice
        let a = bot.choose(turn, dice: &dice)
        turn.dice = dice
        actions.append(a)
        events += try turn.apply(a)
    }
    return (actions, events, turn)
}

/// Kept small for debug builds: the big runs go through cribmaze-sim in release.
@Suite(.serialized) struct BotTests {
    let config = try! Config.load(from: configFolder)

    /// Random seeds, every level, dealer and not: no illegal action, every turn ends once.
    @Test(arguments: ["perfect", "strong", "medium", "weak"])
    func soak(level: String) throws {
        var gen = SplitMix64(seed: fnv1a64("soak." + level))
        let turns = ["perfect": 2, "strong": 3, "medium": 8, "weak": 20][level]!   // a few seconds in debug
        for i in 0..<turns {
            let seed = gen.next()
            let (actions, events, turn) = try playBotTurn(config, level: level, seed: seed, dealer: i % 2 == 0)
            let ends = events.filter { if case .turnEnd = $0 { return true }; return false }
            #expect(ends.count == 1, "seed \(seed): \(ends.count) turn_end events")
            #expect(turn.state.over)
            // Bots never send a trace the rules reject, and never get warned.
            let rejected = events.contains { if case .traceRejected = $0 { return true }; if case .leftoverWarning = $0 { return true }; return false }
            #expect(!rejected, "seed \(seed): a bot trace was rejected or warned")
            // A bot that ends its own turn has nothing left that it found to do.
            if case .endTurn = actions.last {} else { #expect(turn.state.endReason == "board_cleared", "seed \(seed)") }
        }
    }

    /// Same seed, same actions and events; the bot's rolls come only from its own stream.
    @Test(arguments: ["medium", "weak"])
    func determinism(level: String) throws {
        for seed: UInt64 in [1, 42] {
            let a = try playBotTurn(config, level: level, seed: seed, dealer: true)
            let b = try playBotTurn(config, level: level, seed: seed, dealer: true)
            #expect(a.actions == b.actions)
            #expect(a.events == b.events)
            var d = a.turn.dice
            let streams = Set(d.takeRolls().map(\.stream))
            #expect(streams.isSubset(of: ["deal", "reveal", "board", "prize", "bot.0"]))
        }
    }

    /// Another seat draws from its own stream and leaves the turn's dice in step.
    @Test func seatStream() throws {
        let bot = try #require(MatchBot(config: config, id: "medium", seat: 1))
        let (turn, _) = MatchTurn.start(config: config, setup: TurnSetup(seed: 7, warned: true))
        var dice = turn.dice
        _ = dice.takeRolls()
        _ = bot.choose(turn, dice: &dice)
        let rolls = dice.takeRolls()
        #expect(!rolls.isEmpty)
        #expect(rolls.allSatisfy { $0.stream == "bot.1" && $0.purpose == "starts" })
    }

    /// The perfect bot takes the highest-scoring set, and the larger set on a tie.
    @Test func perfectTakesTheBest() throws {
        let bot = try #require(MatchBot(config: config, id: "perfect"))
        var d = Dice(seed: 0)
        for seed: UInt64 in 1...4 {
            let (turn, _) = MatchTurn.start(config: config, setup: TurnSetup(seed: seed, warned: true))
            guard let found = bot.bestSet(turn, dice: &d) else { continue }
            var top = 0
            for s in MatchTurn.sets(maxSize: config.rules.match.maxSet) where turn.traceProblem(s) == nil {
                if let v = turn.value(of: s), !v.count.combos.isEmpty { top = max(top, v.points) }
            }
            #expect(found.points == top, "seed \(seed)")
        }
    }
}
