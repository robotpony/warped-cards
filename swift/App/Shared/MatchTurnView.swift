import CardKit
import CribMaze
import CribbageKit
import SwiftUI

struct MatchTurnView: View {
    @Bindable var session: GameSession
    /// The phone's height as laid out (it's as tall as its content); an estimate until measured.
    @State private var phoneH: CGFloat = PhoneView.height

    var body: some View {
        if let err = session.loadError {
            ContentUnavailableView("Config didn't load", systemImage: "exclamationmark.triangle", description: Text(err))
        } else {
            // The phone is always drawn at its full size, so nothing reflows or gets cut off; on a
            // screen too short for it, the whole phone scales down. The window fits it exactly.
            let s = PhoneView.fitScale(phoneH)
            PhoneView(session: session)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { phoneH = $0 }
                .scaleEffect(s, anchor: .topLeading)
                .frame(width: PhoneView.width * s, height: phoneH * s, alignment: .topLeading)
                .padding(PhoneView.margin)
                .background(Theme.page)
            .background(FrameMeterHost(meter: session.meter))
        }
    }
}

/// The play screen, laid out like the mock's phone: top line, steps and stock, the
/// 121-step track, the board, the help line, the feed, then the tray and End turn.
struct PhoneView: View {
    let session: GameSession
    @State private var showSettings = false

    static let width: CGFloat = BoardLayout.width + 2 * 16 + 18
    static let height: CGFloat = 800   // a first guess; the phone is as tall as its content
    static let margin: CGFloat = 20

