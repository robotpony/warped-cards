// Hints: small nudges when a player seems stuck. Each hint names a place on screen; the view
// that owns that place asks `session.hinting(_:)` and draws `.hintBlink`. New hints (an idle
// player, a set they keep missing, a joker never used) add a case and a rule in `hints`.
import SwiftUI

enum Hint: Hashable {
    /// No sets are left, but power jokers could open one up.
    case powerJokers
}

extension GameSession {
    /// The hints showing now, worked out from the turn's state.
    var hints: Set<Hint> {
        guard settings.hints, !over, !busy else { return [] }
        var h: Set<Hint> = []
        if graceLeft != nil { h.insert(.powerJokers) }
        return h
    }

    func hinting(_ h: Hint) -> Bool { hints.contains(h) }
}

/// A hint's look: a gold ring that blinks around the place to look at.
struct HintBlink: ViewModifier {
    let on: Bool
    var cornerRadius: CGFloat = 12
    @State private var lit = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if on {
                    RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Theme.gold, lineWidth: 3)
                        .shadow(color: Theme.gold.opacity(0.8), radius: 8)
                        .opacity(lit ? 1 : 0.15)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: on, initial: true) { _, v in
                lit = false
                if v { withAnimation(fx.motions.hint.blink.animation()) { lit = true } }
            }
    }
}

extension View {
    func hintBlink(_ on: Bool, cornerRadius: CGFloat = 12) -> some View { modifier(HintBlink(on: on, cornerRadius: cornerRadius)) }
}
