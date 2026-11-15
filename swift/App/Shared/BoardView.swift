// The board as the mock lays it out: a 4 × 4 grid, the crib down the right and the hand
// along the bottom, set apart by a wider gap, with the starter tilted in the corner.
// The hand, crib and starter sit on one rounded background.
// Drag across touching cards to trace a set, or tap cards and tap the last one again.
import CardKit
import CribMaze
import SwiftUI

enum BoardLayout {
    static let pitchX = Theme.cardW + Theme.gap, pitchY = Theme.cardH + Theme.gap
    static let width = 4 * pitchX + Theme.edgeGap + Theme.cardW
    static let height = 4 * pitchY + Theme.edgeGap + Theme.cardH
    /// A card's frame: the edge column and row are pushed out by the edge gap.
    static func frame(_ p: Pos) -> CGRect {
        let (r, c) = Board.coords(p)
        let x = CGFloat(c) * pitchX + (c == 4 ? Theme.edgeGap : 0)
        let y = CGFloat(r) * pitchY + (r == 4 ? Theme.edgeGap : 0)
        return CGRect(x: x, y: y, width: Theme.cardW, height: Theme.cardH)
    }
}

/// One rounded shape behind the crib column, the hand row and the starter.
struct EdgeBackground: Shape {
    var dealer: Bool
    func path(in rect: CGRect) -> Path {
        let pad = Theme.edgePad, outer = Theme.edgePadOuter, r = Theme.cardRadius + pad
        func grow(_ f: CGRect) -> CGRect {   // the inner sides get pad; the right and bottom, where the starter tilts, get more
            CGRect(x: f.minX - pad, y: f.minY - pad, width: f.width + pad + outer, height: f.height + pad + outer)
        }
        let row = grow(BoardLayout.frame(Board.hand.lowerBound).union(BoardLayout.frame(Board.starter)))
        var p = Path(roundedRect: row, cornerRadius: r)
        if dealer {
            let col = grow(BoardLayout.frame(Board.crib.lowerBound).union(BoardLayout.frame(Board.starter)))
            p = p.union(Path(roundedRect: col, cornerRadius: r))
        }
        return p
    }
}

struct BoardView: View {
    let session: GameSession
    @State private var dragging = false
    @State private var moved = false
    /// A swipe picks a card only near its centre (the mock's 70% default).
    private let hitFraction: CGFloat = 0.7

