// The maze scene (ui.md › Scene: Maze): the header, the board, the status line, your plays as a
// fan, the play sheet, the power jokers tray, and the cards that cover it: tap to explain, the
// hazard pause, event cards, the duel and the game's end.
import CardKit
import CribMaze
import SwiftUI

struct MazeView: View {
    let session: GameSession
    var scene: MazeScene { session.mazeScene }
    static let kinds = ["swapper", "bomb", "reach", "burn", "key"]
    static let jokerTips = [
        "swapper": "Swapper: trade places with another player, not the same pair twice a hand",
        "bomb": "Bomb: a door within 10 steps opens (12 or less left) or loses 12; or a mine on another player's way",
        "reach": "Reach: your next play picks its way at every junction",
        "burn": "Burn: a fire on another player's way: the next token through loses plays",
        "key": "Key: works by itself, letting one walk through a door of another suit",
    ]

    var body: some View {
        GeometryReader { g in
            let side = g.size.width - 32
            VStack(alignment: .leading, spacing: 8) {
                header
                MazeBoardView(scene: scene, side: side)
                    .overlay(alignment: .bottom) { if let t = scene.tip { TipCard(tip: t) { scene.tip = nil }.padding(10) } }
                    .overlay { if let h = scene.hazard { HazardCard(pop: h) } }
                Text(scene.status).font(Theme.font(14, .medium)).foregroundStyle(Theme.feltText.opacity(0.9))
                    .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                Text("YOUR PLAYS · \(scene.myPlays.count) LEFT · \(scene.myPlays.reduce(0) { $0 + $1.steps }) STEPS")
                    .font(Theme.font(11, .bold)).tracking(0.8).opacity(0.75)
                PlayFan(scene: scene, width: side).frame(height: 86)
                tray
                if scene.mode == .swapper, scene.myTurn, let m = scene.engine {
                    HStack {
                        ForEach(m.tokens.indices.filter { $0 != 0 }, id: \.self) { q in
                            MazeButton(title: "Swap with \(scene.name(q))", solid: true, enabled: m.canSwap(0, q)) { scene.swap(with: q) }
                        }
                        MazeButton(title: "Cancel", solid: false) { scene.mode = .none }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.top, 18)
            .overlay(alignment: .bottom) { if scene.myTurn, !scene.afterPlay, let p = scene.selectedPlay { PlaySheet(scene: scene, play: p).padding(.horizontal, 12).padding(.bottom, 24) } }
        }
        .foregroundStyle(Theme.feltText)
        .background(Theme.felt)
        .overlay { if let c = scene.card { EventCardView(card: c) { if c.button != nil { scene.nextHand() } else { scene.dismiss() } } } }
        .overlay { if let d = scene.duel { DuelView(scene: scene, duel: d) } }
        .overlay { if let e = scene.ended { EndCard(session: session, ended: e) } }
        .overlay { Toast(text: session.toast) }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("HAND \(scene.hand)").font(Theme.font(11, .bold)).tracking(0.8).padding(.horizontal, 7).frame(height: 20)
                .background(Capsule().fill(Theme.feltText)).foregroundStyle(Theme.felt)
            if let m = scene.shown {
                let costs = m.tokens.indices.map { s in scene.position(s).map { scene.field.indices.contains($0) ? scene.field[$0] : 0 } ?? 0 }
                ForEach(m.tokens.indices, id: \.self) { s in
                    let place = 1 + costs.filter { $0 < costs[s] }.count
                    HStack(spacing: 5) {
                        Canvas { ctx, size in
                            let p = MazeArt.tokenPath(s, CGPoint(x: size.width / 2, y: size.height / 2), 6)
                            ctx.fill(p, with: .color(MazeInk.token(s))); ctx.stroke(p, with: .color(.white), lineWidth: 1.5)
                        }.frame(width: 16, height: 16)
                        Text(["1st", "2nd", "3rd"][min(place, 3) - 1]).font(Theme.font(13, .bold))
                        Text("\(min(100, Int((100 * Double(costs[s]) / Double(scene.startCost)).rounded())))%").font(Theme.font(13, .medium)).monospacedDigit().opacity(0.8)
                    }
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(Capsule().fill(Theme.panel))
                    .overlay(Capsule().strokeBorder(m.turn == s && scene.ended == nil ? Theme.gold : Theme.rim, lineWidth: m.turn == s ? 1.5 : 1))
                    .contentShape(Capsule())
                    .onTapGesture { scene.tip = scene.explain(seat: s) }
                    .help("\(scene.name(s)): place, and the share of the way still to go")
                }
            }
            Spacer()
        }
    }

    // MARK: Tray

    private var tray: some View {
        let mine = scene.shown?.tokens.first
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Self.kinds, id: \.self) { k in
                    TrayCard(kind: k, count: mine?.jokers[k, default: 0] ?? 0, w: 50,
                             armed: (scene.mode == .bomb && k == "bomb") || (scene.mode == .burn && k == "burn") || (scene.mode == .swapper && k == "swapper") || (k == "reach" && mine?.reach == true),
                             tip: Self.jokerTips[k]) { scene.tapJoker(k) }
                        .opacity(scene.canJoker(k) || (mine?.jokers[k, default: 0] ?? 0) == 0 || k == "key" ? 1 : 0.55)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 8) {
                Text(trayNote).font(Theme.font(12, .medium)).opacity(0.8).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if scene.afterPlay { MazeButton(title: "End turn", solid: true) { scene.endTurn() } }
            }
            .frame(minHeight: 26)
        }
        .padding(.horizontal, 8).padding(.top, 18).padding(.bottom, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.violet.opacity(0.5), lineWidth: 1))
        .overlay(alignment: .top) {
            Text("POWER JOKERS").font(Theme.font(10, .bold)).tracking(0.8).padding(.horizontal, 6).frame(height: 16)
                .background(Capsule().fill(Theme.violet)).foregroundStyle(Theme.felt).offset(y: -8)
        }
        .padding(.top, 6)
    }

    private var trayNote: String {
        let reach = scene.shown?.tokens.first?.reach == true ? "Reach is on: your next play picks its ways · " : ""
        if scene.engine?.jokerUsed == true && scene.engine?.turn == 0 { return reach + "Joker used this turn" }
        if scene.afterPlay { return reach + "Play a joker now, or end your turn" }
        return reach + "One a turn, before or after your play"
    }
}

