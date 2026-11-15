// The score breakdown sequence, as the match turn mock plays it (match-turn.html › playBreakdown):
// the set lifts and the board dims; a SINGLE or MULTI banner shows the headline and suit;
// each combo lights its cards, floats its points and adds a tally line; powered edge cards
// show their multipliers; left-over cards cost steps; edge cards power up; the total goes
// to the step counter. Tap the screen to skip.
//
// Unlike the mock, the set's cards fly up from the board into a row at the top, the starter
// on the right, and the breakdown plays over that row; so it always sits in the same place.
import CardKit
import CribMaze
import CribbageKit
import SwiftUI

enum LineStyle { case normal, power, penalty, total }

struct TallyLine: Identifiable {
    let id: Int
    let name: String, pts: String, run: String
    let style: LineStyle
    /// The cards behind the line: a combo's cards, a powered card, a card left over.
    var cards: [Card] = []
}

struct FloatText: Identifiable {
    let id: Int
    let point: CGPoint
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
    /// The set's cards in the row, in count order (the starter last), and whether they've flown up.
    var row: [Pos] = []
    var rowCards: [Pos: Card] = [:]
    var rowOn = false
    /// Power chips on the row's edge cards (×1.5), updated as they power up.
    var chipText: [Pos: String] = [:]
    /// The total's flight from the tally up to the step counter, in the phone's coordinates.
    var totalAt: CGPoint?
    var stepsAt: CGPoint = .zero
    var fly: FlyText?
    var active = false
    var skipping = false
    var bump = false
    /// The breakdown has finished and waits for a tap before the board moves on.
    var holding = false
    /// The demo moves on by itself.
    var autoContinue = false
    private var resume: CheckedContinuation<Void, Never>?
    /// For snapshots: every wait is instant (unlike skipping, floats still show).
    var instant = false
    private var nextID = 0

    func id() -> Int { nextID += 1; return nextID }

    func wait(_ ms: Double) async {
        guard !skipping, !instant, ms > 0 else { return }
        try? await Task.sleep(for: .milliseconds(Motion.ms(ms)))
    }