    var body: some View {
        let state = session.state
        let lit = session.litPositions
        ZStack(alignment: .topLeading) {
            EdgeBackground(dealer: state?.dealer ?? true).fill(Theme.panel)
            EdgeBackground(dealer: state?.dealer ?? true).stroke(Theme.cyan.opacity(0.12), lineWidth: 5)
            EdgeBackground(dealer: state?.dealer ?? true).stroke(Theme.cyan.opacity(0.5), lineWidth: 1)
            // The starter counts with every set (r16), so it sits on a lighter bed of its own.
            let sf = BoardLayout.frame(Board.starter).insetBy(dx: -Theme.edgePad - 3, dy: -Theme.edgePad - 3)
            RoundedRectangle(cornerRadius: Theme.cardRadius + 8)
                .fill(Color(hex: 0x3A4A80))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius + 8).strokeBorder(Theme.feltText.opacity(0.6), lineWidth: 1.5))
                .frame(width: sf.width, height: sf.height)
                .offset(x: sf.minX, y: sf.minY)
            ForEach(0..<Board.count, id: \.self) { p in
                let f = BoardLayout.frame(p)
                EmptyCell(p: p, noCrib: state?.dealer == false).offset(x: f.minX, y: f.minY)
            }
            // Each card is keyed by its ID, so a card that falls or swaps slides to its new cell,
            // new cards drop in from above, and cleared cards shrink away.
            ForEach(placed, id: \.card.id) { item in
                let p = item.p, f = BoardLayout.frame(p)
                CellView(p: p, card: item.card, look: look(p, state, lit)).equatable()
                    // Placed with .offset, not .position: moving a card is then drawing-only, with no
                    // layout pass for the window on every frame (the main cause of choppy moves).
                    .frame(width: Theme.cardW, height: Theme.cardH)
                    .offset(x: f.minX, y: f.minY)
                    .zIndex(session.selection.contains(p) || session.flash.contains(p) ? 1 : 0)
                    .transition(.asymmetric(
                        insertion: .offset(y: Board.isGrid(p) ? -CGFloat(max(1, session.drawnPerColumn[p % 4])) * BoardLayout.pitchY : 0).combined(with: .opacity),
                        // The view's frame sits at the board's origin, so the anchor points at the card's offset centre.
                        removal: .scale(scale: 0.2, anchor: UnitPoint(x: f.midX / Theme.cardW, y: f.midY / Theme.cardH)).combined(with: .opacity)))
            }
        }
        .frame(width: BoardLayout.width, height: BoardLayout.height, alignment: .topLeading)
        .overlay(alignment: .topLeading) { BreakdownOverlay(pb: session.playback) }
        .contentShape(Rectangle())
        .gesture(drag)
        .onContinuousHover { phase in
            if case .active = phase, session.mode == .bomb { NSCursor.crosshair.set() } else { NSCursor.arrow.set() }
        }
    }

    private func look(_ p: Pos, _ state: MatchState?, _ lit: Set<Pos>) -> CellLook {
        let pb = session.playback
        let inset = pb.set.contains(p)
        let level = Board.isEdge(p) ? (pb.chipLevel[p] ?? state?.power[p] ?? 0) : 0
        return CellLook(order: session.selection.firstIndex(of: p), used: lit.contains(p),
                        hit: session.flash.contains(p), bomb: session.flashIsBomb,
                        inset: inset, dimmed: pb.active && !pb.set.isEmpty && !inset,
                        lit: pb.lit.contains(p), litPower: pb.litPower.contains(p), left: pb.leftOver.contains(p),
                        away: pb.row.contains(p), armedSource: session.armedSource == p,
                        chipText: level > 0 ? session.multiplierText(level) : nil, chipPulse: pb.litPower.contains(p))
    }

    private var placed: [(p: Pos, card: Card)] {
        guard let cells = session.state?.cells else { return [] }
        return (0..<Board.count).compactMap { p in cells[p].map { (p, $0) } }
    }

    /// A word tag under a point: tapping HAND, CRIB or STARTER explains it.
    private func tagHit(_ pt: CGPoint) -> InfoTopic? {
        let tags: [(Pos, InfoTopic)] = [(Board.hand.lowerBound, .hand), (Board.crib.lowerBound, .crib), (Board.starter, .starter)]
        for (p, topic) in tags where session.state?.cells[p] != nil {
            let f = BoardLayout.frame(p)
            if CGRect(x: f.midX - 40, y: f.minY - 20, width: 80, height: 24).contains(pt) { return topic }
        }
        return nil
    }

    /// The position under a point; a swipe must land near the card's centre.
    private func hit(_ pt: CGPoint, strict: Bool) -> Pos? {
        for p in 0..<Board.count where session.state?.cells[p] != nil {
            let f = BoardLayout.frame(p), s = strict ? hitFraction : 1
            if f.insetBy(dx: f.width * (1 - s) / 2, dy: f.height * (1 - s) / 2).contains(pt) { return p }
        }
        return nil
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard !session.blocked else { return }
                let far = hypot(v.translation.width, v.translation.height) > 6
                if !dragging {
                    dragging = true; moved = false
                }
                if far && !moved {
                    moved = true
                    // A drag starts a fresh trace from the card it began on.
                    session.selection = hit(v.startLocation, strict: false).map { [$0] } ?? []
                }
                guard moved, let p = hit(v.location, strict: true) else { return }
                var sel = session.selection
                if sel.isEmpty { sel = [p] }
                else if sel.count >= 2 && sel[sel.count - 2] == p { sel.removeLast() }   // back up
                else if !sel.contains(p), Board.touching(sel.last!, p), canAdd(p, to: sel) { sel.append(p) }
                if sel != session.selection { session.selection = sel }
            }
            .onEnded { v in
                dragging = false
                guard !session.blocked else { session.selection = []; return }
                if moved {
                    if session.selection.count >= 2 { session.submit(session.selection) }
                    session.selection = []
                    return
                }
                if let topic = tagHit(v.location) { session.selection = []; session.info = topic; return }
                guard let p = hit(v.location, strict: false), let card = session.state?.cells[p] else { session.selection = []; return }
                tap(p, card)
            }
    }

    /// Whether a card fits under the card counter (a joining starter is free).
    private func canAdd(_ p: Pos, to sel: [Pos]) -> Bool {
        guard let t = session.turn else { return false }
        return (p == Board.starter && t.starterJoins) || t.picked(sel).count < t.pickLimit
    }

    private func tap(_ p: Pos, _ card: Card) {
        var sel = session.selection
        if session.mode == .bomb { session.submit([p]); session.selection = []; return }
        if card.isSpecial, session.mode == .trace, case .special(let kind) = card.kind { session.selection = []; session.arm(kind, from: p); return }
        if sel.last == p {
            if sel.count >= 2 { session.submit(sel) }
            sel = []
        } else if let i = sel.firstIndex(of: p) {
            sel.removeSubrange(i...)
        } else if sel.isEmpty || Board.touching(sel.last!, p) {
            guard canAdd(p, to: sel) else { session.show("A set picks \(session.pickLimit) cards at most"); return }
            sel.append(p)
        } else {
            sel = [p]
        }
        session.selection = sel
    }
}

