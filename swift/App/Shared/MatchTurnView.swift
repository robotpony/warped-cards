import CardKit
import CribMaze
import CribbageKit
import SwiftUI

struct MatchTurnView: View {
    @Bindable var session: GameSession

    var body: some View {
        if let err = session.loadError {
            ContentUnavailableView("Config didn't load", systemImage: "exclamationmark.triangle", description: Text(err))
        } else {
            HStack(spacing: 0) {
                // The phone is a fixed size (the mock's 872 pt, or less in a short window), so nothing reflows as you play.
                GeometryReader { g in
                    PhoneView(session: session, height: min(872, g.size.height - 48))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                SidePanel(session: session).frame(width: 320)
            }
            .background(Theme.page)
            .background(FrameMeterHost(meter: session.meter))
        }
    }
}

/// The play screen, laid out like the mock's phone: top line, steps and stock, the
/// 121-step track, the board, the help line, the feed, then the tray and End turn.
struct PhoneView: View {
    let session: GameSession
    var height: CGFloat = 872

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topLine
            stepsRow
            track
            BoardView(session: session).padding(.top, 9).frame(maxWidth: .infinity)
            HStack(alignment: .top, spacing: 10) {
                Text(session.pickMessage)
                    .font(Theme.font(14, session.dead && session.selection.isEmpty && session.mode == .trace ? .semibold : .medium))
                    .foregroundStyle(session.dead && session.selection.isEmpty && session.mode == .trace ? Theme.gold : Theme.feltText.opacity(0.9))
                    .lineLimit(2).frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .topLeading)
                PickCounter(count: session.mode == .trace ? session.pickCount : 0, limit: session.pickLimit)
                    .onTapGesture { if !session.busy { session.info = .counter } }
            }
            feed
            bottom
        }
        .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 20)
        .frame(width: BoardLayout.width + 2 * 16 + 18, height: height)
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

    private var topLine: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(session.settings.dealer ? "Your match turn · dealer" : "Your match turn")
            Spacer()
            Text(session.settings.timer ? "\(max(0, session.secondsLeft)) s" : "no timer").monospacedDigit()
            Spacer()
            Text("Stock \(session.turn?.drawable ?? 0)").monospacedDigit()
        }
        .font(Theme.font(14, .medium)).opacity(0.9)
    }

    private var stepsRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.state?.steps ?? 0)").font(Theme.font(34, .bold)).contentTransition(.numericText())
                    .foregroundStyle(session.playback.bump ? Theme.gold : Theme.feltText)
                    .scaleEffect(session.playback.bump ? 1.25 : 1, anchor: .leading)
                    .animation(.snappy, value: session.state?.steps)
                Text("steps this turn").font(Theme.font(13, .medium)).opacity(0.75)
            }
            Spacer()
            // The stock, face down; an empty outline once it runs out.
            HStack(spacing: 8) {
                Text("Seed \(String(session.seed))").font(Theme.font(12, .medium)).opacity(0.5)
                if (session.turn?.drawable ?? 0) > 0 { CardBack(width: 46) }
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

    private var feed: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(session.feed.prefix(6).enumerated()), id: \.element.id) { i, l in
                Text(l.text).lineLimit(2)
                .font(Theme.font(14, i == 0 ? .semibold : .regular))
                .foregroundStyle(l.prize ? Theme.gold : Theme.feltText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .layoutPriority(-1)   // the feed takes what's left and never grows the screen
    }

    private var bottom: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // The tray: special jokers on a bed of their own, tagged POWER JOKERS like the hand's tag.
            HStack(spacing: 22) {
                TrayCard(kind: "swapper", count: session.state?.tray["swapper"] ?? 0, armed: session.mode == .swap && session.armedSource == nil) { tapTray("swapper", .swap) }
                TrayCard(kind: "bomb", count: session.state?.tray["bomb"] ?? 0, armed: session.mode == .bomb && session.armedSource == nil) { tapTray("bomb", .bomb) }
            }
            .padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.violet.opacity(0.5), lineWidth: 1))
            .overlay(alignment: .top) {
                Text("POWER JOKERS").font(Theme.font(10, .bold)).tracking(0.8).padding(.horizontal, 6).frame(height: 16)
                    .background(Capsule().fill(Theme.violet)).foregroundStyle(Theme.felt).offset(y: -8)
                    .onTapGesture { if !session.blocked { session.info = .tray } }
            }
            Spacer()
            EndTurnButton(nudge: session.dead && !session.over) { session.send(.endTurn) }
        }
        .frame(minHeight: 112, alignment: .bottom)
    }

    private func tapTray(_ kind: String, _ m: InputMode) {
        guard !session.over, (session.state?.tray[kind] ?? 0) > 0 else { return }
        if session.mode == m && session.armedSource == nil { session.disarm() } else { session.selection = []; session.arm(kind) }
    }
}