    /// 1, or less when the screen can't fit the phone plus the window's title bar and margins.
    @MainActor static func fitScale(_ h: CGFloat) -> CGFloat {
        guard let screen = NSScreen.main?.visibleFrame.height, h > 0 else { return 1 }
        return min(1, (screen - 32 - 2 * margin) / h)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tapping the header or the footer opens the settings; there's no gear.
            VStack(alignment: .leading, spacing: 10) { stepsRow; track }
                .contentShape(Rectangle()).onTapGesture { openSettings() }
            BoardView(session: session).padding(.top, 9).frame(maxWidth: .infinity)
            // What the trace would score, or what an armed joker or a dead board needs; empty otherwise.
            // The turn's log lives behind the gear.
            Text(session.pickMessage)
                .font(Theme.font(14, session.dead && session.selection.isEmpty && session.mode == .trace ? .semibold : .medium))
                .foregroundStyle(session.dead && session.selection.isEmpty && session.mode == .trace ? Theme.gold : Theme.feltText.opacity(0.9))
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20, alignment: .leading)
                .padding(.vertical, -4)   // one tight line, so the power jokers sit close under the board
            bottom   // power jokers, close under the board
                .hintBlink(session.hinting(.powerJokers))
            // The footer: the card counter and clock, on a lighter bar along the bottom edge.
            footer
                .padding(.horizontal, 30).padding(.top, 12).padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .background(Theme.panel)
                .overlay(alignment: .top) { Rectangle().fill(Theme.rim).frame(height: 1) }
                .contentShape(Rectangle()).onTapGesture { openSettings() }
                .help("Settings")
                .popover(isPresented: $showSettings, arrowEdge: .top) {
                    SidePanel(session: session).frame(width: 340, height: 620)
                }
                .padding(.horizontal, -16).padding(.top, 4)
        }
        .padding(.horizontal, 16).padding(.top, 14)
        .frame(width: Self.width)
        .coordinateSpace(.named("phone"))
        .overlay(alignment: .topLeading) { FlyView(pb: session.playback) }
        .foregroundStyle(Theme.feltText)
        .background(Theme.felt)
        .overlay {   // tap anywhere to skip the breakdown
            if session.playback.active {
                // A tap skips to the end of the breakdown; at the end, a tap moves on.
                Color.clear.contentShape(Rectangle()).onTapGesture { session.playback.tap() }
            }
        }
        .overlay { Toast(text: session.toast) }
        .overlay { if let left = session.warning { WarningCard(left: left, cost: session.config?.rules.match.leftOverCost ?? 2) { session.dismissWarning() } } }
        .overlay { if let topic = session.info { InfoCard(topic: topic, session: session) { session.info = nil } } }
        .overlay { if session.over { SummaryView(session: session) } }
        .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 42, style: .continuous).stroke(Color(hex: 0x111111), lineWidth: 10).padding(-5))
    }

    /// Settings, the last score, this turn's log and (in the beta) diagnostics.
    private func openSettings() { if !session.playback.active { showSettings = true } }

    private var footer: some View {
        HStack(alignment: .center) {
            // Tapping the counter explains it; the rest of the bar opens the settings.
            PickCounter(count: session.mode == .trace ? session.pickCount : 0, limit: session.pickLimit, leading: true)
                .contentShape(Rectangle())
                .onTapGesture { if !session.blocked { session.info = .counter } }
            Spacer()
            TurnClock(session: session)
        }
        .font(Theme.font(14, .medium)).opacity(0.9)
    }

    private var stepsRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.state?.steps ?? 0)").font(Theme.font(44, .bold)).contentTransition(.numericText())
                    .foregroundStyle(session.playback.bump ? Theme.gold : Theme.feltText)
                    .scaleEffect(session.playback.bump ? 1.25 : 1, anchor: .leading)
                    .animation(.snappy, value: session.state?.steps)
                    .onGeometryChange(for: CGPoint.self, of: { g in
                        let f = g.frame(in: .named("phone")); return CGPoint(x: f.minX + 24, y: f.midY)
                    }) { session.playback.stepsAt = $0 }
                Text("steps scored").font(Theme.font(13, .medium)).opacity(0.75)
            }
            Spacer()
            // The stock, face down; an empty outline once it runs out.
            HStack(spacing: 8) {
                // The stock's count sits on the deck in a gold badge.
                if (session.turn?.drawable ?? 0) > 0 {
                    CardBack(width: 46).overlay(alignment: .bottomTrailing) {
                        Text("\(session.turn?.drawable ?? 0)").font(Theme.font(13, .bold)).monospacedDigit()
                            .padding(.horizontal, 5).frame(minWidth: 24, minHeight: 22)
                            .background(Capsule().fill(Theme.gold).shadow(color: Theme.gold.opacity(0.5), radius: 3)).foregroundStyle(Theme.ink)
                            .offset(x: 8, y: 6)
                    }
                    .help("Cards left in the stock")
                }
                else { RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.feltText.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3])).frame(width: 46, height: 46 * 1.4) }
            }
        }
    }

    private var track: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.feltText.opacity(0.15))
                Capsule().fill(Theme.gold).frame(width: g.size.width * min(1, max(0, CGFloat(session.state?.steps ?? 0) / 121)))
                    .shadow(color: Theme.gold.opacity(0.7), radius: 3)
                    .animation(.easeOut(duration: Motion.t(0.4)), value: session.state?.steps)
            }
        }
        .frame(height: 6)
        .help("Progress along a 121-step main route")
    }

    private var bottom: some View {
        // Power jokers across the full width: one slot per known kind, then empty holes for
        // the kinds still to come. No End turn: the timer, or a board with no sets left, ends it.
        let known = session.config?.rules.specials.known ?? ["swapper", "bomb"]
        let slots = max(4, known.count)
        return HStack(spacing: 0) {
            ForEach(0..<slots, id: \.self) { i in
                Group {
                    if i < known.count {
                        let kind = known[i]
                        TrayCard(kind: kind, count: session.state?.tray[kind] ?? 0, w: 72,
                                 armed: session.mode == (kind == "swapper" ? .swap : .bomb) && session.armedSource == nil) {
                            tapTray(kind, kind == "swapper" ? .swap : .bomb)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.violet.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.felt.opacity(0.5)))
                            .frame(width: 72, height: 72 * 1.4)
                            .help("An empty slot for a power joker you haven't found yet")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
            .padding(.horizontal, 8).padding(.top, 20).padding(.bottom, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.violet.opacity(0.5), lineWidth: 1))
            .overlay(alignment: .top) {
                Text("POWER JOKERS").font(Theme.font(10, .bold)).tracking(0.8).padding(.horizontal, 6).frame(height: 16)
                    .background(Capsule().fill(Theme.violet)).foregroundStyle(Theme.felt).offset(y: -8)
                    .onTapGesture { if !session.blocked { session.info = .tray } }
            }
    }

    private func tapTray(_ kind: String, _ m: InputMode) {
        guard !session.over, (session.state?.tray[kind] ?? 0) > 0 else { return }
        if session.mode == m && session.armedSource == nil { session.disarm() } else { session.selection = []; session.arm(kind) }
    }
}

/// A special joker in the tray: a small card, a stack when there's more than one, and a count.
struct TrayCard: View {
    let kind: String, count: Int
    var w: CGFloat = 58
    let armed: Bool
    let action: () -> Void
    var body: some View {
        let card = Card(id: 0, kind: .special(kind), rank: 0, suit: nil)
        ZStack {
            if count > 1 {
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xA99E86)).frame(width: w, height: w * 1.4).offset(x: 6, y: -6)
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xCFC6B3)).frame(width: w, height: w * 1.4).offset(x: 3, y: -3)
            }
            CardFace(card: card, width: w)
                .overlay { if armed { RoundedRectangle(cornerRadius: 5.5).stroke(.white, lineWidth: 3).padding(-1.5) } }
                .shadow(color: armed ? .black.opacity(0.4) : .clear, radius: 6, y: 6)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(count)").font(Theme.font(12, .bold)).padding(.horizontal, 5).frame(minWidth: 20, minHeight: 20)
                .background(Capsule().fill(Theme.violet).shadow(color: Theme.violet.opacity(0.6), radius: 3)).foregroundStyle(Theme.felt).offset(x: 6, y: 6)
        }
        .offset(y: armed ? -10 : 0)
        .opacity(count < 1 ? 0.3 : 1)
        .animation(.easeOut(duration: Motion.t(0.12)), value: armed)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .help(kind == "swapper" ? "Swapper: reverses a straight line of 2 to 4 grid cards" : "Bomb: clears a card and its neighbours, without scoring")
    }
}