    func float(_ at: [Pos], _ text: String, _ sub: String, _ style: LineStyle = .normal) {
        guard !skipping else { return }
        let pts = at.map(place)
        let point = CGPoint(x: pts.map(\.x).reduce(0, +) / CGFloat(max(1, pts.count)), y: pts.map(\.y).reduce(0, +) / CGFloat(max(1, pts.count)))
        let f = FloatText(id: id(), point: point, text: text, sub: sub, style: style)
        floats.append(f)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Motion.ms(1000)))
            self?.floats.removeAll { $0.id == f.id }
        }
    }

    /// Where a card is now: its slot in the row once the row is up, or its cell.
    func place(_ p: Pos) -> CGPoint {
        if rowOn, let c = RowLayout.centre(p, in: row) { return c }
        let f = BoardLayout.frame(p); return CGPoint(x: f.midX, y: f.midY)
    }

    func line(_ name: String, _ pts: String, _ run: String, _ style: LineStyle = .normal, cards: [Card] = []) {
        withAnimation(.easeOut(duration: Motion.t(0.22))) { tally.append(TallyLine(id: id(), name: name, pts: pts, run: run, style: style, cards: cards)) }
    }

    /// Waits for a tap (or click) on the screen. Snapshots and the demo don't wait.
    func hold() async {
        guard !instant, !autoContinue else { return }
        withAnimation(.easeOut(duration: Motion.t(0.2))) { holding = true }
        await withCheckedContinuation { resume = $0 }
        holding = false
    }

    /// A tap: moves on from the hold, or skips the rest of the sequence to it.
    func tap() { if holding { release() } else { skipping = true } }

    func release() { resume?.resume(); resume = nil }

    func reset() {
        set = []; lit = []; litPower = []; leftOver = []; chipLevel = [:]; banner = nil; tally = []; tallyOn = false
        row = []; rowCards = [:]; rowOn = false; chipText = [:]; fly = nil
        floats = []; active = false; skipping = false; holding = false
        release()
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
        var n = 0
        func stepMs() -> Double { defer { n += 1 }; return max(T.min, T.base * pow(T.accel, Double(n))) }
        let suitText = suit.flatMap { Suit(letter: $0)?.glyph } ?? "no suit"
        let head = Self.headline(combos)

        pb.reset(); pb.active = true
        for p in sel { pb.rowCards[p] = old.cells[p] }
        for p in sel where Board.isEdge(p) && old.power[p] > 0 { pb.chipText[p] = multiplierText(old.power[p]) }
        await pb.wait(150 * T.scale)
        // The cards leave the board (their cells empty and the rest dims) and fly up into the row.
        pb.row = sel
        withAnimation(.easeOut(duration: Motion.t(0.25))) { pb.set = sel }
        if pb.instant { pb.rowOn = true } else {
            try? await Task.sleep(for: .milliseconds(20))
            pb.rowOn = true   // each row card animates itself, staggered
        }
        await pb.wait(650 * T.scale)
        withAnimation(.spring(duration: Motion.t(0.25))) { pb.banner = Banner(kind: combos.count > 1 ? "MULTI ×\(combos.count)" : "SINGLE", head: head, suit: suitText) }
        await pb.wait(900 * T.scale)
        withAnimation(.easeOut(duration: Motion.t(0.2))) { pb.tallyOn = true }
        let card = { (p: Pos) in old.cells[p] }
        // r16: the starter joined this set. It lights first, so it reads as part of every score.
        if sel.contains(Board.starter), turn?.starterJoins == true {
            withAnimation(.spring(duration: Motion.t(0.25))) { pb.lit = [Board.starter] }
            pb.float([Board.starter], "Starter", "joins the set")
            pb.line("Starter joins", "", "", .normal, cards: [card(Board.starter)].compactMap { $0 })
            await pb.wait(stepMs())
            withAnimation(.easeOut(duration: Motion.t(0.15))) { pb.lit = [] }
        }

        var total = 0
        for c in combos {
            let ps = c.cards.map { sel[$0] }
            total += c.points
            withAnimation(.spring(duration: Motion.t(0.25))) { pb.lit = Set(ps) }
            pb.float(ps, "+\(c.points)", Self.displayName(c))
            pb.line(Self.displayName(c), Self.signed(c.points), "\(total)", cards: ps.compactMap(card))
            let ms = stepMs()
            await pb.wait(ms * 0.88)
            withAnimation(.easeOut(duration: Motion.t(0.15))) { pb.lit = [] }
            await pb.wait(ms * 0.12)
        }
        // Edge power multiplies the combos: each powered card lights with its multiplier, then the set's applies.
        let powered = sel.filter { Board.isEdge($0) && old.power[$0] > 0 }
        for p in powered {
            withAnimation(.spring(duration: Motion.t(0.25))) { pb.litPower = [p] }
            let m = multiplierText(old.power[p])
            pb.float([p], m, "edge power", .power)
            pb.line(p == Board.starter ? "Starter power" : "Edge power", m, "", .power, cards: [card(p)].compactMap { $0 })
            await pb.wait(stepMs())
            withAnimation(.easeOut(duration: Motion.t(0.15))) { pb.litPower = [] }
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
            withAnimation(.spring(duration: Motion.t(0.25))) { _ = pb.leftOver.insert(p) }
            pb.float([p], "−\(cost)", "left over", .penalty)
            pb.line("Left over", "−\(cost)", "\(total)", .penalty, cards: [card(p)].compactMap { $0 })
            await pb.wait(stepMs())
        }
        // Power up: every edge card in the set gains a level for later scores.
        let edges = sel.filter(Board.isEdge)
        if !edges.isEmpty {
            pb.line("Power up", "▲", "", .power, cards: edges.compactMap(card))
            let step = config?.rules.match.edgePower.step ?? 1
            withAnimation(.spring(duration: Motion.t(0.3))) {
                pb.litPower = Set(edges)
                for p in edges { pb.chipLevel[p] = old.power[p] + step; pb.chipText[p] = multiplierText(old.power[p] + step) }
            }
            for p in edges { pb.float([p], "▲", multiplierText(old.power[p] + step), .power) }
            await pb.wait(stepMs())
            withAnimation(.easeOut(duration: Motion.t(0.15))) { pb.litPower = [] }
        }
        _ = refs
        pb.line("\(head) · \(suitText)", Self.signed(points), "", .total)
        await pb.wait(max(T.min, 500 * T.scale))
        await pb.hold()
        // The cards fly home; then the board moves on (grid cards clear, edge cards stay).
        if !pb.instant {
            // The total floats up from the scoresheet to the step counter as the cards fly home.
            if let from = pb.totalAt {
                pb.fly = FlyText(text: Self.signed(points), from: from)
                withAnimation(.easeIn(duration: Motion.t(0.5))) { pb.fly?.arrived = true }
            }
            withAnimation(.easeOut(duration: Motion.t(0.2))) { pb.tallyOn = false; pb.banner = nil }
            pb.rowOn = false
            try? await Task.sleep(for: .milliseconds(Motion.ms(500)))
        }
    }
}

