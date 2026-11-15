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
            EdgeBackground(dealer: state?.dealer ?? true).stroke(Theme.cyan.opacity(0.45), lineWidth: 1)
                .shadow(color: Theme.cyan.opacity(0.6), radius: 4)
            ForEach(0..<Board.count, id: \.self) { p in
                let f = BoardLayout.frame(p)
                EmptyCell(p: p, noCrib: state?.dealer == false).position(x: f.midX, y: f.midY)
            }
            // Each card is keyed by its ID, so a card that falls or swaps slides to its new cell,
            // new cards drop in from above, and cleared cards shrink away.
            ForEach(placed, id: \.card.id) { item in
                let p = item.p, f = BoardLayout.frame(p)
                CellView(p: p, card: item.card, state: state, order: session.selection.firstIndex(of: p),
                         used: lit.contains(p), hit: session.flash.contains(p), bomb: session.flashIsBomb, session: session)
                    .position(x: f.midX, y: f.midY)
                    .zIndex(session.selection.contains(p) || session.flash.contains(p) ? 1 : 0)
                    .transition(.asymmetric(
                        insertion: .offset(y: Board.isGrid(p) ? -CGFloat(max(1, session.drawnPerColumn[p % 4])) * BoardLayout.pitchY : 0).combined(with: .opacity),
                        // .position fills the board, so the shrink is anchored on the card's own centre.
                        removal: .scale(scale: 0.2, anchor: UnitPoint(x: f.midX / BoardLayout.width, y: f.midY / BoardLayout.height)).combined(with: .opacity)))
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

    private var placed: [(p: Pos, card: Card)] {
        guard let cells = session.state?.cells else { return [] }
        return (0..<Board.count).compactMap { p in cells[p].map { (p, $0) } }
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
                guard !session.over, !session.busy, session.warning == nil else { return }
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
                else if !sel.contains(p), Board.touching(sel.last!, p), sel.count < (session.config?.rules.match.maxSet ?? 5) { sel.append(p) }
                if sel != session.selection { session.selection = sel }
            }
            .onEnded { v in
                dragging = false
                guard !session.over, !session.busy, session.warning == nil else { session.selection = []; return }
                if moved {
                    if session.selection.count >= 2 { session.submit(session.selection) }
                    session.selection = []
                    return
                }
                guard let p = hit(v.location, strict: false), let card = session.state?.cells[p] else { session.selection = []; return }
                tap(p, card)
            }
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

/// One cell, styled like the mock's .cell: edge ring, tags, power chip, made star,
/// selection ring and order, and the brighter "used" look for cards in a combo.
struct CellView: View {
    let p: Pos
    let card: Card
    let state: MatchState?
    let order: Int?
    let used: Bool
    var hit = false
    var bomb = false
    let session: GameSession

    var body: some View {
            let pb = session.playback
            let inset = pb.set.contains(p), dimmed = pb.active && !pb.set.isEmpty && !inset
            let lit = pb.lit.contains(p), litPower = pb.litPower.contains(p), left = pb.leftOver.contains(p)
            let selected = order != nil
            let edge = Board.isEdge(p), starter = p == Board.starter
            let armedSource = session.armedSource == p
            CardFace(card: card)
                .overlay {   // rings sit outside the card, like the mock's box-shadow rings
                    let w: CGFloat = used || armedSource ? 3 : 2
                    let colour: Color = selected || armedSource ? .white : starter ? Theme.feltText : edge ? Theme.gold : .clear
                    RoundedRectangle(cornerRadius: Theme.cardRadius + w / 2).stroke(colour, lineWidth: w).padding(-w / 2)
                }
                .overlay {   // the pop before a bombed card clears, and the breakdown's rings
                    let ring: Color? = hit || (inset && !lit && !litPower && !left) ? .white : lit ? Theme.gold : litPower ? Theme.power : left ? Color(hex: 0xFF5A5A) : nil
                    if let ring { RoundedRectangle(cornerRadius: Theme.cardRadius + 1.5).stroke(ring, lineWidth: 3).padding(-1.5) }
                }
                .shadow(color: lit ? Theme.gold.opacity(0.85) : litPower ? Theme.power.opacity(0.8) : left ? Color(hex: 0xFF5A5A, opacity: 0.7) : .clear, radius: 9)
                .shadow(color: Board.isEdge(p) && !selected && !hit ? Theme.gold.opacity(0.45) : .clear, radius: 4)
                .brightness(used ? 0.06 : 0)
                .shadow(color: hit ? (bomb ? Color(hex: 0xE00000, opacity: 0.85) : Theme.gold.opacity(0.9)) : used ? .white.opacity(0.55) : .clear, radius: hit ? 10 : 8)
                .shadow(color: .black.opacity(selected || starter ? 0.33 : 0), radius: 4, y: 4)
                .scaleEffect(hit ? (bomb ? 1.18 : 1.12) : lit || litPower ? 1.06 : used ? 1.1 : selected ? 1.04 : 1)
                .offset(y: lit || litPower ? -8 : inset ? -4 : used ? -4 : selected ? -2 : armedSource ? -6 : 0)
                .opacity(dimmed ? 0.28 : 1)
                .saturation(dimmed ? 0.4 : 1)
                .rotationEffect(starter ? .degrees(-5) : .zero)
                .overlay(alignment: .top) { tag }
                .overlay(alignment: .topTrailing) { chip }
                .overlay(alignment: .topLeading) {
                    if card.kind == .made { badge("★", Theme.gold, Theme.ink, 16).offset(x: -5, y: -5) }
                }
                .overlay(alignment: .bottomLeading) {
                    if let order { badge("\(order + 1)", .white, Theme.felt, 18).offset(x: -4, y: 4) }
                }
                .animation(.easeOut(duration: 0.12), value: selected)
                .animation(.easeOut(duration: 0.12), value: used)
                .animation(.spring(duration: 0.3, bounce: 0.4), value: hit)
    }

    /// Word tags: one on the first hand card, the top crib card and the starter.
    @ViewBuilder private var tag: some View {
        let text: String? = p == Board.starter ? "STARTER" : p == Board.hand.lowerBound ? "HAND" : p == Board.crib.lowerBound ? "CRIB" : nil
        if let text {
            Text(text).font(Theme.font(10, .bold)).tracking(0.8).padding(.horizontal, 6).frame(height: 16)
                .background(Capsule().fill(p == Board.starter ? Theme.feltText : Theme.gold))
                .foregroundStyle(p == Board.starter ? Theme.felt : Theme.ink)
                // With a power chip on the right, the tag moves left so both read.
                .offset(x: hasChip ? -10 : 0, y: -10)
        }
    }

    private var hasChip: Bool { Board.isEdge(p) && (session.playback.chipLevel[p] ?? state?.power[p] ?? 0) > 0 }

    /// The power chip: this card's multiplier once it has a level.
    @ViewBuilder private var chip: some View {
        if Board.isEdge(p), let level = session.playback.chipLevel[p] ?? state?.power[p], level > 0 {
            let pulse = session.playback.litPower.contains(p)
            Text(session.multiplierText(level)).font(Theme.font(12, .bold)).padding(.horizontal, 6).frame(height: 18)
                .background(Capsule().fill(pulse ? Theme.power : Theme.gold)).foregroundStyle(Theme.ink)
                .scaleEffect(pulse ? 1.5 : 1).offset(x: 6, y: -6)
        }
    }

    private func badge(_ text: String, _ bg: Color, _ fg: Color, _ size: CGFloat) -> some View {
        Text(text).font(Theme.font(size * 0.62, .bold)).frame(width: size, height: size).background(Circle().fill(bg)).foregroundStyle(fg)
    }
}
