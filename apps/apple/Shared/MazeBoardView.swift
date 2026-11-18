// The neon maze (ui.md › Scene: Maze › The board): walls drawn double, card doors, switches,
// hazards, stars, junction chevrons, the previewed walk, targets and the tokens, through a camera
// that fits every token and eases toward its target. Sizes come from fx.json › maze and
// palette.json › maze, colours from palette.json.
import CardKit
import CribMaze
import SwiftUI

/// The maze's colours, from palette.json (Look).
enum MazeInk {
    static let bg = Theme.felt
    static let wall = Theme.cyan
    static let core = Palette.colour("core", 0xE6FFFF)
    static let outer = Theme.magenta
    static let gold = Theme.gold
    static let door = Palette.colour("door", 0xFF8A3D)
    static let violet = Theme.violet
    static let pink = Theme.magenta
    static func neon(_ suit: String) -> Color { Palette.colour("suit.\(suit)", 0xE8ECFF) }
    static func token(_ seat: Int) -> Color { Palette.colour("tokens.\(seat)", [0xFFD447, 0x34E0A1, 0xB48CFF][min(seat, 2)]) }
}

/// palette.json › maze: the neon art's sizes, as fractions of a cell.
enum MazeSizes {
    static let values: [String: Double] = {
        guard let url = Bundle.main.url(forResource: "palette", withExtension: "json"), let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let m = json["maze"] as? [String: Double] else { return [:] }
        return m
    }()
    static func v(_ k: String, _ fallback: Double) -> Double { values[k] ?? fallback }
    static var glow: Double { v("glow", 2.2) }
    static var token: Double { v("token", 0.25) }
    static var tokenOnStart: Double { v("tokenOnStart", 0.16) }
    static var star: Double { v("star", 0.34) }
    static var startInset: Double { v("startInset", 0.17) }
    static var outerWall: Double { v("outerWall", 0.07) }
    static var wallMin: Double { v("wallMin", 2.2) }
    static var coreRatio: Double { v("coreRatio", 0.35) }
    static var floorInset: Double { v("floorInset", 0.03) }
    static var floorRadius: Double { v("floorRadius", 0.06) }
    static var floorOpacity: Double { v("floorOpacity", 0.07) }
    static var laserLen: Double { v("laserLen", 0.96) }
}

/// The camera: a cell size and the cell it centres on.
struct MazeCamera {
    var cs: Double, x: Double, y: Double
    let side: Double
    /// A cell's centre on screen.
    func point(_ b: MazeBoard, _ c: Int) -> CGPoint { CGPoint(x: (Double(b.x(c)) + 0.5 - x) * cs + side / 2, y: (Double(b.y(c)) + 0.5 - y) * cs + side / 2) }
    /// A passage's middle on screen, and whether its line runs up and down (the cells side by side).
    func middle(_ b: MazeBoard, _ k: Int) -> (CGPoint, Bool) {
        let (a, c) = b.cells(ofKey: k), p = point(b, a), q = point(b, c)
        return (CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2), k % 2 == 0)
    }
    /// The cell under a screen point, and where in it (0 to 1 each way).
    func cell(_ b: MazeBoard, at p: CGPoint) -> (Int, Double, Double)? {
        let wx = (p.x - side / 2) / cs + x, wy = (p.y - side / 2) / cs + y
        let cx = Int(floor(wx)), cy = Int(floor(wy))
        guard cx >= 0, cy >= 0, cx < b.w, cy < b.w else { return nil }
        return (cy * b.w + cx, wx - Double(cx), wy - Double(cy))
    }
}

