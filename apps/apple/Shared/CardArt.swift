// The card art from design/cards/*.svg (bundled as "cards"), so every build draws one source
// (design/cards/README.md). Reads only the subset those files use: rect, circle and path
// (M L H V C Z, absolute or relative), fill and stroke with their opacities, width, caps, joins
// and dashes, translate, rotate and scale transforms, and a rect clip path. Text isn't drawn
// here: each <text> is a slot the card view draws itself, at its centre.
import Foundation
import SwiftUI

struct CardArt {
    struct Paint { var fill: Color?; var stroke: Color?; var width: CGFloat = 1; var cap: CGLineCap = .butt; var join: CGLineJoin = .miter; var dash: [CGFloat] = [] }
    struct Shape { let path: Path; let paint: Paint; let clip: Path? }
    struct TextSlot { let id: String; let text: String; let centre: CGPoint; let size: CGFloat; let tracking: CGFloat; let colour: Color; let turned: Bool }

    var shapes: [Shape] = []
    var texts: [TextSlot] = []

    /// Draws the shapes into `size` (the files' 50 × 70 unit box). The height is scaled on its own,
    /// since the view's frame is snapped to whole pixels.
    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = size.width / 50
        let scale = CGAffineTransform(scaleX: s, y: size.height / 70)
        for sh in shapes {
            var c = ctx
            if let clip = sh.clip { c.clip(to: clip.applying(scale)) }
            let p = sh.path.applying(scale)
            if let f = sh.paint.fill { c.fill(p, with: .color(f)) }
            if let st = sh.paint.stroke {
                c.stroke(p, with: .color(st), style: StrokeStyle(lineWidth: sh.paint.width * s, lineCap: sh.paint.cap, lineJoin: sh.paint.join, dash: sh.paint.dash.map { $0 * s }))
            }
        }
    }

    // MARK: Loading

    nonisolated(unsafe) private static var cache: [String: CardArt] = [:]

    /// A file from the bundled card art by name ("frame", "joker-swap"), or nil if it isn't there.
    static func named(_ name: String) -> CardArt? {
        if let a = cache[name] { return a }
        guard let url = Bundle.main.url(forResource: "cards", withExtension: nil)?.appendingPathComponent("\(name).svg"),
              let data = try? Data(contentsOf: url) else { return nil }
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        guard parser.parse() else { return nil }
        cache[name] = reader.art
        return reader.art
    }

    private final class Reader: NSObject, XMLParserDelegate {
        var art = CardArt()
        /// Each open element's transform and paint, so groups pass theirs down.
        var stack: [(CGAffineTransform, [String: String], Path?)] = [(.identity, [:], nil)]
        var clips: [String: Path] = [:]
        var clipID: String?
        var text: (attrs: [String: String], transform: CGAffineTransform)?
        var textBuffer = ""

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
            let (parentT, parentPaint, parentClip) = stack.last!
            let t = Self.transform(a["transform"]).concatenating(parentT)
            var paint = parentPaint
            for k in ["fill", "fill-opacity", "stroke", "stroke-opacity", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-dasharray", "opacity"] { if let v = a[k] { paint[k] = v } }
            var clip = parentClip
            if let ref = a["clip-path"], let id = ref.split(separator: "#").last?.dropLast(), let c = clips[String(id)] { clip = c }
            stack.append((t, paint, clip))

            switch name {
            case "clipPath": clipID = a["id"]
            case "text": text = (a, t); textBuffer = ""
            case "rect", "circle", "path":
                guard let shape = Self.path(name, a) else { return }
                let p = shape.applying(t)
                if let id = clipID { clips[id, default: Path()].addPath(p); return }
                art.shapes.append(Shape(path: p, paint: Self.paint(paint), clip: clip))
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { if text != nil { textBuffer += string } }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            let paint = stack.popLast()!.1
            if name == "clipPath" { clipID = nil }
            if name == "text", let (a, t) = text {
                let at = CGPoint(x: Self.num(a["x"]), y: Self.num(a["y"])).applying(t)
                art.texts.append(TextSlot(id: a["id"] ?? "", text: textBuffer.trimmingCharacters(in: .whitespacesAndNewlines), centre: at,
                                          size: Self.num(a["font-size"]), tracking: Self.num(a["letter-spacing"]),
                                          colour: Self.colour(a["fill"] ?? paint["fill"], a["fill-opacity"]) ?? .black,
                                          turned: abs(t.b) < 1e-6 && t.a < 0))
                text = nil
            }
        }

        static func num(_ s: String?) -> CGFloat { s.flatMap { Double($0) }.map { CGFloat($0) } ?? 0 }

        static func colour(_ hex: String?, _ opacity: String?) -> Color? {
            guard let hex, hex.hasPrefix("#"), let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
            return Color(hex: v, opacity: opacity.flatMap(Double.init) ?? 1)
        }

        static func paint(_ p: [String: String]) -> Paint {
            let o = p["opacity"].flatMap(Double.init) ?? 1
            func op(_ k: String) -> String { String((p[k].flatMap(Double.init) ?? 1) * o) }
            var out = Paint(fill: p["fill"] == "none" ? nil : colour(p["fill"] ?? "#000000", op("fill-opacity")),
                            stroke: colour(p["stroke"], op("stroke-opacity")))
            out.width = p["stroke-width"].map { num($0) } ?? 1
            out.cap = ["round": .round, "square": .square][p["stroke-linecap"] ?? ""] ?? .butt
            out.join = ["round": .round, "bevel": .bevel][p["stroke-linejoin"] ?? ""] ?? .miter
            out.dash = (p["stroke-dasharray"] ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0).map { CGFloat($0) } }
            return out
        }

        static func path(_ name: String, _ a: [String: String]) -> Path? {
            switch name {
            case "rect":
                let r = CGRect(x: num(a["x"]), y: num(a["y"]), width: num(a["width"]), height: num(a["height"]))
                let rx = num(a["rx"])
                return rx > 0 ? roundedRect(r, rx) : Path(r)
            case "circle":
                let c = CGPoint(x: num(a["cx"]), y: num(a["cy"])), r = num(a["r"])
                return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            default:
                return a["d"].map(pathData)
            }
        }

        /// A rounded rect as SVG builds it: from (x + rx, y), clockwise, with circular corners, so a
        /// dashed outline starts where every SVG reader starts it.
        static func roundedRect(_ r: CGRect, _ rx: CGFloat) -> Path {
            let k = min(rx, r.width / 2, r.height / 2)
            var p = Path()
            p.move(to: CGPoint(x: r.minX + k, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - k, y: r.minY))
            p.addArc(center: CGPoint(x: r.maxX - k, y: r.minY + k), radius: k, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - k))
            p.addArc(center: CGPoint(x: r.maxX - k, y: r.maxY - k), radius: k, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: r.minX + k, y: r.maxY))
            p.addArc(center: CGPoint(x: r.minX + k, y: r.maxY - k), radius: k, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + k))
            p.addArc(center: CGPoint(x: r.minX + k, y: r.minY + k), radius: k, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.closeSubpath()
            return p
        }

        /// Path data with M, L, H, V, C and Z, absolute or relative.
        static func pathData(_ d: String) -> Path {
            var tokens: [String] = []
            var cur = ""
            for ch in d {
                if ch.isLetter { if !cur.isEmpty { tokens.append(cur) }; tokens.append(String(ch)); cur = "" }
                else if ch == " " || ch == "," { if !cur.isEmpty { tokens.append(cur) }; cur = "" }
                else if ch == "-", !cur.isEmpty, cur.last != "e" { tokens.append(cur); cur = "-" }
                else { cur.append(ch) }
            }
            if !cur.isEmpty { tokens.append(cur) }
            var p = Path(), i = 0, cmd: Character = "M", pt = CGPoint.zero, start = CGPoint.zero
            func n() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
            while i < tokens.count {
                if let c = tokens[i].first, c.isLetter { cmd = c; i += 1; if c == "Z" || c == "z" { p.closeSubpath(); pt = start; continue } }
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
                default: i += 1
                }
            }
            return p
        }

        /// translate(x y), rotate(a [cx cy]) and scale(s [sy]), applied right to left as SVG does.
        static func transform(_ s: String?) -> CGAffineTransform {
            guard let s else { return .identity }
            var t = CGAffineTransform.identity
            let scanner = s.replacingOccurrences(of: ",", with: " ")
            for part in scanner.split(separator: ")") {
                let bits = part.split(separator: "(")
                guard bits.count == 2 else { continue }
                let name = bits[0].trimmingCharacters(in: .whitespaces)
                let v = bits[1].split(separator: " ").compactMap { Double($0).map { CGFloat($0) } }
                var m = CGAffineTransform.identity
                switch name {
                case "translate": m = CGAffineTransform(translationX: v.first ?? 0, y: v.count > 1 ? v[1] : 0)
                case "scale": m = CGAffineTransform(scaleX: v.first ?? 1, y: v.count > 1 ? v[1] : (v.first ?? 1))
                case "rotate":
                    let r = (v.first ?? 0) * .pi / 180
                    if v.count == 3 { m = CGAffineTransform(translationX: -v[1], y: -v[2]).concatenating(CGAffineTransform(rotationAngle: r)).concatenating(CGAffineTransform(translationX: v[1], y: v[2])) }
                    else { m = CGAffineTransform(rotationAngle: r) }
                default: break
                }
                t = m.concatenating(t)
            }
            return t
        }
    }
}
