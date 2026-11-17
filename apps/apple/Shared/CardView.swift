// Cards drawn from design/cards/*.svg (CardArt), in their 50 × 70 unit box.
import CardKit
import SwiftUI

private let unitW: CGFloat = 50

extension Suit {
    /// cards.js SUITS: four colours, each 4.5:1 on the face.
    var colour: Color { Theme.suits[rawValue] }
    /// The glyph with the text-style selector, so it never draws as an emoji.
    var textGlyph: String { glyph + "\u{FE0E}" }
}

/// A card drawn from its art file in design/cards/ (CardArt), with the file's text slots and the
/// face's rank and suit drawn here.
struct CardFace: View {
    let card: Card
    var width: CGFloat = Theme.cardW

    /// The art file for this card: the joker or extra card's own, or the plain frame.
    private var artName: String {
        switch card.kind {
        case .special(let kind): "joker-" + (kind == "swapper" ? "swap" : kind)
        case .extra(let kind): "extra-" + kind
        default: "frame"
        }
    }

    var body: some View {
        let u = width / unitW
        let art = CardArt.named(artName) ?? CardArt.named("frame") ?? CardArt()
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in art.draw(&ctx, size: size) }
            ForEach(Array(art.texts.enumerated()), id: \.offset) { _, t in
                Text(t.text).font(Theme.font(t.size * u, .bold)).tracking(t.tracking * u).foregroundStyle(t.colour)
                    .fixedSize()
                    .rotationEffect(.degrees(t.turned ? 180 : 0))
                    .position(x: t.centre.x * u, y: t.centre.y * u)
            }
            switch card.kind {
            case .standard, .made: front(u)
            default: EmptyView()
            }
        }
        .frame(width: width, height: width * 1.4)
    }

    @ViewBuilder private func front(_ u: CGFloat) -> some View {
        let fill = card.suit?.colour ?? Theme.ink
        let ten = card.rank == 10
        let rank = Text(Card.rankText(card.rank)).font(Theme.font((ten ? 14 : 16) * u, .bold)).tracking(ten ? -1.2 * u : 0).foregroundStyle(fill)
        rank.position(x: 9 * u, y: 10.5 * u)
        rank.rotationEffect(.degrees(180)).position(x: 41 * u, y: 59.5 * u)
        Text(card.suit?.textGlyph ?? "").font(.system(size: 34 * u)).foregroundStyle(fill).position(x: 25 * u, y: 35 * u)
    }
}

/// The crosshatch back, from design/cards/back.svg, for the stock pile.
struct CardBack: View {
    var width: CGFloat
    var body: some View {
        let art = CardArt.named("back") ?? CardArt()
        Canvas { ctx, size in art.draw(&ctx, size: size) }
            .frame(width: width, height: width * 1.4)
    }
}