struct MazeBoardView: View {
    let scene: MazeScene
    let side: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !(scene.moving || scene.hop != nil))) { tl in
            Canvas { ctx, size in
                guard let m = scene.shown else { return }
                let cam = camera(m, now: tl.date)
                MazeArt(scene: scene, m: m, cam: cam, now: tl.date).draw(&ctx, size: size)
            }
        }
        .frame(width: side, height: side)
        .background(MazeInk.bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.rim, lineWidth: 1))
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tap($0.location) })
    }

    // MARK: Camera

    /// Where the camera wants to be (maze.md › The screen › Camera): every token, plus the walk or
    /// the previewed walk, as close as that allows and no closer than `cellsAcross` cells.
    func target(_ m: Maze) -> MazeCamera {
        let b = m.board, c = fx.maze.camera, v = Double(side)
        var fit = m.tokens.indices.compactMap { scene.position($0) }
        if let h = scene.hop { fit += h.cells } else if let pv = scene.preview { fit += pv.walk.path }
        let zoom = v / c.cellsAcross, least = v / Double(b.w)
        var cs = zoom, x: Double, y: Double
        if Set(fit).count > 1 {
            let xs = fit.map { Double(b.x($0)) }, ys = fit.map { Double(b.y($0)) }
            let span = max(xs.max()! - xs.min()!, ys.max()! - ys.min()!)
            cs = max(least, min(zoom, v / (span + c.fitMargin)))
            x = (xs.min()! + xs.max()! + 1) / 2; y = (ys.min()! + ys.max()! + 1) / 2
        } else {
            let f = fit.first ?? b.start
            x = Double(b.x(f)) + 0.5; y = Double(b.y(f)) + 0.5
        }
        func clamp(_ p: Double) -> Double { let h = v / cs / 2; return Double(b.w) <= 2 * h ? Double(b.w) / 2 : min(Double(b.w) - h, max(h, p)) }
        return MazeCamera(cs: cs, x: clamp(x), y: clamp(y), side: v)
    }

    /// The camera eased toward its target since the last frame; at once in snapshots or the first time.
    private func camera(_ m: Maze, now: Date) -> MazeCamera {
        let t = target(m)
        guard let c = scene.cam, !scene.instant else { scene.cam = (t.cs, t.x, t.y, now); return t }
        let dt = max(0, now.timeIntervalSince(c.t) * 1000)
        let k = 1 - exp(-dt / Motion.t(fx.maze.camera.easeMs))
        let cs = exp(log(c.cs) + (log(t.cs) - log(c.cs)) * k)
        let out = MazeCamera(cs: cs, x: c.x + (t.x - c.x) * k, y: c.y + (t.y - c.y) * k, side: t.side)
        scene.cam = (out.cs, out.x, out.y, now)
        return out
    }

    // MARK: Taps

    private func tap(_ p: CGPoint) {
        guard let m = scene.shown, let c = scene.cam else { return }
        let cam = MazeCamera(cs: c.cs, x: c.x, y: c.y, side: Double(side)), b = m.board
        if scene.tip != nil { scene.tip = nil; return }
        let reach = Double(max(fx.maze.targetRange * cam.cs, 14))
        func near(_ q: CGPoint) -> Double { hypot(q.x - p.x, q.y - p.y) }
        if scene.myTurn, let e = scene.engine {
            switch scene.mode {
            case .close:
                let keys = MazeArt.visibleKeys(b, cam).filter { e.canClose(0, key: $0) }
                if let k = keys.min(by: { near(cam.middle(b, $0).0) < near(cam.middle(b, $1).0) }), near(cam.middle(b, k).0) < reach {
                    let (a, z) = b.cells(ofKey: k); scene.close([a, z])
                }
                return
            case .bomb, .burn:
                let cells = e.hazardCells(0)
                let doors = scene.mode == .bomb ? e.bombDoors(0) : []
                let bestCell = cells.min { near(cam.point(b, $0)) < near(cam.point(b, $1)) }
                let bestDoor = doors.min { near(cam.middle(b, $0).0) < near(cam.middle(b, $1).0) }
                let dc = bestCell.map { near(cam.point(b, $0)) } ?? .infinity, dd = bestDoor.map { near(cam.middle(b, $0).0) } ?? .infinity
                if dd < reach && dd <= dc, let k = bestDoor { let (a, z) = b.cells(ofKey: k); scene.bombDoor([a, z]) }
                else if dc < reach, let cell = bestCell { scene.hazardAt(cell) }
                return
            case .flip:
                let ks = b.switches.indices.filter { e.canFlip($0) }
                if let s = ks.min(by: { near(cam.middle(b, b.switches[$0].a).0) < near(cam.middle(b, b.switches[$1].a).0) }), near(cam.middle(b, b.switches[s].a).0) < reach {
                    scene.flip(Maze.letters[s])
                }
                return
            case .swapper, .none: break
            }
            if let pv = scene.preview, e.reachOn(0),
               let j = pv.walk.junctions.min(by: { near(cam.point(b, $0.cell)) < near(cam.point(b, $1.cell)) }), near(cam.point(b, j.cell)) < reach {
                scene.turnJunction(j.cell); return
            }
        }
        guard let (cell, fx0, fy0) = cam.cell(b, at: p) else { return }
        let sides: [(Double, Dir)] = [(fy0, .up), (1 - fx0, .right), (1 - fy0, .down), (fx0, .left)]
        let side = sides.min { $0.0 < $1.0 }!
        scene.tip = scene.explain(cell: cell, side: side.0 < 0.3 ? side.1 : nil)
    }
}