/// Your plays as a fan of small cream cards: steps over suit. Tap one to open its sheet.
struct PlayFan: View {
    let scene: MazeScene
    let width: CGFloat
    var body: some View {
        let plays = scene.myPlays, n = plays.count, f = fx.maze.fan
        // Inset from the edges, so the outer cards' turn stays on the phone.
        let inner = width - 28, cw = CGFloat(f.cardW), gap = n > 1 ? min(cw + 4, (inner - cw) / CGFloat(n - 1)) : 0
        let x0 = (width - (cw + gap * CGFloat(max(0, n - 1)))) / 2
        let off = !scene.myTurn || scene.afterPlay
        ZStack(alignment: .topLeading) {
            ForEach(Array(plays.enumerated()), id: \.element.id) { k, p in
                let mid = Double(k) - Double(n - 1) / 2
                PlayTile(play: p, width: cw, corner: true)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(scene.selected == p.id ? Theme.gold : .clear, lineWidth: 3).padding(-2))
                    .rotationEffect(.degrees(n > 1 ? mid * min(f.maxTurn, 36 / Double(n)) : 0), anchor: UnitPoint(x: 0.5, y: 1.2))
                    .offset(x: x0 + CGFloat(k) * gap, y: CGFloat(abs(mid) * abs(mid) * 0.35 + 4) - (scene.selected == p.id ? 10 : 0))
                    .onTapGesture { scene.select(p.id) }
                    .help(p.cards.compactMap { Card.parse($0.card)?.face }.joined(separator: " ") + " (\(p.from))")
            }
        }
        .frame(width: width, height: 86, alignment: .topLeading)
        .opacity(off ? 0.45 : 1)
        .animation(fx.motions.board.select.animation(), value: scene.selected)
    }
}

