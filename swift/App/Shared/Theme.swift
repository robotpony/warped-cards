import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// The table in the neon palette (design/neon/palette.json, decided 2026-11-14) with the
/// original card faces from design/cards/cards.js, which read far better than neon cards.
/// Sizes follow the match turn mock (match-turn.html).
enum Theme {
    // Page and table (neon palette). The names keep the felt look's roles: felt is the table, feltText the text on it.
    static let page = Color(hex: 0x05070F)          // around the phone
    static let felt = Color(hex: 0x0A0E1F)          // neon bg
    static let feltText = Color(hex: 0xDDE6FF)      // neon text
    static let panel = Color(hex: 0x121A33)         // neon panel: the edge background
    static let rim = Color(hex: 0x2E3A66)
    static let cyan = Color(hex: 0x3CF2FF)
    static let magenta = Color(hex: 0xFF4FD8)
    static let violet = Color(hex: 0xC77DFF)       // neon joker.special
    static let overlay = Color(hex: 0x0A0E1F, opacity: 0.95)
    static let gold = Color(hex: 0xFFD447)
    static let power = Color(hex: 0x3CF2FF)
    static let bonus = Color(hex: 0xC9A0FF)
    static let ink = Color(hex: 0x2B2A26)
    // Cards (cards.js FACE, SUITS, JOKER)
    static let face = Color(hex: 0xFDFCF8)
    static let rule = Color(hex: 0xD6D0C4)
    static let soft = Color(hex: 0x7C6C48)
    static let joker = Color(hex: 0x6A1B9A)
    static let red = Color(hex: 0xE00000)

    // Sizes: the mock's, a 64 pt card (k scales them all).
    static let k: CGFloat = 1
    static let cardW: CGFloat = 64 * k
    static let cardH: CGFloat = cardW * 1.4
    static let gap: CGFloat = 5 * k
    static let edgeGap: CGFloat = 12 * k
    static let cardRadius: CGFloat = 5 * k
    /// The edge background's margin around the hand, crib and starter: at least 2 pt past the
    /// cards' 2 pt rings (and a lifted, selected card) on the inner sides, and past the starter's tilt on the outer ones.
    static let edgePad: CGFloat = 6
    static let edgePadOuter: CGFloat = 9

    /// The mock's face is Saira Semi Condensed; until it's bundled, the system's condensed width stands in.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { a in
            let hex = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}
