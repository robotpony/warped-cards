// Card art drawn the way design/cards/cards.js draws it, in its 50 × 70 unit box.
import CardKit
import SwiftUI

private let unitW: CGFloat = 50

extension Suit {
    /// cards.js SUITS: four colours, each 4.5:1 on the face.
    var colour: Color { [Color(hex: 0x000000), Color(hex: 0xE00000), Color(hex: 0x0070E0), Color(hex: 0x00843D)][rawValue] }
    /// The glyph with the text-style selector, so it never draws as an emoji.
    var textGlyph: String { glyph + "\u{FE0E}" }
}

/// A shape given in cards.js units, scaled to the card.
struct UnitShape: Shape {
    let build: @Sendable (inout Path) -> Void
    func path(in rect: CGRect) -> Path {
        var p = Path(); build(&p)
        let s = rect.width / unitW
        return p.applying(CGAffineTransform(scaleX: s, y: s).translatedBy(x: rect.minX / s, y: rect.minY / s))
    }
}

struct CardFace: View {
    let card: Card
    var width: CGFloat = Theme.cardW

    var body: some View {
        let u = width / unitW
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4.5 * u).fill(Theme.face)
            RoundedRectangle(cornerRadius: 4.5 * u).strokeBorder(Theme.rule, lineWidth: 1.2 * u)
            switch card.kind {
            case .standard, .made: front(u)
            case .special(let kind): special(kind, u)
            case .extra(let kind): Text(kind.uppercased()).font(Theme.font(7 * u, .bold)).foregroundStyle(Theme.soft)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    @ViewBuilder private func special(_ kind: String, _ u: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3 * u).strokeBorder(Theme.joker.opacity(0.5), lineWidth: 1 * u).padding(3.5 * u)
        Text("JOKER").font(Theme.font(8 * u, .bold)).tracking(1 * u).foregroundStyle(Theme.joker).position(x: 25 * u, y: 9.5 * u)
        Text(kind == "swapper" ? "SWAP" : kind.uppercased()).font(Theme.font(8 * u, .bold)).tracking(1 * u).foregroundStyle(Theme.joker).position(x: 25 * u, y: 61.5 * u)
        if kind == "swapper" {
            UnitShape { p in
                p.move(to: .init(x: 13, y: 30)); p.addLine(to: .init(x: 35, y: 30)); p.addLine(to: .init(x: 30, y: 25))
                p.move(to: .init(x: 37, y: 42)); p.addLine(to: .init(x: 15, y: 42)); p.addLine(to: .init(x: 20, y: 47))
            }.stroke(Theme.joker, style: StrokeStyle(lineWidth: 3.2 * u, lineCap: .round, lineJoin: .round))
        } else if kind == "reach" {
            // A card, and a dashed extra card with a plus: one more card for a while.
            UnitShape { p in p.addRoundedRect(in: CGRect(x: 10, y: 24, width: 17, height: 24), cornerSize: CGSize(width: 2, height: 2)) }
                .stroke(Theme.joker, lineWidth: 2.4 * u)
            UnitShape { p in p.addRoundedRect(in: CGRect(x: 23, y: 29, width: 17, height: 24), cornerSize: CGSize(width: 2, height: 2)) }
                .fill(Theme.face)
            UnitShape { p in p.addRoundedRect(in: CGRect(x: 23, y: 29, width: 17, height: 24), cornerSize: CGSize(width: 2, height: 2)) }
                .stroke(Theme.joker, style: StrokeStyle(lineWidth: 2 * u, dash: [3 * u, 2 * u]))
            UnitShape { p in
                p.move(to: .init(x: 31.5, y: 35.5)); p.addLine(to: .init(x: 31.5, y: 46.5))
                p.move(to: .init(x: 26, y: 41)); p.addLine(to: .init(x: 37, y: 41))
            }.stroke(Color(hex: 0xE00000), style: StrokeStyle(lineWidth: 2.8 * u, lineCap: .round))
        } else {
            UnitShape { p in p.addEllipse(in: CGRect(x: 12, y: 29, width: 22, height: 22)) }.fill(Theme.ink)
            UnitShape { p in p.addRoundedRect(in: CGRect(x: 27, y: 25, width: 6, height: 5), cornerSize: CGSize(width: 1, height: 1),
                                               transform: CGAffineTransform(translationX: 30, y: 27.5).rotated(by: .pi * 35 / 180).translatedBy(x: -30, y: -27.5)) }.fill(Theme.ink)
            UnitShape { p in p.move(to: .init(x: 32, y: 25)); p.addCurve(to: .init(x: 40, y: 21), control1: .init(x: 34, y: 21), control2: .init(x: 37, y: 20)) }
                .stroke(Theme.soft, lineWidth: 1.4 * u)
            UnitShape { p in
                let pts: [(CGFloat, CGFloat)] = [(41, 17), (42.2, 19.6), (45, 20), (43, 22), (43.5, 24.8), (41, 23.5), (38.5, 24.8), (39, 22), (37, 20), (39.8, 19.6)]
                p.move(to: .init(x: pts[0].0, y: pts[0].1)); for q in pts.dropFirst() { p.addLine(to: .init(x: q.0, y: q.1)) }; p.closeSubpath()
            }.fill(Color(hex: 0xE00000))
            UnitShape { p in p.addEllipse(in: CGRect(x: 16.6, y: 33.6, width: 4.8, height: 4.8)) }.fill(.white.opacity(0.35))
        }
    }
}

/// The crosshatch back (cards.js back()), for the stock pile.
struct CardBack: View {
    var width: CGFloat
    var body: some View {
        let u = width / unitW
        ZStack {
            RoundedRectangle(cornerRadius: 4.5 * u).fill(Theme.face)
            RoundedRectangle(cornerRadius: 4.5 * u).strokeBorder(Theme.rule, lineWidth: 1.2 * u)
            RoundedRectangle(cornerRadius: 2.7 * u).stroke(Theme.rule, lineWidth: 1 * u).frame(width: 41 * u, height: 61 * u)
            Canvas { ctx, size in
                // Two sets of diagonals, 3.4 units apart: the 45° crosshatch.
                var p = Path()
                let step = 3.4 * u * 1.41421356, span = size.width + size.height
                var d: CGFloat = -span
                while d < span {
                    p.move(to: .init(x: d, y: 0)); p.addLine(to: .init(x: d + size.height, y: size.height))
                    p.move(to: .init(x: d + size.height, y: 0)); p.addLine(to: .init(x: d, y: size.height))
                    d += step
                }
                ctx.stroke(p, with: .color(Theme.soft.opacity(0.7)), lineWidth: 0.7 * u)
            }
            .frame(width: 32 * u, height: 52 * u).clipShape(RoundedRectangle(cornerRadius: 1.8 * u))
        }
        .frame(width: width, height: width * 1.4)
    }
}
