// The score breakdown sequence, as the match turn mock plays it (match-turn.html › playBreakdown):
// the set lifts and the board dims; a SINGLE or MULTI banner shows the headline and suit;
// each combo lights its cards, floats its points and adds a tally line; powered edge cards
// show their multipliers; left-over cards cost steps; edge cards power up; the total goes
// to the step counter. Tap the screen to skip.
import CardKit
import CribMaze
import CribbageKit
import SwiftUI

enum LineStyle { case normal, power, penalty, total }

struct TallyLine: Identifiable {
    let id: Int
    let name: String, pts: String, run: String
    let style: LineStyle
}

struct FloatText: Identifiable {
    let id: Int
    let at: [Pos]
    let text: String, sub: String
    let style: LineStyle
}

struct Banner { let kind: String; let head: String; let suit: String }

/// Timings from the mock's defaults: the first step 1.2 s, each after 15% quicker, never under 0.4 s.
struct BreakdownTiming {
    var base = 1200.0, accel = 0.85, min = 400.0
    var scale: Double { base / 1200 }
}

/// What the screen shows while a score plays out. The board itself still shows the turn
/// from before the score; it changes once the breakdown ends.
@MainActor @Observable
final class Playback {
    var set: [Pos] = []
    var lit: Set<Pos> = []
    var litPower: Set<Pos> = []
    var leftOver: Set<Pos> = []
    var chipLevel: [Pos: Int] = [:]
    var banner: Banner?
    var tally: [TallyLine] = []
    var tallyOn = false
    var floats: [FloatText] = []
    var placeTop = true
    var active = false
    var skipping = false
    var bump = false
    /// For snapshots: every wait is instant (unlike skipping, floats still show).
    var instant = false
    private var nextID = 0

    func id() -> Int { nextID += 1; return nextID }

    func wait(_ ms: Double) async {
        guard !skipping, !instant, ms > 0 else { return }
        try? await Task.sleep(for: .milliseconds(Int(ms)))
    }

    func float(_ at: [Pos], _ text: String, _ sub: String, _ style: LineStyle = .normal) {
        guard !skipping else { return }
        let f = FloatText(id: id(), at: at, text: text, sub: sub, style: style)
        floats.append(f)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1000))
            self?.floats.removeAll { $0.id == f.id }
        }
    }

    func line(_ name: String, _ pts: String, _ run: String, _ style: LineStyle = .normal) {
        withAnimation(.easeOut(duration: 0.22)) { tally.append(TallyLine(id: id(), name: name, pts: pts, run: run, style: style)) }
    }

    func reset() {
        set = []; lit = []; litPower = []; leftOver = []; chipLevel = [:]; banner = nil; tally = []; tallyOn = false
        floats = []; active = false; skipping = false
    }
}

extension GameSession {
    static func displayName(_ c: ComboOut) -> String {
        switch c.kind {
        case .fifteen: return "Fifteen"
        case .pair: return ["2": "Pair", "3": "Pair royal", "4": "Double pair royal"][String(c.size ?? 2)] ?? "\(c.size ?? 2) of a kind"
        case .run:
            let m = c.multiplier ?? 1
            return ([1: "Run", 2: "Double run", 3: "Triple run", 4: "Double double run"][m] ?? "\(m) runs") + " of \(c.size ?? 3)"
        case .flush: return "Flush of \(c.size ?? 4)"
        case .nobs: return "His nobs"
        }
    }

    /// The set's headline: its biggest combo that isn't a fifteen, or its fifteens.
    static func headline(_ combos: [ComboOut]) -> String {
        let f = combos.filter { $0.kind == .fifteen }.count
        let rest = combos.filter { $0.kind != .fifteen }
        if let top = rest.max(by: { $0.points < $1.points }) {   // first of the biggest, as the mock sorts
            return displayName(rest.first { $0.points == top.points }!)
        }
        let words = ["", "", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"]
        return f == 1 ? "Fifteen" : (f < words.count ? words[f] : "\(f)") + " fifteens"
    }

    static func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : n < 0 ? "−\(-n)" : "0" }

