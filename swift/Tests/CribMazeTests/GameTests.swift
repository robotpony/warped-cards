import CardKit
import GameKit
import Testing
@testable import CribMaze
import CribMazeBots

/// Match rules r23: burn jokers, and a game of turns whose deck lasts the game.
@Suite struct BurnTests {
    @Test func burnTakesACardOutOfTheDeck() throws {
        let c = try loadConfig()
        var (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: 4))
        let card = t.state.cells[5]!
        let ev = try t.apply(.burn(target: 5, source: nil))
        guard case .burn(let target, let ref, let size, let source) = ev.first else { Issue.record("burn event"); return }
        #expect(target == "g11" && ref.id == card.id && size == 51 && source == "tray")
        #expect(t.state.burned == [card] && t.state.deckSize == 51 && t.state.tray["burn"] == 0 && t.state.totals.burns == 1)
        #expect(t.state.cells[5]?.id != card.id)   // the column fell and refilled
        #expect(throws: IllegalAction.self) { try t.apply(.burn(target: 6, source: nil)) }   // none left
    }

    @Test func burnNeedsAGridPlayingCard() throws {
        let c = try loadConfig()
        var (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: 4))
        #expect(throws: IllegalAction.self) { try t.apply(.burn(target: 16, source: nil)) }   // a hand card
        #expect(t.state.tray["burn"] == 1)
    }

    @Test func burnStopsAtTheFloor() throws {
        var c = try loadConfig()
        c.rules.deck = .init(shared: true, minSize: 52)
        var (t, _) = MatchTurn.start(config: c, setup: TurnSetup(seed: 4))
        #expect(!t.canBurn)
        #expect(throws: IllegalAction.self) { try t.apply(.burn(target: 5, source: nil)) }
        #expect(t.state.tray["burn"] == 1)
    }
}

@Suite struct GameTests {
    /// Plays the game's turn with a bot, with a burn on the first grid card if one is in the tray.
    func play(_ g: inout MatchGame, _ c: Config, burn: Bool = false) throws -> MatchTurn {
        let dealt = g.deal()
        let keep = Deal.classicKeep(dealt.player), bot = Deal.classicKeep(dealt.bot)
        var (t, ev) = MatchTurn.start(config: c, setup: g.setup(dealt: dealt, thrown: keep.thrown, botThrown: bot.thrown, warned: true))
        if burn, let p = Board.grid.first(where: { t.state.cells[$0]?.isPlaying == true }) { ev += try t.apply(.burn(target: p, source: nil)) }
        let b = MatchBot(config: c, id: "medium")!
        while !t.state.over {
            var d = t.dice
            let a = b.choose(t, dice: &d)
            t.dice = d
            ev += try t.apply(a)
        }
        g.finish(t, events: ev)
        return t
    }

    @Test func aOneTurnGamePlaysLikeAStandaloneTurn() throws {
        let c = try loadConfig()
        let g = MatchGame(config: c, seed: 9)
        #expect(g.turnSeed == 9 && g.dealer && g.turns == 3)
        #expect(g.deal() == Deal.deal(seed: 9))
        let (a, ea) = MatchTurn.start(config: c, setup: g.setup())
        let (b, eb) = MatchTurn.start(config: c, setup: TurnSetup(seed: 9))
        #expect(json(ea) == json(eb) && a.state == b.state)
    }

    @Test func theDeckLastsTheGame() throws {
        let c = try loadConfig()
        var g = MatchGame(config: c, seed: 3)
        var made = 0, burned: [Card] = []
        while !g.over {
            let t = try play(&g, c, burn: g.turn == 1)
            made += t.state.made.count; burned += t.state.burned
        }
        #expect(g.results.count == 3 && g.results.map(\.dealer) == [true, false, true])
        #expect(g.deck.count == 52 + made - burned.count && g.deck.made.count <= made)
        #expect(g.deck.burned == burned && burned.count == 1)
        let ids = Set(g.deck.cards.map(\.id))
        #expect(ids.count == g.deck.count && burned.allSatisfy { !ids.contains($0.id) })
        // Made card IDs never repeat across turns.
        let madeIDs = g.results.flatMap(\.made).map(\.id)
        #expect(Set(madeIDs).count == madeIDs.count)
    }

    @Test func madeCardsCanBeDealt() throws {
        let c = try loadConfig()
        var g = MatchGame(config: c, seed: 3)
        while g.deck.made.isEmpty && !g.over { _ = try play(&g, c) }
        try #require(!g.deck.made.isEmpty)
        // Over many deals from this deck, made cards turn up in hands and the stock.
        var seen = false
        for s in 0..<200 {
            let d = Deal.deal(seed: UInt64(s), deck: g.deck.cards)
            if (d.player + d.bot + [d.starter]).contains(where: { $0.kind == .made }) { seen = true; break }
        }
        #expect(seen)
    }

    @Test func powerJokersCarryOverWithThePrize() throws {
        let c = try loadConfig()
        var g = MatchGame(config: c, seed: 5)
        let t = try play(&g, c)
        var want = t.state.tray
        if let p = g.results[0].prize { want[p, default: 0] += 1 }
        #expect(g.tray == want)
        #expect(g.setup().tray == want)
    }

    @Test func ownDecksKeepTheBotsDeckStandard() throws {
        var c = try loadConfig()
        c.rules.deck = .init(shared: false, minSize: 40)
        var g = MatchGame(config: c, seed: 7)
        _ = try play(&g, c, burn: true)
        #expect(g.botDeck == .standard && g.deck.count == 51 + g.deck.made.count)
        let d = g.deal()
        let all = d.player + d.bot + [d.starter]
        #expect(Set(all.map(\.id)).count == 13)   // nothing dealt twice
    }

    @Test func gamesAreDeterministic() throws {
        let c = try loadConfig()
        var a = MatchGame(config: c, seed: 11), b = MatchGame(config: c, seed: 11)
        while !a.over { _ = try play(&a, c); _ = try play(&b, c) }
        #expect(a == b)
    }
}