/// An empty cell's dashed outline; crib slots say "no crib" when you aren't the dealer.
struct EmptyCell: View {
    let p: Pos
    let noCrib: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius)
            .strokeBorder(Theme.feltText.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .overlay { if Board.crib.contains(p) && noCrib { Text("no crib").font(Theme.font(11)).foregroundStyle(Theme.feltText).opacity(0.5) } }
            .frame(width: Theme.cardW, height: Theme.cardH)
    }
}

/// Everything a cell shows besides its card, as plain values, so SwiftUI redraws only the
/// cells whose look changed (reading the session in each cell redrew all 25 on every change).
struct CellLook: Equatable {
    var order: Int?
    var used = false, hit = false, bomb = false
    var inset = false, dimmed = false, lit = false, litPower = false, left = false
    /// The card has flown up into the breakdown's row; its cell shows empty.
    var away = false
    var armedSource = false
    var chipText: String?
    var chipPulse = false
}

/// One cell, styled like the mock's .cell: edge ring, tags, power chip, made star,
/// selection ring and order, and the brighter "used" look for cards in a combo.
/// Tags, chips and badges are attached before the lift and scale, so they move with the card.
struct CellView: View, Equatable {
    let p: Pos
    let card: Card
    let look: CellLook

    var body: some View {
        let l = look
        let selected = l.order != nil
        let edge = Board.isEdge(p), starter = p == Board.starter
        let glow: Color? = l.hit ? (l.bomb ? Color(hex: 0xE00000, opacity: 0.85) : Theme.gold.opacity(0.9))
            : l.lit ? Theme.gold.opacity(0.85) : l.litPower ? Theme.power.opacity(0.8) : l.left ? Color(hex: 0xFF5A5A, opacity: 0.7)
            : l.used ? .white.opacity(0.55) : nil
        CardFace(card: card)
            .overlay {   // dimming and the "used" brightening: plain overlays, not colour filters
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .fill(l.dimmed ? Theme.felt.opacity(0.72) : l.used ? Color.white.opacity(0.08) : .clear)
            }
            .overlay {   // rings sit outside the card, like the mock's box-shadow rings
                let w: CGFloat = l.used || l.armedSource ? 3 : 2
                let colour: Color = selected || l.armedSource ? .white : starter ? Theme.feltText : edge ? Theme.gold : .clear
                RoundedRectangle(cornerRadius: Theme.cardRadius + w / 2).stroke(colour, lineWidth: w).padding(-w / 2)
            }
            .overlay {   // the pop before a bombed card clears, and the breakdown's rings
                let ring: Color? = l.hit || (l.inset && !l.lit && !l.litPower && !l.left) ? .white
                    : l.lit ? Theme.gold : l.litPower ? Theme.power : l.left ? Color(hex: 0xFF5A5A) : nil
                if let ring { RoundedRectangle(cornerRadius: Theme.cardRadius + 1.5).stroke(ring, lineWidth: 3).padding(-1.5) }
            }
            .background {   // steady looks without blur: a soft gold halo on edge cards, a hard drop shadow when raised
                if edge && !selected && !l.hit {
                    RoundedRectangle(cornerRadius: Theme.cardRadius + 4).stroke(Theme.gold.opacity(0.22), lineWidth: 4).padding(-4)
                }
                if selected || starter {
                    RoundedRectangle(cornerRadius: Theme.cardRadius).fill(.black.opacity(0.35)).offset(y: 4)
                }
            }
            .rotationEffect(starter ? .degrees(-5) : .zero)
            .overlay(alignment: .top) { tag }
            .overlay(alignment: .topTrailing) { chip }
            .overlay(alignment: .topLeading) {
                if card.kind == .made { badge("★", Theme.gold, Theme.ink, 16).offset(x: -5, y: -5) }
            }
            .overlay(alignment: .bottomLeading) {
                if let order = l.order { badge("\(order + 1)", .white, Theme.felt, 18).offset(x: -4, y: 4) }
            }
            // One blurred glow, and only while a card is lit, popped or in a combo.
            .shadow(color: glow ?? .clear, radius: glow == nil ? 0 : (l.hit ? 10 : 9))
            .scaleEffect(l.hit ? (l.bomb ? 1.18 : 1.12) : l.lit || l.litPower ? 1.06 : l.used ? 1.1 : selected ? 1.04 : 1)
            .offset(y: l.lit || l.litPower ? -8 : l.inset ? -4 : l.used ? -4 : selected ? -2 : l.armedSource ? -6 : 0)
            .animation(.easeOut(duration: Motion.t(0.12)), value: selected)
            .animation(.easeOut(duration: Motion.t(0.12)), value: l.used)
            .animation(.spring(duration: Motion.t(0.3), bounce: 0.4), value: l.hit)
            .opacity(l.away ? 0 : 1)
    }

