// The deal before a match turn (rules.md › Deal and discard), for 2 players: 6 cards each, 2 each
// thrown to the crib, then the starter. The player picks their own throw; a bot keeps its best
// classic hand. The kept hands, the crib and the starter then set up the match turn.
import CardKit
import CribbageKit
import GameKit

public struct Dealt: Sendable, Equatable {
    public let player: [Card]
    public let bot: [Card]
    public let starter: Card
}

public enum Deal {
    /// Deals from the turn's seed (stream `round`, purpose `shuffle`): the player's 6, the bot's 6,
    /// then the starter, cut from the rest. `deck` is the game's deck (r23; a standard deck if
    /// missing). With `botDeck` (each player builds their own), the bot's 6 come from its own deck
    /// instead (purpose `bot_shuffle`), less any card already dealt, and the starter is the 7th card
    /// of the player's deck.
    public static func deal(seed: UInt64, deck given: [Card]? = nil, botDeck: [Card]? = nil) -> Dealt {
        var dice = Dice(seed: seed)
        return deal(dice: &dice, deck: given, botDeck: botDeck)
    }

    /// The same deal, drawn from a game's dice so the record keeps its rolls.
    public static func deal(dice: inout Dice, deck given: [Card]? = nil, botDeck: [Card]? = nil) -> Dealt {
        var deck = given ?? (0..<52).map { Card(standard: $0) }
        dice.shuffle(&deck, stream: "round", purpose: "shuffle")
        guard var own = botDeck else { return Dealt(player: Array(deck[0..<6]), bot: Array(deck[6..<12]), starter: deck[12]) }
        let taken = Set(deck[0..<7].map(\.id))
        own.removeAll { taken.contains($0.id) }
        dice.shuffle(&own, stream: "round", purpose: "bot_shuffle")
        return Dealt(player: Array(deck[0..<6]), bot: Array(own[0..<6]), starter: deck[6])
    }

    /// The best 4 to keep by classic count: the hand's total over every starter the deal leaves
    /// (hand flushes and his nobs count), which ranks keeps as the mean does. Totals are integers,
    /// so every language breaks ties the same way (engine.md › The deal). First found wins a tie.
    /// Returns (keep, throw).
    public static func classicKeep(_ six: [Card], scoring: Scoring = Scoring()) -> (keep: [Card], thrown: [Card]) {
        let ids = Set(six.map(\.id))
        let starters = (0..<52).filter { !ids.contains($0) }.map { Card(standard: $0) }
        var best: (Int, [Card], [Card])?
        for a in 0..<six.count { for b in (a + 1)..<six.count {
            let keep = six.enumerated().filter { $0.offset != a && $0.offset != b }.map(\.element)
            let v = classicTotal(keep, starters: starters, scoring: scoring)
            if best == nil || v > best!.0 { best = (v, keep, [six[a], six[b]]) }
        } }
        return (best!.1, best!.2)
    }

    /// A 4-card hand's mean classic count over these starters, for showing.
    public static func classicValue(_ keep: [Card], starters: [Card], scoring: Scoring = Scoring()) -> Double {
        Double(classicTotal(keep, starters: starters, scoring: scoring)) / Double(starters.count)
    }

    /// A 4-card hand's total classic count over these starters.
    public static func classicTotal(_ keep: [Card], starters: [Card], scoring: Scoring = Scoring()) -> Int {
        var total = 0
        for st in starters {
            let cards = (keep + [st]).map { (rank: $0.rank, suit: $0.suit!) }
            var o = CountOptions(flushMin: 4, handFlush4: true)
            if let j = keep.firstIndex(where: { $0.rank == 11 && $0.suit == st.suit }) { o.nobs = [4, j] }
            total += count(cards, o, scoring: scoring).total
        }
        return total
    }

    /// The match turn's setup from a finished deal: the player's kept 4, the starter, the crib
    /// (the player's and bot's throws; on the grid only when the player deals) and the bot's hand,
    /// which stays out of the stock.
    public static func setup(seed: UInt64, dealer: Bool, dealt: Dealt, thrown: [Card], botThrown: [Card], tray: [String: Int]? = nil, warned: Bool = false, deck: [Card]? = nil) -> TurnSetup {
        let thrownIDs = Set(thrown.map(\.id)), botIDs = Set(botThrown.map(\.id))
        var s = TurnSetup(seed: seed, dealer: dealer, tray: tray, warned: warned,
                          fixedHand: dealt.player.filter { !thrownIDs.contains($0.id) }.map(\.notation),
                          fixedStarter: dealt.starter.notation)
        // The dealer's own throw goes first in the crib, as it lies down the side.
        s.fixedCrib = (dealer ? thrown + botThrown : botThrown + thrown).map(\.notation)
        s.held = dealt.bot.filter { !botIDs.contains($0.id) }.map(\.notation)
        // From a game's deck, the cards themselves: made cards share notation with standard ones.
        if let deck {
            s.deck = deck
            s.dealt = DealtCards(hand: dealt.player.filter { !thrownIDs.contains($0.id) }, crib: dealer ? thrown + botThrown : botThrown + thrown,
                                 held: dealt.bot.filter { !botIDs.contains($0.id) }, starter: dealt.starter)
        }
        return s
    }
}
