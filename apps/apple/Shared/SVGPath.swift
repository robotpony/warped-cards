// SVG path data to a Path: M L H V C A Z, absolute or relative. Used by the card art
// (design/cards/*.svg) and the suit and star shapes (design/neon/shapes.json).
import Foundation
import SwiftUI

enum SVGPath {
    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var cur = ""
        for ch in d {
            if ch.isLetter && ch != "e" { if !cur.isEmpty { tokens.append(cur) }; tokens.append(String(ch)); cur = "" }
            else if ch == " " || ch == "," { if !cur.isEmpty { tokens.append(cur) }; cur = "" }
            else if ch == "-", !cur.isEmpty, cur.last != "e" { tokens.append(cur); cur = "-" }
            else { cur.append(ch) }
        }
        if !cur.isEmpty { tokens.append(cur) }
        var p = Path(), i = 0, cmd: Character = "M", pt = CGPoint.zero, start = CGPoint.zero
        func n() -> CGFloat { defer { i += 1 }; return i < tokens.count ? CGFloat(Double(tokens[i]) ?? 0) : 0 }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter, c != "e" {
                cmd = c; i += 1
                if c == "Z" || c == "z" { p.closeSubpath(); pt = start; continue }
            }
            let rel = cmd.isLowercase
            func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: pt.x + x, y: pt.y + y) : CGPoint(x: x, y: y) }
            switch cmd.uppercased() {
            case "M": pt = at(n(), n()); p.move(to: pt); start = pt; cmd = rel ? "l" : "L"
            case "L": pt = at(n(), n()); p.addLine(to: pt)
            case "H": let x = n(); pt = CGPoint(x: rel ? pt.x + x : x, y: pt.y); p.addLine(to: pt)
            case "V": let y = n(); pt = CGPoint(x: pt.x, y: rel ? pt.y + y : y); p.addLine(to: pt)
            case "C":
                let c1 = at(n(), n()), c2 = at(n(), n()), e = at(n(), n())
                p.addCurve(to: e, control1: c1, control2: c2); pt = e
            case "A":
                let rx = n(), ry = n(); _ = n()
                let large = n() != 0, sweep = n() != 0
                let e = at(n(), n())
                arc(&p, from: pt, to: e, r: max(rx, ry), large: large, sweep: sweep); pt = e
            default: i += 1
            }
        }
        return p
    }

    /// A circular arc by SVG's endpoint rules (the shapes use circles only, so rx = ry, no rotation).
    private static func arc(_ p: inout Path, from a: CGPoint, to b: CGPoint, r: CGFloat, large: Bool, sweep: Bool) {
        let dx = (a.x - b.x) / 2, dy = (a.y - b.y) / 2
        let d2 = dx * dx + dy * dy
        guard d2 > 0 else { return }
        let rr = max(r, d2.squareRoot())
        let k = ((rr * rr - d2) / d2).squareRoot() * (large == sweep ? -1 : 1)
        let c = CGPoint(x: (a.x + b.x) / 2 + k * dy, y: (a.y + b.y) / 2 - k * dx)
        let t1 = atan2(a.y - c.y, a.x - c.x), t2 = atan2(b.y - c.y, b.x - c.x)
        // In y-down space, SVG's sweep 1 runs clockwise on screen, which is Path's clockwise: false.
        p.addArc(center: c, radius: rr, startAngle: .radians(t1), endAngle: .radians(t2), clockwise: !sweep)
    }
}

/// The suits and star from design/neon/shapes.json, in its 20 unit box, for builds whose
/// typeface has no suit glyphs (ui.md › Type).
enum SuitShapes {
    static let paths: [Character: Path] = {
        guard let url = Bundle.main.url(forResource: "shapes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shapes = json["shapes"] as? [String: [[String: Any]]] else { return [:] }
        var out: [Character: Path] = [:]
        for (ch, key) in [("♠", "S"), ("♥", "H"), ("♦", "D"), ("♣", "C"), ("★", "star")] as [(Character, String)] {
            var p = Path()
            for part in shapes[key] ?? [] { if let d = part["d"] as? String { p.addPath(SVGPath.parse(d)) } }
            out[ch] = p
        }
        return out
    }()

    /// The shape for a suit glyph or ★, scaled into a `size` square.
    static func path(_ ch: Character, size: CGFloat) -> Path? {
        paths[ch].map { $0.applying(CGAffineTransform(scaleX: size / 20, y: size / 20)) }
    }

    nonisolated(unsafe) private static var images: [String: NSImage] = [:]

    /// A template image of the shape, for drawing inside text in the text's colour.
    static func image(_ ch: Character, size: CGFloat) -> Image {
        let key = "\(ch)\(size)"
        if let img = images[key] { return Image(nsImage: img).renderingMode(.template) }
        let img = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let path = paths[ch], let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.addPath(path.applying(CGAffineTransform(scaleX: size / 20, y: size / 20)).cgPath)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            return true
        }
        img.isTemplate = true
        images[key] = img
        return Image(nsImage: img).renderingMode(.template)
    }
}