/// A play: steps over its suit, on a cream card.
struct PlayTile: View {
    let play: MazePlay
    var width: CGFloat = 52
    /// In the fan, steps and suit sit in the top left corner, so overlapped cards still show them.
    var corner = false
    var body: some View {
        let suit = play.suit.flatMap { Suit(letter: $0) }
        VStack(alignment: corner ? .leading : .center, spacing: corner ? 2 : 0) {
            Text("\(play.steps)").font(Theme.font(width * (corner ? 0.36 : 0.44), .bold)).monospacedDigit()
            Text(suit?.textGlyph ?? "–").font(.system(size: width * (corner ? 0.3 : 0.34))).foregroundStyle(suit?.colour ?? Theme.soft).padding(.leading, corner ? 1 : 0)
        }
        .padding(.leading, corner ? 5 : 0).padding(.top, corner ? 5 : 0)
        .foregroundStyle(Theme.ink)
        .frame(width: width, height: width * 1.4, alignment: corner ? .topLeading : .center)
        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.face).shadow(color: .black.opacity(0.4), radius: 2, y: 2))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.rule, lineWidth: 1))
    }
}

/// The play sheet: the play's tile and cards, and its three uses (or the switches, or the close prompt).
struct PlaySheet: View {
    let scene: MazeScene
    let play: MazePlay
    var body: some View {
        let suit = play.suit.flatMap { Suit(letter: $0) }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                PlayTile(play: play, width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(play.steps) steps · \(suit.map { $0.textGlyph } ?? "no suit")").font(Theme.font(16, .bold))
                    Text(play.cards.compactMap { Card.parse($0.card)?.face }.joined(separator: " ") + "  ·  " + (play.from == "set" ? "a grid set" : "your \(play.from) count"))
                        .font(Theme.font(13, .regular)).opacity(0.75)
                }
                Spacer()
                MazeButton(title: "✕ Cancel", solid: false) { scene.cancel() }
            }
            switch scene.mode {
            case .flip:
                if let m = scene.engine {
                    ForEach(m.board.switches.indices, id: \.self) { k in
                        row(Maze.letters[k], "Flip switch \(Maze.letters[k])", m.canFlip(k) ? "Swap its open and shut passages, for everyone" : "Already flipped this hand", ok: m.canFlip(k)) { scene.flip(Maze.letters[k]) }
                    }
                }
                row("‹", "Back", "", ok: true) { scene.mode = .none }
            case .close:
                row("▭", "Tap a path on the maze", "It becomes a \(scene.glyph(play.suit))\(strength) door. Tap here to go back", ok: true, on: true) { scene.mode = .none }
            default:
                row("▶", "Walk \(play.steps) steps", walkNote, ok: true, on: true) { scene.walk() }
                row("▭", "Close a door", closeWhy ?? "Put a \(scene.glyph(play.suit))\(strength) door on an open path", ok: closeWhy == nil) { scene.mode = .close }
                row("⇄", "Flip a switch", flipWhy ?? "Swap a switch's open and shut passages", ok: flipWhy == nil) { scene.mode = .flip }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel).shadow(color: .black.opacity(0.6), radius: 14, y: 6))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
    }

    private var strength: Int {
        let c = scene.config?.close
        return max(c?.min ?? 2, (play.steps * (c?.mulPercent ?? 100) + 50) / 100)
    }
    private var closeWhy: String? {
        guard let m = scene.engine else { return "" }
        if play.suit == nil { return "A play with no suit can't make a door" }
        if m.tokens[0].closed >= (scene.config?.close.perRound ?? 1) { return "You've closed a door this hand" }
        return nil
    }
    private var flipWhy: String? {
        guard let m = scene.engine else { return "" }
        if m.board.switches.isEmpty { return "No switches on this maze" }
        if !m.board.switches.indices.contains(where: m.canFlip) { return "Every switch was flipped this hand" }
        return nil
    }
    private var walkNote: String {
        guard let pv = scene.preview, let m = scene.engine else { return "" }
        if pv.walk.won { return "Reaches the goal!" }
        var s = "Ends \(pv.cost) from the goal"
        if !pv.walk.doors.isEmpty { s += pv.walk.doors.contains(where: \.broke) ? ", breaks a door" : ", hits a door" }
        if pv.walk.stopped { s += ", stopped by a door" }
        if pv.walk.key { s += ", a key gets it through" }
        for c in pv.walk.hazards {
            let kind = m.hazards.first { $0.cell == c }?.kind == "mine" ? "mine" : "fire"
            s += c == pv.walk.end ? ", stops on a \(kind)" : ", runs over a \(kind)"
        }
        if m.reachOn(0) { s += ". Reach: tap a ringed junction to change its way" }
        return s
    }

    private func row(_ icon: String, _ title: String, _ sub: String, ok: Bool, on: Bool = false, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(icon).font(Theme.font(16, .bold)).frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(on ? Theme.gold : Theme.felt)).foregroundStyle(on ? Theme.ink : Theme.feltText)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.font(15, .semibold))
                if !sub.isEmpty { Text(sub).font(Theme.font(12, .regular)).opacity(0.75).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.felt.opacity(0.6)))
        .opacity(ok ? 1 : 0.45)
        .contentShape(Rectangle())
        .onTapGesture { if ok { action() } }
    }
}