/// Where the breakdown sits over the board: the banner on top, the set's cards in a row
/// under it (the starter on the right, a little apart), then the tally.
enum RowLayout {
    static let w: CGFloat = 50, h: CGFloat = w * 1.4, gap: CGFloat = 6, starterGap: CGFloat = 18
    static let bannerH: CGFloat = 50
    static let top: CGFloat = bannerH + 22          // room for the STARTER tag over the row
    static let tallyTop: CGFloat = top + h + 14

    static func centre(_ p: Pos, in row: [Pos]) -> CGPoint? {
        guard let i = row.firstIndex(of: p) else { return nil }
        let n = row.count, apart = n > 1 && row.last == Board.starter
        let total = CGFloat(n) * w + CGFloat(n - 1) * gap + (apart ? starterGap - gap : 0)
        var x = (BoardLayout.width - total) / 2 + CGFloat(i) * (w + gap) + w / 2
        if apart && i == n - 1 { x += starterGap - gap }
        return CGPoint(x: x, y: top + h / 2)
    }
}

/// The breakdown's banner, card row, tally panel and floating points, drawn over the board.
struct BreakdownOverlay: View {
    let pb: Playback
    /// The tally's natural height. A long breakdown (many fifteens, say) scales down to stay on the board.
    @State private var tallyH: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The board fades back under the breakdown, so nothing behind it competes.
            // It reaches past the edge background's outline and glow, so no stray borders show through.
            RoundedRectangle(cornerRadius: 16).fill(Theme.felt.opacity(0.94)).padding(-(Theme.edgePadOuter + 8))
                .opacity(pb.active ? 1 : 0)
                .animation(.easeOut(duration: Motion.t(0.3)), value: pb.active)
            VStack {
                if let b = pb.banner { banner(b).transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: -8))) }
            }
            .frame(width: BoardLayout.width, height: RowLayout.bannerH)
            let room = BoardLayout.height - RowLayout.tallyTop + 8
            tally.frame(width: BoardLayout.width)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { tallyH = $0 }
                .scaleEffect(tallyH > room ? room / tallyH : 1, anchor: .top)
                .animation(.easeOut(duration: Motion.t(0.2)), value: tallyH > room)
                .offset(y: RowLayout.tallyTop)
            ForEach(Array(pb.row.enumerated()), id: \.element) { i, p in
                if let card = pb.rowCards[p] { RowCard(p: p, card: card, index: i, pb: pb) }
            }
            ForEach(pb.floats) { f in FloatView(f: f) }
        }
        .frame(width: BoardLayout.width, height: BoardLayout.height, alignment: .topLeading)
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
                        // Name on the left; the cards sit on the right, next to their points, so rows line up.
                        // A long name with many cards moves the cards under it.
                        let cards = HStack(spacing: 2) { ForEach(Array(l.cards.enumerated()), id: \.offset) { _, c in MiniCard(card: c) } }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) { Text(l.name).lineLimit(1).fixedSize(); Spacer(minLength: 4); cards }
                            VStack(alignment: .trailing, spacing: 2) { Text(l.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading); cards }
                        }
                        .frame(maxWidth: .infinity)
                        Text(l.pts).fontWeight(.bold).monospacedDigit().frame(width: l.style == .total ? 64 : 48, alignment: .trailing)
                            .foregroundStyle(l.style == .total ? Theme.feltText : l.style == .power ? Theme.power : l.style == .penalty ? Color(hex: 0xFF7A7A) : Theme.gold)
                    }
                    .font(Theme.font(l.style == .total ? 20 : 16, l.style == .total ? .bold : .medium))
                    .frame(minHeight: 24)
                    .padding(.top, l.style == .total ? 4 : 0)
                    .overlay(alignment: .top) { if l.style == .total { Rectangle().fill(Theme.feltText.opacity(0.3)).frame(height: 1) } }
                    .onGeometryChange(for: CGPoint.self, of: { g in
                        let f = g.frame(in: .named("phone")); return CGPoint(x: f.maxX - 30, y: f.midY)
                    }) { p in if l.style == .total { pb.totalAt = p } }
                    .transition(.opacity.combined(with: .offset(x: -10)))
                }
            }
            .foregroundStyle(Theme.feltText)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.felt.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.cyan.opacity(0.35), lineWidth: 1))
            .overlay(alignment: .bottom) {
                if pb.holding {
                    Text("Tap to continue").font(Theme.font(13, .semibold)).foregroundStyle(Theme.cyan)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(Theme.felt)).overlay(Capsule().strokeBorder(Theme.cyan.opacity(0.5), lineWidth: 1))
                        .offset(y: 13).transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 10, y: 8)
            .padding(.horizontal, 8)
            .padding(.bottom, pb.holding ? 14 : 0)
            .transition(.opacity)
        }
    }
}