/// One frame of the maze.
@MainActor struct MazeArt {
    let scene: MazeScene
    let m: Maze
    let cam: MazeCamera
    let now: Date

    var b: MazeBoard { m.board }
    var cs: Double { cam.cs }

    static func visibleRange(_ b: MazeBoard, _ cam: MazeCamera) -> (ClosedRange<Int>, ClosedRange<Int>) {
        let h = cam.side / cam.cs / 2
        let x0 = max(0, Int(floor(cam.x - h)) - 1), x1 = min(b.w - 1, Int(ceil(cam.x + h)))
        let y0 = max(0, Int(floor(cam.y - h)) - 1), y1 = min(b.w - 1, Int(ceil(cam.y + h)))
        return (x0...max(x0, x1), y0...max(y0, y1))
    }
    static func visibleCells(_ b: MazeBoard, _ cam: MazeCamera) -> [Int] {
        let (xs, ys) = visibleRange(b, cam)
        return ys.flatMap { y in xs.map { y * b.w + $0 } }
    }
    /// Every passage key inside the view, open, wall or otherwise.
    static func visibleKeys(_ b: MazeBoard, _ cam: MazeCamera) -> [Int] {
        visibleCells(b, cam).flatMap { c -> [Int] in
            var out: [Int] = []
            if b.x(c) < b.w - 1 { out.append(c * 2) }
            if b.y(c) < b.w - 1 { out.append(c * 2 + 1) }
            return out
        }
    }