struct MazeButton: View {
    let title: String
    let solid: Bool
    var enabled = true
    let action: () -> Void
    var body: some View {
        Text(title).font(Theme.font(14, .semibold)).padding(.horizontal, 12).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(solid ? Theme.feltText : .clear))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(solid ? .clear : Theme.feltText.opacity(0.4), lineWidth: 1))
            .foregroundStyle(solid ? Theme.felt : Theme.feltText)
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Rectangle())
            .onTapGesture { if enabled { action() } }
    }
}

/// Tap to explain: what a spot on the board is.
struct TipCard: View {
    let tip: MazeScene.Tip
    let done: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(tip.lines.enumerated()), id: \.offset) { _, l in
                Text("\(Text(l.0).bold())\(l.1.isEmpty ? "" : " " + l.1)").font(Theme.font(14, .regular)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.paper).shadow(color: .black.opacity(0.5), radius: 10, y: 6))
        .contentShape(Rectangle()).onTapGesture(perform: done)
    }
}

/// The hazard pause: "FIRE!" or "BOOM!", what happened, and the plays lost burning out.
struct HazardCard: View {
    let pop: MazeScene.HazardPop
    @State private var burnt = false
    var body: some View {
        VStack(spacing: 8) {
            Text(pop.title).font(Theme.font(34, .heavy)).foregroundStyle(pop.fire ? Theme.flame : Theme.red)
                .shadow(color: (pop.fire ? Theme.flame : Theme.red).opacity(0.7), radius: 8)
            Text(pop.text).font(Theme.font(15, .semibold)).multilineTextAlignment(.center).foregroundStyle(Theme.ink)
            if !pop.lost.isEmpty {
                HStack(spacing: 6) {
                    ForEach(pop.lost, id: \.id) { p in
                        PlayTile(play: p, width: 36)
                            .overlay { RoundedRectangle(cornerRadius: 5).fill(Theme.red.opacity(burnt ? 0.55 : 0)) }
                            .opacity(burnt ? 0.25 : 1).scaleEffect(burnt ? 0.8 : 1)
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: 300)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.paper).shadow(color: .black.opacity(0.6), radius: 14, y: 8))
        .onAppear { withAnimation(.easeIn(duration: Motion.t(fx.maze.hazardBurn.ms / 1000)).delay(Motion.t(fx.maze.hazardBurn.delayMs / 1000))) { burnt = true } }
        .allowsHitTesting(false)
    }
}

/// The stir, plays owed, a bots' duel or the hand's end, until tapped.
struct EventCardView: View {
    let card: MazeScene.EventCard
    let done: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title).font(Theme.font(22, .bold))
                Text(card.text).font(Theme.font(15, .regular)).fixedSize(horizontal: false, vertical: true)
                Text(card.button ?? "OK").font(Theme.font(15, .semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.felt)).foregroundStyle(Theme.feltText).padding(.top, 4)
            }
            .foregroundStyle(Theme.ink)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.paper).shadow(color: .black.opacity(0.55), radius: 16, y: 12))
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle()).onTapGesture(perform: done)
    }
}