    /// Plays a score's breakdown over the board as it was before the score.
    func playBreakdown(_ e: MatchEvent, before old: MatchState) async {
        guard case .score(let names, let refs, let combos, _, let pct, let multiplied, _, _, let points, _, let suit, _) = e else { return }
        let pb = playback, T = timing
        let sel = names.compactMap(Board.parse)
        let face = { (p: Pos) in old.cells[p]?.face ?? "" }
        var n = 0
        func stepMs() -> Double { defer { n += 1 }; return max(T.min, T.base * pow(T.accel, Double(n))) }
        let suitText = suit.flatMap { Suit(letter: $0)?.glyph } ?? "no suit"
        let head = Self.headline(combos)

        pb.reset(); pb.active = true
        let rows = sel.map { Board.coords($0).r }
        pb.placeTop = Double(rows.reduce(0, +)) / Double(rows.count) >= 2   // away from the set
        await pb.wait(300 * T.scale)
        withAnimation(.easeOut(duration: 0.25)) { pb.set = sel }
        await pb.wait(350 * T.scale)
        withAnimation(.spring(duration: 0.25)) { pb.banner = Banner(kind: combos.count > 1 ? "MULTI ×\(combos.count)" : "SINGLE", head: head, suit: suitText) }
        await pb.wait(900 * T.scale)
        withAnimation(.easeOut(duration: 0.2)) { pb.tallyOn = true }

        var total = 0
        for c in combos {
            let ps = c.cards.map { sel[$0] }
            total += c.points
            withAnimation(.spring(duration: 0.25)) { pb.lit = Set(ps) }
            pb.float(ps, "+\(c.points)", Self.displayName(c))
            pb.line(Self.displayName(c), Self.signed(c.points), "\(total)")
            let ms = stepMs()
            await pb.wait(ms * 0.88)
            withAnimation(.easeOut(duration: 0.15)) { pb.lit = [] }
            await pb.wait(ms * 0.12)
        }
        // Edge power multiplies the combos: each powered card lights with its multiplier, then the set's applies.
        let powered = sel.filter { Board.isEdge($0) && old.power[$0] > 0 }
        for p in powered {
            withAnimation(.spring(duration: 0.25)) { pb.litPower = [p] }
            let m = multiplierText(old.power[p])
            pb.float([p], m, "edge power", .power)
            pb.line("Edge power \(face(p))", m, "", .power)
            await pb.wait(stepMs())
            withAnimation(.easeOut(duration: 0.15)) { pb.litPower = [] }
        }
        if !powered.isEmpty {
            let gain = multiplied - total; total = multiplied
            pb.float(sel, multiplierText(percent: pct), "+\(gain)", .power)
            pb.line("Multiplier" + (powered.count > 1 ? " (levels added)" : ""), multiplierText(percent: pct), "\(total)", .power)
            await pb.wait(stepMs())
        }
        // Cards left over cost steps, one line each, not multiplied.
        let used = Set(combos.flatMap(\.cards))
        let cost = config?.rules.match.leftOverCost ?? 2
        for i in sel.indices where !used.contains(i) {
            let p = sel[i]
            total -= cost
            withAnimation(.spring(duration: 0.25)) { _ = pb.leftOver.insert(p) }
            pb.float([p], "−\(cost)", "left over", .penalty)
            pb.line("Left over \(face(p))", "−\(cost)", "\(total)", .penalty)
            await pb.wait(stepMs())
        }
        // Power up: every edge card in the set gains a level for later scores.
        let edges = sel.filter(Board.isEdge)
        if !edges.isEmpty {
            pb.line("Power up " + edges.map(face).joined(separator: " "), "▲", "", .power)
            let step = config?.rules.match.edgePower.step ?? 1
            withAnimation(.spring(duration: 0.3)) {
                pb.litPower = Set(edges)
                for p in edges { pb.chipLevel[p] = old.power[p] + step }
            }
            for p in edges { pb.float([p], "▲", multiplierText(old.power[p] + step), .power) }
            await pb.wait(stepMs())
            withAnimation(.easeOut(duration: 0.15)) { pb.litPower = [] }
        }
        _ = refs
        pb.line("\(head) · \(suitText)", "", Self.signed(points), .total)
        await pb.wait(max(T.min, 800 * T.scale))
    }
}