    /// Glow: the shape blurred under itself.
    func glow(_ ctx: inout GraphicsContext, _ path: Path, _ colour: Color, _ width: Double, dash: [CGFloat] = []) {
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: MazeSizes.glow))
            l.stroke(path, with: .color(colour), style: style)
        }
        ctx.stroke(path, with: .color(colour), style: style)
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(MazeInk.bg))
        let cells = Self.visibleCells(b, cam)
        let rect = { (c: Int) -> CGRect in let p = cam.point(b, c); return CGRect(x: p.x - cs / 2, y: p.y - cs / 2, width: cs, height: cs) }

        // Floor tiles, faint.
        if cs >= 10 {
            var floor = Path()
            let i = max(1, cs * MazeSizes.floorInset)
            for c in cells { floor.addRoundedRect(in: rect(c).insetBy(dx: i, dy: i), cornerSize: CGSize(width: cs * MazeSizes.floorRadius, height: cs * MazeSizes.floorRadius)) }
            ctx.fill(floor, with: .color(MazeInk.wall.opacity(MazeSizes.floorOpacity)))
        }
        // The start pad and the goal portal.
        let sr = rect(b.start).insetBy(dx: cs * MazeSizes.startInset, dy: cs * MazeSizes.startInset)
        ctx.fill(Path(roundedRect: sr, cornerRadius: cs * 0.08), with: .color(MazeInk.wall.opacity(0.14)))
        glow(&ctx, Path(roundedRect: sr, cornerRadius: cs * 0.08), MazeInk.wall, 2)
        let g = cam.point(b, b.goal)
        for (r, w, o) in [(0.44, 2.0, 1.0), (0.3, 1.5, 0.7)] { glow(&ctx, diamond(g, cs * r), MazeInk.gold.opacity(o), w) }
        ctx.fill(diamond(g, cs * 0.16), with: .color(MazeInk.gold))

        // Walls: two thin neon lines with floor between, so door cards sit in the gaps.
        var walls = Path()
        for c in cells {
            let r = rect(c)
            if b.x(c) < b.w - 1 && b.passages[c * 2] == nil { walls.move(to: CGPoint(x: r.maxX, y: r.minY)); walls.addLine(to: CGPoint(x: r.maxX, y: r.maxY)) }
            if b.y(c) < b.w - 1 && b.passages[c * 2 + 1] == nil { walls.move(to: CGPoint(x: r.minX, y: r.maxY)); walls.addLine(to: CGPoint(x: r.maxX, y: r.maxY)) }
        }
        let wf = fx.maze.walls
        let line = max(wf.lineMin, cs * wf.line), gap = max(wf.gapMin, cs * wf.gap)
        glow(&ctx, walls, MazeInk.wall, gap + 2 * line)
        ctx.stroke(walls, with: .color(MazeInk.bg), style: StrokeStyle(lineWidth: gap, lineCap: .round, lineJoin: .round))
        let o0 = cam.point(b, 0), whole = CGRect(x: o0.x - cs / 2, y: o0.y - cs / 2, width: cs * Double(b.w), height: cs * Double(b.w))
        let ow = max(MazeSizes.wallMin + 1, cs * MazeSizes.outerWall)
        glow(&ctx, Path(roundedRect: whole, cornerRadius: 4), MazeInk.outer, ow)
        ctx.stroke(Path(roundedRect: whole, cornerRadius: 4), with: .color(MazeInk.core.opacity(0.8)), lineWidth: ow * MazeSizes.coreRatio)

        // Junction chevrons near the tokens and along a walk, the way taken in gold.
        let pv = scene.preview
        let taken: [Int: Dir] = Dictionary((scene.hop?.junctions ?? pv?.walk.junctions ?? []).map { ($0.cell, $0.dir) }, uniquingKeysWith: { $1 })
        if cs >= fx.maze.chevronMinCell {
            let tokens = m.tokens.indices.compactMap { scene.position($0) }
            let reach = Int(ceil(cam.side / cs / 2))
            let path = Set(pv?.walk.path ?? scene.hop?.cells ?? [])
            for c in cells where b.liveExits(c).count >= 3 && (path.contains(c) || taken[c] != nil || tokens.contains { b.manhattan($0, c) <= reach }) {
                chevron(&ctx, cam.point(b, c), taken[c] ?? b.arrow[c], hot: taken[c] != nil)
            }
        }
        // Stars and hazards.
        for c in b.stars where cells.contains(c) { star(&ctx, cam.point(b, c)) }
        for h in m.hazards where !scene.hazardsGone.contains(h.cell) && cells.contains(h.cell) { hazard(&ctx, cam.point(b, h.cell), mine: h.kind == "mine") }

        // Doors, broken doors and switches.
        for k in Self.visibleKeys(b, cam) {
            guard var p = b.passages[k] else { continue }
            if let hit = scene.doorsHit[k] { if hit.broke { p.kind = .open; p.broken = true } else { p.damage = p.strength - hit.left } }
            let (mid, upright) = cam.middle(b, k)
            switch p.kind {
            case .door: doorCard(&ctx, mid, upright: upright, p)
            case .switch: switchMark(&ctx, mid, upright: upright, p)
            case .open where p.broken: brokenDoor(&ctx, mid, upright: upright)
            default: break
            }
        }

        // What the player can pick: passages to close, doors and cells for a bomb or burn, switches.
        if scene.myTurn, let e = scene.engine {
            switch scene.mode {
            case .close: for k in Self.visibleKeys(b, cam) where e.canClose(0, key: k) { targetBar(&ctx, k, light: true) }
            case .bomb:
                for k in e.bombDoors(0) { targetBar(&ctx, k) }
                for c in e.hazardCells(0) { targetRing(&ctx, cam.point(b, c), cs * 0.3) }
            case .burn: for c in e.hazardCells(0) { targetRing(&ctx, cam.point(b, c), cs * 0.3) }
            case .flip: for s in b.switches.indices where e.canFlip(s) { targetRing(&ctx, cam.middle(b, b.switches[s].a).0, max(9, cs * 0.28)) }
            default: break
            }
        }
        // The previewed walk: a dotted gold path and its end; with a reach, its junctions ringed in violet.
        if let pv, let from = m.tokens.first?.pos {
            if m.reachOn(0) {
                for j in pv.walk.junctions { ctx.stroke(Path(ellipseIn: square(cam.point(b, j.cell), cs * 0.46)), with: .color(MazeInk.violet), lineWidth: 2.5) }
            }
            var line = Path()
            line.move(to: cam.point(b, from))
            for c in pv.walk.path { line.addLine(to: cam.point(b, c)) }
            ctx.stroke(line, with: .color(MazeInk.gold.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [1, 6]))
            let end = cam.point(b, pv.walk.end)
            ctx.stroke(Path(ellipseIn: square(end, cs * 0.36)), with: .color(MazeInk.gold), lineWidth: 2.5)
            ctx.fill(Path(ellipseIn: square(end, cs * 0.1)), with: .color(MazeInk.gold))
        }
        tokens(&ctx)
        pointer(&ctx)
    }

    // MARK: Pieces

    func square(_ c: CGPoint, _ r: Double) -> CGRect { CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r) }

    func diamond(_ c: CGPoint, _ r: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r)); p.addLine(to: CGPoint(x: c.x + r, y: c.y))
        p.addLine(to: CGPoint(x: c.x, y: c.y + r)); p.addLine(to: CGPoint(x: c.x - r, y: c.y)); p.closeSubpath()
        return p
    }

    func chevron(_ ctx: inout GraphicsContext, _ c: CGPoint, _ d: Dir, hot: Bool) {
        let k = cs * (hot ? 0.17 : 0.13), o = cs * 0.2
        let a = [-Double.pi / 2, 0, Double.pi / 2, Double.pi][d.rawValue]
        func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: c.x + x * cos(a) - y * sin(a), y: c.y + x * sin(a) + y * cos(a)) }
        var p = Path()
        p.move(to: at(o - k * 0.5, -k)); p.addLine(to: at(o + k * 0.5, 0)); p.addLine(to: at(o - k * 0.5, k))
        ctx.stroke(p, with: .color(hot ? MazeInk.gold : MazeInk.wall.opacity(0.45)),
                   style: StrokeStyle(lineWidth: max(hot ? 2.2 : 1.4, cs * (hot ? 0.07 : 0.045)), lineCap: .round, lineJoin: .round))
    }

    func star(_ ctx: inout GraphicsContext, _ c: CGPoint) {
        let r = cs * MazeSizes.star, r2 = r * 0.44
        var p = Path()
        for i in 0..<10 {
            let a = -Double.pi / 2 + Double(i) * Double.pi / 5, rr = i % 2 == 0 ? r : r2
            let q = CGPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        ctx.fill(p, with: .color(MazeInk.gold.opacity(0.2)))
        glow(&ctx, p, MazeInk.gold, 2)
    }

    /// A fire is the burn card's flame; a mine the bomb card's bomb on a pale disc.
    func hazard(_ ctx: inout GraphicsContext, _ c: CGPoint, mine: Bool) {
        if mine {
            ctx.fill(Path(ellipseIn: square(c, cs * 0.4)), with: .color(Theme.face.opacity(0.85)))
            ctx.stroke(Path(ellipseIn: square(c, cs * 0.4)), with: .color(Theme.red), lineWidth: 1.5)
        } else {
            ctx.fill(Path(ellipseIn: square(c, cs * 0.42)), with: .color(Theme.flame.opacity(0.18)))
        }
        guard let art = CardArt.named(mine ? "icon-bomb" : "icon-burn") else { return }
        let k = cs * (mine ? 0.8 / 36 : 0.72 / 34)
        var l = ctx
        l.translateBy(x: c.x - (mine ? 28 : 25) * k, y: c.y - (mine ? 34 : 35) * k)
        l.scaleBy(x: k, y: k)
        art.draw(&l, size: CGSize(width: 50, height: 70))
    }

    /// A door: a playing card laid at a slant across the passage, its rank the strength left and its
    /// suit the door's. The rim is the closer's token colour, the suit's neon, or the door orange.
    func doorCard(_ ctx: inout GraphicsContext, _ c: CGPoint, upright: Bool, _ p: Passage) {
        let df = fx.maze.door
        let h = max(df.sizeMin, cs * df.size), w = h * 0.7
        let ink = p.suit.flatMap { Suit(letter: $0) }.map { Theme.suits[$0.rawValue] } ?? Theme.soft
        let rim = p.closedBy.map(MazeInk.token) ?? p.suit.map(MazeInk.neon) ?? MazeInk.door
        let g = p.suit.flatMap { Suit(letter: $0)?.textGlyph } ?? "–"
        var l = ctx
        l.translateBy(x: c.x, y: c.y)
        l.rotate(by: .degrees(upright ? df.turn : df.turn - 90))
        let r = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        l.fill(Path(roundedRect: r.offsetBy(dx: 1.5, dy: 2), cornerRadius: h * 0.09), with: .color(.black.opacity(0.5)))
        l.fill(Path(roundedRect: r, cornerRadius: h * 0.09), with: .color(Theme.face))
        l.stroke(Path(roundedRect: r, cornerRadius: h * 0.09), with: .color(rim), lineWidth: max(1.6, h * 0.06))
        let num = "\(p.left)"
        func text(_ s: String, _ size: Double) -> Text { Text(s).font(.system(size: size, weight: .heavy).width(.condensed)).foregroundColor(ink) }
        // The index in two corners, turned with the card.
        for turned in [false, true] {
            var q = l
            if turned { q.rotate(by: .degrees(180)) }
            q.draw(text(num, h * 0.17), at: CGPoint(x: -w / 2 + w * 0.17, y: -h / 2 + h * 0.1), anchor: .center)
            q.draw(text(g, h * 0.13), at: CGPoint(x: -w / 2 + w * 0.17, y: -h / 2 + h * 0.24), anchor: .center)
        }
        l.draw(text(num, h * (num.count > 2 ? 0.26 : 0.34)), at: CGPoint(x: 0, y: -h * 0.06), anchor: .center)
        l.draw(text(g, h * 0.2), at: CGPoint(x: 0, y: h * 0.24), anchor: .center)
        if p.damage > 0 {
            var crack = Path()
            crack.move(to: CGPoint(x: -w * 0.32, y: -h * 0.3)); crack.addLine(to: CGPoint(x: -w * 0.08, y: -h * 0.05))
            crack.addLine(to: CGPoint(x: -w * 0.2, y: h * 0.08)); crack.addLine(to: CGPoint(x: w * 0.1, y: h * 0.36))
            l.stroke(crack, with: .color(Theme.ink.opacity(0.45)), lineWidth: 1)
        }
    }

    /// A broken door: a faint card split by a crack, and the door's emitters at each end.
    func brokenDoor(_ ctx: inout GraphicsContext, _ c: CGPoint, upright: Bool) {
        let df = fx.maze.door
        let h = max(df.sizeMin, cs * df.size) * 0.8, w = h * 0.7
        var l = ctx
        l.translateBy(x: c.x, y: c.y)
        l.rotate(by: .degrees(upright ? df.turn : df.turn - 90))
        var crack = Path()
        crack.move(to: CGPoint(x: -w / 2, y: -h * 0.1)); crack.addLine(to: CGPoint(x: -w * 0.15, y: h * 0.05))
        crack.addLine(to: CGPoint(x: w * 0.1, y: -h * 0.08)); crack.addLine(to: CGPoint(x: w / 2, y: h * 0.06))
        l.stroke(Path(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: h * 0.09), with: .color(MazeInk.door.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        l.stroke(crack, with: .color(MazeInk.door.opacity(0.6)), lineWidth: 1.2)
        let L = cs * MazeSizes.laserLen / 2, e = max(3, cs * 0.09), t = max(4, cs * 0.1)
        for s in [-1.0, 1.0] {
            let r = upright ? CGRect(x: c.x - t / 2, y: c.y + s * L - (s > 0 ? e : 0), width: t, height: e)
                : CGRect(x: c.x + s * L - (s > 0 ? e : 0), y: c.y - t / 2, width: e, height: t)
            ctx.fill(Path(roundedRect: r, cornerRadius: 1), with: .color(MazeInk.door))
        }
    }

    /// A switch: a lettered disc on its passage; a thick glowing bar while it's shut, a dashed line while open.
    func switchMark(_ ctx: inout GraphicsContext, _ c: CGPoint, upright: Bool, _ p: Passage) {
        let L = cs * 0.46, r = max(7, cs * 0.2)
        var bar = Path()
        bar.move(to: CGPoint(x: c.x - (upright ? 0 : L), y: c.y - (upright ? L : 0)))
        bar.addLine(to: CGPoint(x: c.x + (upright ? 0 : L), y: c.y + (upright ? L : 0)))
        if p.on { ctx.stroke(bar, with: .color(MazeInk.violet.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4])) }
        else { glow(&ctx, bar, MazeInk.violet, max(3, cs * 0.12)) }
        let disc = Path(ellipseIn: square(c, r))
        ctx.fill(disc, with: .color(MazeInk.bg))
        ctx.stroke(disc, with: .color(MazeInk.violet), style: StrokeStyle(lineWidth: 1.5, dash: p.on ? [2, 2] : []))
        ctx.draw(Text(Maze.letters[p.sw ?? 0]).font(.system(size: r * 1.1, weight: .bold).width(.condensed)).foregroundColor(MazeInk.violet), at: c, anchor: .center)
    }

    /// A passage to pick: a pink bar across it. Every open passage is a target for Close a door, so
    /// those are drawn lighter (`light`) than a bomb's few doors.
    func targetBar(_ ctx: inout GraphicsContext, _ k: Int, light: Bool = false) {
        let (c, upright) = cam.middle(b, k), L = cs * (light ? 0.32 : 0.45)
        var p = Path()
        p.move(to: CGPoint(x: c.x - (upright ? 0 : L), y: c.y - (upright ? L : 0)))
        p.addLine(to: CGPoint(x: c.x + (upright ? 0 : L), y: c.y + (upright ? L : 0)))
        ctx.stroke(p, with: .color(MazeInk.pink.opacity(light ? 0.45 : 0.7)), style: StrokeStyle(lineWidth: light ? max(5, cs * 0.14) : max(9, cs * 0.3), lineCap: .round))
    }

    func targetRing(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: Double) {
        let p = Path(ellipseIn: square(c, r))
        ctx.fill(p, with: .color(MazeInk.pink.opacity(0.25)))
        ctx.stroke(p, with: .color(MazeInk.pink), lineWidth: 2)
    }

    /// A token: the player a disc, bots a square and a triangle, each in its colour.
    static func tokenPath(_ seat: Int, _ c: CGPoint, _ r: Double) -> Path {
        switch seat {
        case 0: return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        case 1: return Path(roundedRect: CGRect(x: c.x - r * 0.9, y: c.y - r * 0.9, width: r * 1.8, height: r * 1.8), cornerRadius: 2)
        default:
            var p = Path()
            for i in 0..<3 {
                let a = -Double.pi / 2 + Double(i) * 2 * Double.pi / 3
                let q = CGPoint(x: c.x + r * 1.2 * cos(a), y: c.y + r * 0.15 + r * 1.2 * sin(a))
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            p.closeSubpath()
            return p
        }
    }

    func tokens(_ ctx: inout GraphicsContext) {
        let focus = scene.hop?.seat ?? m.turn ?? 0
        let order = m.tokens.indices.filter { $0 != focus } + [focus]
        let tcs = max(cs, 16)
        for s in order {
            guard let at = scene.position(s) else { continue }
            let mates = m.tokens.indices.filter { scene.position($0) == at }
            let k = Double(mates.firstIndex(of: s) ?? 0), n = Double(mates.count)
            let off = mates.count > 1 ? (k - (n - 1) / 2) * cs * 0.28 : 0
            var c = cam.point(b, at)
            c.x += off; c.y += off * 0.3
            if let h = scene.hop, h.seat == s, h.moving, h.index + 1 < h.cells.count {
                let f = min(1, max(0, now.timeIntervalSince(h.since) * 1000 / Motion.t(Double(scene.timing?.stepMs ?? 90))))
                let e = f < 0.5 ? 2 * f * f : 1 - 2 * (1 - f) * (1 - f)
                let q = cam.point(b, h.cells[h.index + 1])
                c = CGPoint(x: c.x + (q.x - c.x) * e, y: c.y + (q.y - c.y) * e)
                let lift = sin(Double.pi * f) * cs * fx.maze.hop.lift
                let sw = cs * (fx.maze.hop.shadow - 0.08 * sin(Double.pi * f))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - sw, y: c.y + cs * 0.22 - cs * 0.07, width: 2 * sw, height: cs * 0.14)), with: .color(.black.opacity(0.45)))
                c.y -= lift
            }
            let r = tcs * (mates.count > 1 ? MazeSizes.tokenOnStart : MazeSizes.token)
            let shape = Self.tokenPath(s, c, r)
            ctx.drawLayer { l in l.addFilter(.blur(radius: MazeSizes.glow)); l.fill(shape, with: .color(MazeInk.token(s))) }
            ctx.fill(shape, with: .color(MazeInk.token(s)))
            ctx.stroke(shape, with: .color(.white), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
    }

    /// An arrow at the view's edge pointing to the goal, while the goal is out of view.
    func pointer(_ ctx: inout GraphicsContext) {
        let g = cam.point(b, b.goal), v = cam.side
        guard g.x < 0 || g.y < 0 || g.x > v || g.y > v else { return }
        let o = v / 2, dx = g.x - o, dy = g.y - o
        let k = min((o - 22) / max(abs(dx), 1e-9), (o - 22) / max(abs(dy), 1e-9))
        let c = CGPoint(x: o + dx * k, y: o + dy * k), r = 13.0, a = atan2(dy, dx)
        ctx.fill(Path(ellipseIn: square(c, r)), with: .color(MazeInk.bg))
        glow(&ctx, Path(ellipseIn: square(c, r)), MazeInk.gold, 2)
        var tip = Path()
        let t = CGPoint(x: c.x + (r + 8) * cos(a), y: c.y + (r + 8) * sin(a))
        let s1 = CGPoint(x: c.x + r * cos(a + 0.45), y: c.y + r * sin(a + 0.45)), s2 = CGPoint(x: c.x + r * cos(a - 0.45), y: c.y + r * sin(a - 0.45))
        tip.move(to: t); tip.addLine(to: s1); tip.addLine(to: s2); tip.closeSubpath()
        ctx.fill(tip, with: .color(MazeInk.gold))
        ctx.fill(diamond(c, r * 0.5), with: .color(MazeInk.gold))
    }
}