/// The first-time left-over warning (the mock's .warn card); play waits for "Got it".
struct WarningCard: View {
    let left: [String], cost: Int
    let done: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
            VStack(alignment: .leading, spacing: 8) {
                Text("Every card must score").font(Theme.font(22, .bold))
                Text("A set can hold one combo or several (7-8-8 is two fifteens and a pair), but every card you trace must be part of at least one: a fifteen, pair, run, flush or his nobs.")
                let bad = Text(left.joined(separator: " ")).foregroundStyle(Color(hex: 0xC00000)).bold()
                Text("Here, \(bad)\(left.count == 1 ? " isn't" : " aren't") part of any combo. While you trace, only cards in a combo light up.")
                let rule = Text("From now on, a set still scores its combos, but each card left over costs \(cost) step\(cost == 1 ? "" : "s").").bold()
                Text("\(rule) Your steps can go below 0. This time nothing happens.")
                Text("Got it").font(Theme.font(15, .semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.felt)).foregroundStyle(Theme.feltText)
                    .contentShape(Rectangle()).onTapGesture(perform: done).padding(.top, 4)
            }
            .font(Theme.font(15, .regular)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xFFFDF7)).shadow(color: .black.opacity(0.55), radius: 16, y: 12))
            .padding(.horizontal, 20)
        }
    }
}

/// The mock's toast: gold, centred a little above the middle.
struct Toast: View {
    let text: String?
    var body: some View {
        GeometryReader { g in
            if let text {
                Text(text).font(Theme.font(20, .bold)).multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: g.size.width - 40)
                    .position(x: g.size.width / 2, y: g.size.height * 0.46)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeOut(duration: Motion.t(0.2)), value: text)
        .allowsHitTesting(false)
    }
}