/// Points that pop up over the cards and rise away (the mock's .float).
struct FloatView: View {
    let f: FloatText
    var body: some View {
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
            KeyframeTrack(\.scale) { CubicKeyframe(1.15, duration: Motion.t(0.18)); CubicKeyframe(1, duration: Motion.t(0.45)); CubicKeyframe(1, duration: Motion.t(0.27)) }
            KeyframeTrack(\.y) { CubicKeyframe(0, duration: Motion.t(0.18)); CubicKeyframe(-18, duration: Motion.t(0.45)); CubicKeyframe(-36, duration: Motion.t(0.27)) }
            KeyframeTrack(\.opacity) { CubicKeyframe(1, duration: Motion.t(0.18)); CubicKeyframe(1, duration: Motion.t(0.45)); CubicKeyframe(0, duration: Motion.t(0.27)) }
        }
        .position(f.point)
    }
    struct Rise { var scale = 0.6, y = 12.0, opacity = 0.0 }
}

/// A small card in a tally line: rank and suit, in the card face's colours.
struct MiniCard: View {
    let card: Card
    var body: some View {
        let colour = card.suit?.colour ?? Theme.ink
        Text(card.isPlaying ? Card.rankText(card.rank) + (card.suit?.textGlyph ?? "") : "★")
            .font(Theme.font(12, .bold)).tracking(-0.3)
            .foregroundStyle(colour)
            .frame(minWidth: 22, minHeight: 26).padding(.horizontal, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.face))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(card.kind == .made ? Theme.gold : Theme.rule, lineWidth: 1))
    }
}

/// One of the set's cards: it flies from its cell to its slot in the row, shrinking as it goes,
/// and lights there as the breakdown counts it. The starter is tagged.
struct RowCard: View {
    let p: Pos, card: Card, index: Int
    let pb: Playback

    var body: some View {
        let on = pb.rowOn
        let home = BoardLayout.frame(p)
        let c = on ? (RowLayout.centre(p, in: pb.row) ?? CGPoint(x: home.midX, y: home.midY)) : CGPoint(x: home.midX, y: home.midY)
        let lit = pb.lit.contains(p), power = pb.litPower.contains(p), left = pb.leftOver.contains(p)
        let ring: Color = lit ? Theme.gold : power ? Theme.power : left ? Color(hex: 0xFF5A5A) : .white
        let starter = p == Board.starter
        CardFace(card: card)
            .overlay { RoundedRectangle(cornerRadius: Theme.cardRadius + 1.5).stroke(ring, lineWidth: lit || power || left ? 4 : 2).padding(-1.5) }
            .overlay(alignment: .top) {
                if starter && on {
                    Text("STARTER").font(Theme.font(13, .bold)).tracking(1).padding(.horizontal, 7).frame(height: 20)
                        .background(Capsule().fill(Theme.feltText)).foregroundStyle(Theme.felt).fixedSize().offset(x: pb.chipText[p] != nil ? -22 : 0, y: -24)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let t = pb.chipText[p] {
                    Text(t).font(Theme.font(15, .bold)).padding(.horizontal, 7).frame(height: 22)
                        .background(Capsule().fill(power ? Theme.power : Theme.gold)).foregroundStyle(Theme.ink).fixedSize().offset(x: 8, y: -8)
                }
            }
            .shadow(color: lit ? Theme.gold.opacity(0.85) : power ? Theme.power.opacity(0.8) : left ? Color(hex: 0xFF5A5A, opacity: 0.7) : .black.opacity(0.4),
                    radius: lit || power || left ? 9 : 5, y: lit || power || left ? 0 : 3)
            .offset(y: lit || power ? -10 : 0)
            .animation(.spring(duration: Motion.t(0.25)), value: lit || power || left)
            .rotationEffect(starter && !on ? .degrees(-5) : .zero)
            .scaleEffect(on ? RowLayout.w / Theme.cardW : 1)
            .frame(width: Theme.cardW, height: Theme.cardH)
            .offset(x: c.x - Theme.cardW / 2, y: c.y - Theme.cardH / 2)
            // Staggered flights; the starter, last in the row, comes up from its corner last.
            .animation(.spring(duration: Motion.t(0.5), bounce: 0.18).delay(Motion.t(Double(index) * 0.05)), value: on)
    }
}

struct FlyText: Equatable {
    let text: String
    let from: CGPoint
    var arrived = false
}

/// The score's total on its way to the step counter.
struct FlyView: View {
    let pb: Playback
    var body: some View {
        if let f = pb.fly {
            Text(f.text).font(Theme.font(f.arrived ? 26 : 34, .bold)).foregroundStyle(Theme.gold)
                .shadow(color: Theme.gold.opacity(0.7), radius: 8)
                .fixedSize()
                .position(f.arrived ? pb.stepsAt : f.from)
                .allowsHitTesting(false)
        }
    }
}