/// A special joker in the tray: a small card, a stack when there's more than one, and a count.
struct TrayCard: View {
    let kind: String, count: Int, armed: Bool
    var w: CGFloat = 58
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

/// The mock's ghost button; it turns gold and pulses when no sets are left.
struct EndTurnButton: View {
    let nudge: Bool
    let action: () -> Void
    @State private var pulse = false
    var body: some View {
        Text("End turn").font(Theme.font(15, .semibold))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(nudge ? Theme.gold : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(nudge ? Theme.gold : Theme.feltText.opacity(0.4), lineWidth: 1))
            .foregroundStyle(nudge ? Theme.ink : Theme.feltText)
            .scaleEffect(nudge && pulse ? 1.06 : 1)
            .contentShape(Rectangle()).onTapGesture(perform: action)
            .onChange(of: nudge, initial: true) { _, on in
                pulse = false
                if on { withAnimation(.easeInOut(duration: Motion.t(0.6)).repeatForever(autoreverses: true)) { pulse = true } }
            }
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

struct SidePanel: View {
    @Bindable var session: GameSession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Edition.name).font(.headline)
                    Text("Match turn, rules \(MatchTurn.rulesVersion), app \(version)").font(.caption).foregroundStyle(.secondary)
                }
                GroupBox("Next turn") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Dealer: crib down the side", isOn: $session.settings.dealer)
                        Toggle("\(session.config?.rules.match.timerSeconds ?? 180) s timer", isOn: $session.settings.timer)
                        Toggle("Play each score's breakdown (tap to skip)", isOn: $session.settings.breakdown)
                        Picker("Breakdown speed", selection: $session.timing.base) {
                            Text("Slow (1.2 s)").tag(1200.0); Text("Medium (0.9 s)").tag(900.0); Text("Quick (0.6 s)").tag(600.0); Text("Practised (0.4 s)").tag(400.0)
                        }
                        Picker("Hand", selection: $session.settings.hand) { Text("Random").tag("random"); Text("Strong (4♥ 5♣ 6♦ J♠, 5♠)").tag("strong") }
                        Picker("Card budget", selection: $session.settings.budget) { Text("Whole stock").tag(0); Text("12").tag(12); Text("16").tag(16); Text("24").tag(24) }
                        HStack {
                            TextField("Seed (blank: random)", text: $session.seedText).textFieldStyle(.roundedBorder).onSubmit { session.newTurn() }
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
                        if session.feed.isEmpty { Text("Drag across 2 to 5 touching cards.").foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                if Edition.isBeta { GroupBox("Animation diagnostics") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Slow motion (5× slower)", isOn: $session.slowMotion)
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            Text("\(Int(session.meter.fps.rounded())) fps · \(session.meter.hitches) hitches during moves · worst \(Int(session.meter.worstMs)) ms")
                                .font(.callout.monospacedDigit())
                        }
                        Button("Reset count") { session.meter.reset() }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } }
                if let url = session.savedRecord {
                    Button("Show the turn record") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.buttonStyle(.link)
                }
                Text("How to play: drag across touching cards (diagonals count), or tap cards and tap the last again. Every set needs a grid card. Hand, crib and starter cards stay and power up.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
        // Neon: the panel colours from palette.json, with the Mac's dark controls tinted cyan.
        .background(Theme.panel)
        .environment(\.colorScheme, .dark)
        .tint(Theme.cyan)
        .foregroundStyle(Theme.feltText)
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
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
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