/// The end-of-turn overlay, over the whole screen like the mock's.
struct SummaryView: View {
    let session: GameSession
    var body: some View {
        let t = session.state?.totals
        VStack(alignment: .leading, spacing: 10) {
            Text(endTitle).font(Theme.font(24, .bold)).foregroundStyle(Theme.cyan).shadow(color: Theme.cyan.opacity(0.6), radius: 6)
            Text("\(session.state?.steps ?? 0) steps").font(Theme.font(48, .bold)).foregroundStyle(Theme.gold)
                .shadow(color: Theme.gold.opacity(0.6), radius: 10)
            if let t {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
                    row("Sets scored", "\(t.scores)")
                    row("Sets with 2 or more combos", "\(t.multis)")
                    row("Best set", t.best.map(String.init) ?? "none")
                    row("Steps from edge power", GameSession.signed(t.stepsFromEdgePower))
                    row("Cards left over", GameSession.signed(-(t.leftOverTotal + t.penaltyTotal)))
                    if t.clearBonus > 0 { row("Clear-board bonus", "+\(t.clearBonus)") }
                    row("Swaps, bombs", "\(t.swaps), \(t.bombs)")
                    row("Cards drawn", "\(t.drawn)")
                }.font(Theme.font(15, .regular))
            }
            if let prize { Text(prize).font(Theme.font(17, .semibold)).foregroundStyle(Theme.gold).padding(.top, 4) }
            Spacer()
            HStack(spacing: 8) {
                pbtn("Same seed", ghost: true) { session.newTurn(seed: session.seed) }
                pbtn("New turn", ghost: false) { session.newTurn() }
            }
        }
        .padding(.horizontal, 24).padding(.top, 70).padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.overlay)
        .foregroundStyle(Theme.feltText)
    }
    private var endTitle: String { ["player": "Turn over", "timer": "Time's up", "board_cleared": "Board cleared!"][session.state?.endReason ?? ""] ?? "Turn over" }
    private var prize: String? {
        for e in session.events.reversed() { if case .prizeWon(let tier, _, _, let special) = e { return "\(tier.capitalized) prize: a \(special)" } }
        return nil
    }
    private func row(_ a: String, _ b: String) -> some View {
        GridRow { Text(a); Text(b).fontWeight(.semibold).monospacedDigit().gridColumnAlignment(.trailing) }
    }
    private func pbtn(_ title: String, ghost: Bool, _ action: @escaping () -> Void) -> some View {
        Text(title).font(Theme.font(15, .semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(ghost ? .clear : Theme.feltText))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ghost ? Theme.feltText.opacity(0.4) : .clear, lineWidth: 1))
            .foregroundStyle(ghost ? Theme.feltText : Theme.felt)
            .contentShape(Rectangle()).onTapGesture(perform: action)
    }
}

