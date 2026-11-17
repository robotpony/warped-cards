import SwiftUI
import CoreText

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// The neon palette's colours (design/neon/palette.json, decided 2026-11-14), read from the copy
/// bundled into the app, so the app, the mocks and any port share one set of values. A colour the
/// file lacks falls back to the value it had when this was written.
enum Palette {
    /// palette.json › colours, flattened to paths: "cyan", "joker.special", "tokens.0".
    static let colours: [String: String] = {
        guard let url = Bundle.main.url(forResource: "palette", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        func walk(_ node: Any?, _ path: String) {
            if let text = node as? String { out[path] = text }
            if let map = node as? [String: Any] { for (k, v) in map { walk(v, path.isEmpty ? k : "\(path).\(k)") } }
            if let list = node as? [Any] { for (i, v) in list.enumerated() { walk(v, "\(path).\(i)") } }
        }
        walk(json["colours"], "")
        return out
    }()

    /// A colour by its path in palette.json › colours ("cyan", "joker.special").
    static func colour(_ path: String, _ fallback: UInt32, opacity: Double = 1) -> Color {
        guard let text = colours[path], text.hasPrefix("#"), let hex = UInt32(text.dropFirst(), radix: 16) else { return Color(hex: fallback, opacity: opacity) }
        return Color(hex: hex, opacity: opacity)
    }
}

/// The table in the neon palette with the original card faces from design/cards/cards.js, which
/// read far better than neon cards. Sizes follow the match turn mock (match-turn.html).
enum Theme {
    // Page and table (neon palette). The names keep the felt look's roles: felt is the table, feltText the text on it.
    static let page = Palette.colour("page", 0x05070F)   // around the phone
    static let felt = Palette.colour("bg", 0x0A0E1F)
    static let feltText = Palette.colour("text", 0xDDE6FF)
    static let panel = Palette.colour("panel", 0x121A33)   // the edge background
    static let rim = Palette.colour("rim", 0x2E3A66)
    static let cyan = Palette.colour("cyan", 0x3CF2FF)
    static let magenta = Palette.colour("magenta", 0xFF4FD8)
    static let violet = Palette.colour("joker.special", 0xC77DFF)
    static let overlay = Palette.colour("bg", 0x0A0E1F, opacity: 0.95)
    static let gold = Palette.colour("gold", 0xFFD447)
    static let power = Palette.colour("cyan", 0x3CF2FF)
    static let ink = Palette.colour("ink", 0x2B2A26)
    static let paper = Palette.colour("paper", 0xFFFDF7)   // the left-over warning, the banner's suit chip
    static let bezel = Palette.colour("bezel", 0x111111)
    static let starterBed = Palette.colour("starterBed", 0x3A4A80)
    // The original cards (palette.json › colours.card, from cards.js)
    static let face = Palette.colour("card.face", 0xFDFCF8)
    static let rule = Palette.colour("card.rule", 0xD6D0C4)
    static let soft = Palette.colour("card.soft", 0x7C6C48)
    static let joker = Palette.colour("card.joker", 0x6A1B9A)
    static let red = Palette.colour("card.red", 0xE00000)
    static let flame = Palette.colour("card.flame", 0xF2B705)
    static let suits = [("S", 0x000000), ("H", 0xE00000), ("D", 0x0070E0), ("C", 0x00843D)].map { Palette.colour("card.suit.\($0.0)", UInt32($0.1)) }
    static let stack = [Palette.colour("card.stack.0", 0xA99E86), Palette.colour("card.stack.1", 0xCFC6B3)]
    // The turn clock, and cards left over in a score
    static let clockGreen = Palette.colour("clock.green", 0x39E07A)
    static let clockOrange = Palette.colour("clock.orange", 0xFF9F1C)
    static let clockRed = Palette.colour("clock.red", 0xFF4D4D)
    static let leftOver = Palette.colour("leftOver.ring", 0xFF5A5A)
    static let leftOverText = Palette.colour("leftOver.text", 0xFF7A7A)
    static let leftOverNames = Palette.colour("leftOver.names", 0xC00000)

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

    /// Whether the UI face is Saira Semi Condensed (design/fonts/, bundled into both apps). Crib Maze
    /// uses it; the beta keeps the system font at its condensed width unless launched with `--saira`
    /// (Bruce, 2026-11-16: try it in the release app, Crib RPG, first). ui.md › Type.
    static let saira: Bool = {
        guard !Edition.isBeta || CommandLine.arguments.contains("--saira") else { return false }
        guard let dir = Bundle.main.url(forResource: "saira-semi-condensed", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return false }
        for f in files where f.pathExtension == "ttf" { CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) }
        return true
    }()

    static func font(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        guard saira else { return .system(size: size, weight: weight).width(.condensed) }
        // By file, since the family name doesn't resolve weights. The four weights design/fonts/ has.
        let face = switch weight {
        case .bold, .heavy, .black: "Bold"
        case .semibold: "SemiBold"
        case .medium: "Medium"
        default: "Regular"
        }
        return .custom("SairaSemiCondensed-" + face, fixedSize: size)
    }

    /// Text in the UI face. With Saira, which has no suit glyphs or ★, those are drawn from
    /// shapes.json inside the text, in its colour (ui.md › Type).
    static func text(_ s: String, _ size: CGFloat) -> Text {
        guard saira else { return Text(s) }
        let marks = Set("♠♥♦♣★".unicodeScalars)
        var out = Text(""), run = ""
        for ch in s {
            if let first = ch.unicodeScalars.first, marks.contains(first) {
                let mark = Text(SuitShapes.image(Character(first), size: size * 0.8)).baselineOffset(-size * 0.06)
                out = Text("\(out)\(Text(verbatim: run))\(mark)")
                run = ""
            } else { run.append(ch) }
        }
        return Text("\(out)\(Text(verbatim: run))")
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