/// The game's end: who reached the goal, or who was closest after the last hand.
struct EndCard: View {
    let session: GameSession
    let ended: MazeScene.Ended
    var body: some View {
        let scene = session.mazeScene
        ZStack {
            Color.black.opacity(0.45)
            VStack(alignment: .leading, spacing: 10) {
                Text("GAME OVER").font(Theme.font(11, .bold)).tracking(0.8).opacity(0.7)
                Text(title).font(Theme.font(26, .bold)).foregroundStyle(ended.winner == 0 ? Theme.gold : Theme.cyan)
                    .shadow(color: (ended.winner == 0 ? Theme.gold : Theme.cyan).opacity(0.6), radius: 8)
                Text("Hand \(scene.hand). Seed \(String(session.seed)).").font(Theme.font(15, .regular)).opacity(0.8)
                HStack(spacing: 8) {
                    MazeButton(title: "Same seed", solid: false) { session.newGame(seed: session.seed) }
                    MazeButton(title: "New game", solid: true) { session.newGame() }
                }.padding(.top, 6)
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panel).shadow(color: .black.opacity(0.6), radius: 16, y: 10))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.rim, lineWidth: 1))
            .padding(.horizontal, 24)
        }
        .foregroundStyle(Theme.feltText)
    }
    private var title: String {
        let n = session.mazeScene.name(ended.winner)
        if ended.reason == "cap" { return ended.winner == 0 ? "You're closest to the goal after the last hand" : "\(n) is closest to the goal after the last hand" }
        return ended.winner == 0 ? "You reach the goal!" : "\(n) reaches the goal"
    }
}