/// The settings behind the gear, in three tabs: the game (next turn, the last score and this
/// turn's log), advanced options, and animation.
struct SidePanel: View {
    @Bindable var session: GameSession
    @State private var tab = Tab.game
    enum Tab: Hashable { case game, advanced, animation }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Edition.name).font(.headline)
                Text("Match turn, rules \(MatchTurn.rulesVersion), app \(version)").font(.caption).foregroundStyle(.secondary)
            }
            Picker("", selection: $tab) {
                Text("Game").tag(Tab.game); Text("Advanced").tag(Tab.advanced); Text("Animation").tag(Tab.animation)
            }
            .pickerStyle(.segmented).labelsHidden()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case .game: game
                    case .advanced: advanced
                    case .animation: animation
                    }
                }
            }
        }
        .padding(16)
        // Neon: the panel colours from palette.json, with the Mac's dark controls tinted cyan.
        .background(Theme.panel)
        .environment(\.colorScheme, .dark)
        .tint(Theme.cyan)
        .foregroundStyle(Theme.feltText)
    }

    @ViewBuilder private var game: some View {
        GroupBox("Next turn") {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Dealer: crib down the side", isOn: $session.settings.dealer)
                Toggle("\(session.config?.rules.match.timerSeconds ?? 180) s timer", isOn: $session.settings.timer)
                Toggle("Hints when you're stuck", isOn: $session.settings.hints)
                Picker("Hand", selection: $session.settings.hand) { Text("Random").tag("random"); Text("Strong (4♥ 5♣ 6♦ J♠, 5♠)").tag("strong") }
                HStack {
                    // The field shows this turn's seed; type another to replay it, or leave it blank for a random deal.
                    TextField("Seed", text: $session.seedText, prompt: Text("Seed \(String(session.seed)) · blank: random"))
                        .textFieldStyle(.roundedBorder).monospacedDigit().onSubmit { session.newTurn() }
                    Button("New turn") { session.newTurn() }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        if let b = session.breakdown {
            GroupBox("Last score: " + b.cards.joined(separator: " ")) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                    ForEach(Array(b.lines.enumerated()), id: \.offset) { _, l in GridRow { Text(l.0); Text("\(l.1)").monospacedDigit() } }
                    if b.percent > 100 { GridRow { Text("Edge power ×\(Double(b.percent) / 100, format: .number)"); Text("\(b.points + b.cost)").monospacedDigit() } }
                    if b.cost > 0 { GridRow { Text("\(b.leftOver) left over"); Text("−\(b.cost)").monospacedDigit() } }
                    Divider()
                    GridRow { Text("Steps").bold(); Text("\(b.points)").bold().monospacedDigit() }
                }.frame(maxWidth: .infinity, alignment: .leading).font(.callout)
            }
        }
        GroupBox("This turn") {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(session.feed.prefix(8)) { l in   // capped: the whole turn's list made each move slower
                    HStack(alignment: .firstTextBaseline) {
                        Text(l.text).font(.callout)
                        Spacer()
                        if let p = l.points { Text(p >= 0 ? "+\(p)" : "\(p)").monospacedDigit().foregroundStyle(p >= 0 ? Color.primary : Color.red) }
                    }
                }
                if session.feed.isEmpty { Text("Drag across 2 to \(session.pickLimit) touching cards.").foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var advanced: some View {
        GroupBox("Next turn") {
            Picker("Card budget", selection: $session.settings.budget) { Text("Whole stock").tag(0); Text("12").tag(12); Text("16").tag(16); Text("24").tag(24) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let url = session.savedRecord {
            Button("Show the turn record") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.buttonStyle(.link)
        }
        Text("How to play: drag across touching cards (diagonals count), or tap cards and tap the last again. Every set needs a grid card. Hand, crib and starter cards stay and power up.")
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder private var animation: some View {
        GroupBox("Score breakdown") {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Play each score's breakdown (tap to skip)", isOn: $session.settings.breakdown)
                Picker("Speed", selection: $session.timing.base) {
                    Text("Slow (1.2 s)").tag(1200.0); Text("Medium (0.9 s)").tag(900.0); Text("Quick (0.6 s)").tag(600.0); Text("Practised (0.4 s)").tag(400.0)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        if Edition.isBeta {
            GroupBox("Diagnostics") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Slow motion (5× slower)", isOn: $session.slowMotion)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("\(Int(session.meter.fps.rounded())) fps · \(session.meter.hitches) hitches during moves · worst \(Int(session.meter.worstMs)) ms")
                            .font(.callout.monospacedDigit())
                    }
                    Button("Reset count") { session.meter.reset() }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var version: String {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "?") (\(i?["CFBundleVersion"] as? String ?? "?"))"
    }
}

/// The card counter beside the help line: one pip per card a set may pick, lit as you pick them.
/// Room for more: a later rule can raise the limit for a while.
struct PickCounter: View {
    let count: Int, limit: Int
    var leading = false
    var body: some View {
        VStack(alignment: leading ? .leading : .trailing, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<limit, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < count ? (count == limit ? Theme.gold : Theme.cyan) : Theme.feltText.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.feltText.opacity(i < count ? 0 : 0.3), lineWidth: 1))
                        .frame(width: 9, height: 13)
                }
            }
            Text("CARDS \(count) / \(limit)").font(Theme.font(11, .bold)).tracking(0.6).monospacedDigit()
                .foregroundStyle(count == limit ? Theme.gold : Theme.feltText.opacity(0.75))
        }
        .animation(.easeOut(duration: Motion.t(0.12)), value: count)
        .contentShape(Rectangle())
        .help("How many cards a set can pick. The starter is free.")
    }
}

/// What a tapped tag or the card counter explains.
enum InfoTopic { case hand, crib, starter, tray, counter }

/// An info card over the board, like the left-over warning; play waits for "Got it".
struct InfoCard: View {
    let topic: InfoTopic
    let session: GameSession
    let done: () -> Void

    var body: some View {
        let (title, lines) = text
        ZStack {
            Color.black.opacity(0.25).contentShape(Rectangle()).onTapGesture(perform: done)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(Theme.font(22, .bold))
                ForEach(Array(lines.enumerated()), id: \.offset) { _, l in Text(l).fixedSize(horizontal: false, vertical: true) }
                Text("Got it").font(Theme.font(15, .semibold)).frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.felt)).foregroundStyle(Theme.feltText)
                    .contentShape(Rectangle()).onTapGesture(perform: done).padding(.top, 4)
            }
            .font(Theme.font(15, .medium))
            .padding(18)
            .frame(width: 340)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.face))
            .foregroundStyle(Theme.ink)
            .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
        }
    }

    private var text: (String, [String]) {
        let m = session.config?.rules.match
        let pct = m?.edgePower.percentPerLevel ?? 50
        let power = "Each time it scores, it powers up: every level multiplies the sets it's in by another ×\(session.multiplierText(percent: 100 + pct).dropFirst()), up to \(session.multiplierText(percent: m?.edgePower.capPercent ?? 200))."
        switch topic {
        case .hand:
            return ("Your hand", ["The 4 cards you kept from the deal. They're edge cards: they stay all turn and never clear.",
                                  "Trace them with grid cards that touch them. " + power])
        case .crib:
            return ("The crib", [session.state?.dealer == false
                                 ? "The crib is the dealer's. On your turns as dealer, its 4 cards sit down this side."
                                 : "The dealer's crib: 4 more edge cards down the side. Like your hand, they stay all turn and never clear.",
                                 "Trace them with grid cards that touch them. " + power])
        case .starter:
            return ("The starter", ["As in a cribbage hand, the starter counts with every set you score. You don't have to trace it, and it never counts toward your cards.",
                                    "When it's part of a combo it lights up and scores, and it's never left over when it isn't.",
                                    power])
        case .tray:
            return ("Power jokers", ["Special jokers you've won, kept all game.",
                                  "Swapper: tap it, then trace a straight line of 2 to 4 grid cards to reverse it.",
                                  "Bomb: tap it, then tap a grid card. It clears that card and its neighbours, without scoring.",
                                  "Tap an armed joker again to put it back."])
        case .counter:
            return ("Cards per set", ["A set picks 2 to \(session.pickLimit) cards. The pips fill as you pick, and turn gold at the limit.",
                                      "The starter is free: it joins every set without using a pip.",
                                      "Some combos, jokers and prizes will raise the limit for a while."])
        }
    }
}