    /// Word tags: one on the first hand card, the top crib card and the starter.
    @ViewBuilder private var tag: some View {
        let text: String? = p == Board.starter ? "STARTER" : p == Board.hand.lowerBound ? "HAND" : p == Board.crib.lowerBound ? "CRIB" : nil
        if let text {
            Text(text).font(Theme.font(10, .bold)).tracking(0.8).padding(.horizontal, 6).frame(height: 16)
                .background(Capsule().fill(p == Board.starter ? Theme.feltText : Theme.gold))
                .foregroundStyle(p == Board.starter ? Theme.felt : Theme.ink)
                // With a power chip on the right, the tag moves left so both read.
                .offset(x: look.chipText != nil ? -10 : 0, y: -10)
        }
    }

    /// The power chip: this card's multiplier once it has a level.
    @ViewBuilder private var chip: some View {
        if let text = look.chipText {
            Text(text).font(Theme.font(12, .bold)).padding(.horizontal, 6).frame(height: 18)
                .background(Capsule().fill(look.chipPulse ? Theme.power : Theme.gold)).foregroundStyle(Theme.ink)
                .scaleEffect(look.chipPulse ? 1.5 : 1).offset(x: 6, y: -6)
        }
    }

    private func badge(_ text: String, _ bg: Color, _ fg: Color, _ size: CGFloat) -> some View {
        Text(text).font(Theme.font(size * 0.62, .bold)).frame(width: size, height: size).background(Circle().fill(bg)).foregroundStyle(fg)
    }
}