/// A human's duel, full screen (maze.md › Duels › On screen).
struct DuelView: View {
    let scene: MazeScene
    let duel: MazeScene.DuelShow
    var body: some View {
        let me = duel.seats.firstIndex(of: 0) ?? 0, them = 1 - me
        let legal = scene.duelLegal
        let toPlay = scene.engine?.duel.map { $0.seats[$0.peg.turn] }
        VStack(spacing: 14) {
            Text("DUEL!").font(Theme.font(34, .heavy)).foregroundStyle(Theme.magenta).shadow(color: Theme.magenta.opacity(0.7), radius: 10)
            Text(why).font(Theme.font(15, .medium)).multilineTextAlignment(.center).opacity(0.85)
            HStack(spacing: 12) {
                score(duel.seats[me], duel.scores[me], toPlay: toPlay)
                score(duel.seats[them], duel.scores[them], toPlay: toPlay)
            }
            if let r = duel.result { result(r, me: duel.seats[me]) } else {
                HStack(spacing: -14) { ForEach(duel.hands[them], id: \.id) { _ in CardBack(width: 44) } }.frame(height: 62)
                VStack(spacing: 6) {
                    Text("Count \(duel.count)").font(Theme.font(18, .bold)).monospacedDigit()
                    HStack(spacing: -10) {
                        ForEach(Array(duel.run.enumerated()), id: \.offset) { _, x in
                            CardFace(card: x.card, width: 44).overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(MazeInk.token(x.seat), lineWidth: 2))
                        }
                    }.frame(height: 62)
                    Text(duel.said ?? " ").font(Theme.font(15, .semibold)).foregroundStyle(Theme.gold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
                HStack(spacing: 6) {
                    ForEach(duel.hands[me], id: \.id) { c in
                        CardFace(card: c, width: 60).opacity(legal.contains(c.id) ? 1 : 0.4)
                            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(legal.contains(c.id) ? Theme.gold : .clear, lineWidth: 2).padding(-2))
                            .onTapGesture { scene.duelPlay(c) }
                    }
                }.frame(height: 84)
                Text(legal.isEmpty ? " " : "Your card: tap one").font(Theme.font(14, .medium)).opacity(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22).padding(.top, 40).padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.overlay)
        .foregroundStyle(Theme.feltText)
    }

    private var why: String {
        let other = duel.seats.first { $0 != 0 }.map(scene.name) ?? ""
        if duel.why == "landing" {
            return duel.seats[0] == 0 ? "You landed on \(other)'s cell." : "\(scene.name(duel.seats[0])) landed on your cell."
        }
        return "Stuck: the winner's way opens, and takes the loser's biggest play."
    }

    private func score(_ seat: Int, _ points: Int, toPlay: Int?) -> some View {
        let won = duel.result?.winner == seat
        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                Canvas { ctx, size in
                    let p = MazeArt.tokenPath(seat, CGPoint(x: size.width / 2, y: size.height / 2), 7)
                    ctx.fill(p, with: .color(MazeInk.token(seat))); ctx.stroke(p, with: .color(.white), lineWidth: 1.5)
                }.frame(width: 18, height: 18)
                Text(scene.name(seat)).font(Theme.font(15, .semibold))
            }
            Text("\(points)").font(Theme.font(72, .bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(won ? Theme.magenta : (toPlay == seat && duel.result == nil ? Theme.gold : Theme.rim), lineWidth: won || toPlay == seat ? 3 : 1))
    }

    @ViewBuilder private func result(_ r: MazeScene.DuelShow.Result, me: Int) -> some View {
        VStack(spacing: 10) {
            Text(r.winner == 0 ? "You win" : "\(scene.name(r.winner)) wins").font(Theme.font(28, .bold))
                .foregroundStyle(r.winner == 0 ? Theme.gold : Theme.cyan)
            if r.coin { Text("Tied twice: a coin decides.").font(Theme.font(14, .regular)).opacity(0.8) }
            if let p = r.took {
                HStack(spacing: 10) {
                    Text(r.winner == 0 ? "+" : "−").font(Theme.font(54, .heavy)).foregroundStyle(r.winner == 0 ? Theme.clockGreen : Theme.clockRed)
                    PlayTile(play: p, width: 52)
                    Text(r.winner == 0 ? "You take their biggest play" : "\(scene.name(r.winner)) takes your biggest play").font(Theme.font(14, .medium)).frame(maxWidth: 140, alignment: .leading)
                }
            }
            if let o = r.opened {
                Text("The way opens: " + (["break": "the door on \(r.winner == 0 ? "your" : "their") way breaks", "fade": "the door ahead fades",
                                          "star": "a star falls ahead", "shift": "a wall opens"][o] ?? o) + ".").font(Theme.font(15, .medium))
            }
            if r.scores.count > 1 {
                Text("Games: " + r.scores.map { "\($0[duel.seats.firstIndex(of: 0) ?? 0]) to \($0[1 - (duel.seats.firstIndex(of: 0) ?? 0)])" }.joined(separator: ", ")).font(Theme.font(14, .regular)).opacity(0.8)
            }
            MazeButton(title: "Back to the maze", solid: true) { scene.dismiss() }.padding(.top, 6)
        }
        .padding(.top, 10)
    }
}