/// The turn's clock: no numbers, a solid wedge that grows until it fills the circle.
/// Green while time runs, orange in the last 10%, orange and pulsing while a stuck board
/// counts down its grace, red when the turn is over, grey with no timer.
struct TurnClock: View {
    let session: GameSession
    @State private var pulse = false
    @State private var breathe = false

    enum Look { case running, warning, stuck, done, off }

    static let green = Color(hex: 0x39E07A), orange = Color(hex: 0xFF9F1C), red = Color(hex: 0xFF4D4D)

    var body: some View {
        let total = session.turn?.config.rules.match.timerSeconds ?? 0
        let look: Look = session.over ? .done
            : session.graceLeft != nil ? .stuck
            : total == 0 ? .off
            : session.secondsLeft * 10 <= total ? .warning : .running
        let filled: Double = switch look {
        case .done: 1
        case .stuck: 1 - Double(session.graceLeft ?? 0) / Double(GameSession.graceSeconds)
        case .off: 0
        default: total > 0 ? 1 - Double(max(0, session.secondsLeft)) / Double(total) : 0
        }
        let colour: Color = switch look {
        case .running: Self.green
        case .warning, .stuck: Self.orange
        case .done: Self.red
        case .off: Theme.feltText.opacity(0.3)
        }
        ZStack {
            Circle().fill(colour.opacity(0.15))
            Wedge(fraction: filled).fill(colour)
                .animation(.linear(duration: 1), value: filled)   // grows smoothly between ticks
            Circle().strokeBorder(colour, lineWidth: 2)
        }
        .frame(width: 30, height: 30)
        // While the clock runs it breathes, slowly, so it reads as alive; a stuck board pulses faster.
        .scaleEffect(look == .running || look == .warning ? (breathe ? 1.07 : 0.96) : 1)
        .opacity(look == .stuck && pulse ? 0.35 : 1)
        .shadow(color: look == .off ? .clear : colour.opacity(0.5), radius: 4)
        .animation(.easeOut(duration: 0.3), value: look)
        .onChange(of: look == .running || look == .warning, initial: true) { _, running in
            breathe = false
            if running { withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { breathe = true } }   // about a breath: 2 s in, 2 s out
        }
        .onChange(of: look == .stuck, initial: true) { _, stuck in
            pulse = false
            if stuck { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true } }
        }
        .help(look == .off ? "No timer" : look == .stuck ? "No sets left: use a power joker before the clock fills" : "\(max(0, session.secondsLeft)) s left")
    }
}

/// A pie wedge from 12 o'clock, clockwise, `fraction` of the circle.
struct Wedge: Shape {
    var fraction: Double
    var animatableData: Double { get { fraction } set { fraction = newValue } }
    func path(in r: CGRect) -> Path {
        var p = Path()
        guard fraction > 0 else { return p }
        let c = CGPoint(x: r.midX, y: r.midY), rad = min(r.width, r.height) / 2
        p.move(to: c)
        p.addArc(center: c, radius: rad, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * min(1, fraction)), clockwise: false)
        p.closeSubpath()
        return p
    }
}