/// The breakdown's banner, tally panel and floating points, drawn over the board.
struct BreakdownOverlay: View {
    let pb: Playback

    var body: some View {
        ZStack(alignment: pb.placeTop ? .top : .bottom) {
            ForEach(pb.floats) { f in FloatView(f: f) }
            VStack(spacing: 8) {
                if !pb.placeTop { tally }
                if let b = pb.banner { banner(b).transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: -8))) }
                if pb.placeTop { tally }
            }
            .padding(.vertical, 6)
        }
        .frame(width: BoardLayout.width, height: BoardLayout.height)
        .allowsHitTesting(false)
    }

    private func banner(_ b: Banner) -> some View {
        HStack(spacing: 8) {
            Text(b.kind).font(Theme.font(11, .bold)).tracking(1.1).padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.ink)).foregroundStyle(Theme.gold)
            Text(b.head).font(Theme.font(22, .bold))
            Text(b.suit).font(Theme.font(13, .semibold)).padding(.horizontal, 6).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xFFFDF7)))
        }
        .lineLimit(1).fixedSize()
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold).shadow(color: Theme.gold.opacity(0.5), radius: 10))
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder private var tally: some View {
        if pb.tallyOn {
            VStack(spacing: 0) {
                ForEach(pb.tally) { l in
                    HStack(spacing: 6) {
                        Text(l.name).frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                        Text(l.pts).fontWeight(.bold).frame(width: 48, alignment: .trailing)
                            .foregroundStyle(l.style == .power ? Theme.power : l.style == .penalty ? Color(hex: 0xFF7A7A) : Theme.gold)
                        Text(l.run).monospacedDigit().frame(width: 52, alignment: .trailing).opacity(l.style == .total ? 1 : 0.8)
                    }
                    .font(Theme.font(l.style == .total ? 20 : 16, l.style == .total ? .bold : .medium))
                    .frame(minHeight: 24)
                    .padding(.top, l.style == .total ? 4 : 0)
                    .overlay(alignment: .top) { if l.style == .total { Rectangle().fill(Theme.feltText.opacity(0.3)).frame(height: 1) } }
                    .transition(.opacity.combined(with: .offset(x: -10)))
                }
            }
            .foregroundStyle(Theme.feltText)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.felt.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cyan.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 10, y: 8)
            .padding(.horizontal, 8)
            .transition(.opacity)
        }
    }
}

/// Points that pop up over the cards and rise away (the mock's .float).
struct FloatView: View {
    let f: FloatText
    var body: some View {
        let pts = f.at.map { BoardLayout.frame($0) }
        let x = pts.map(\.midX).reduce(0, +) / CGFloat(max(1, pts.count))
        let y = pts.map(\.midY).reduce(0, +) / CGFloat(max(1, pts.count))
        VStack(spacing: 0) {
            Text(f.text).font(Theme.font(30, .bold))
            if !f.sub.isEmpty { Text(f.sub).font(Theme.font(13, .semibold)).opacity(0.9) }
        }
        .fixedSize()
        .foregroundStyle(f.style == .power ? Theme.power : f.style == .penalty ? Color(hex: 0xFF7A7A) : .white)
        .shadow(color: .black.opacity(0.7), radius: 3, y: 2)
        .keyframeAnimator(initialValue: Rise(), repeating: false) { v, r in
            v.scaleEffect(r.scale).offset(y: r.y).opacity(r.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) { CubicKeyframe(1.15, duration: 0.18); CubicKeyframe(1, duration: 0.45); CubicKeyframe(1, duration: 0.27) }
            KeyframeTrack(\.y) { CubicKeyframe(0, duration: 0.18); CubicKeyframe(-18, duration: 0.45); CubicKeyframe(-36, duration: 0.27) }
            KeyframeTrack(\.opacity) { CubicKeyframe(1, duration: 0.18); CubicKeyframe(1, duration: 0.45); CubicKeyframe(0, duration: 0.27) }
        }
        .position(x: x, y: y)
    }
    struct Rise { var scale = 0.6, y = 12.0, opacity = 0.0 }
}
