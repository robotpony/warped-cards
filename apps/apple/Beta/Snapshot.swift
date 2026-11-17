// Beta only: `--snapshot <png> [--seed N] [--turn N] [--trace g30,g31;g00,g01] [--select g10,g11] [--arm swapper|bomb|burn]
// [--burn g11] [--play] [--crib-off] [--end]` (and `--deal [--pick 5H,5C] [--hint]`, `--breakdown g31,g21`)
// renders the play screen to a PNG and quits. Used to check the screen from scripts, where screen capture isn't available.
import AppKit
import CribMaze
import SwiftUI

@MainActor enum Snapshot {
    static func runIfAsked(_ session: GameSession) {
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? { args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        func positions(_ s: Substring) -> [Pos] { s.split(separator: ",").compactMap { Board.parse(String($0)) } }
        // `--demo [--slow]`: the medium bot plays turn after turn with full animation, for recording with Instruments.
        if args.contains("--demo") {
            session.settings.timer = false
            session.settings.deal = false
            session.slowMotion = args.contains("--slow")
            session.playback.autoContinue = true   // the demo doesn't wait for taps
            session.newTurn(seed: value("--seed").flatMap(UInt64.init) ?? 42)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                while true {
                    try? await Task.sleep(for: .milliseconds(400))
                    if session.busy { continue }
                    session.dismissWarning()
                    if session.over { try? await Task.sleep(for: .seconds(1.5)); session.newTurn(seed: session.seed + 1); continue }
                    session.botMove()
                }
            }
            return
        }
        guard let out = value("--snapshot") else { return }
        session.animate = false
        if args.contains("--crib-off") { session.settings.dealer = false }
        // `--deal [--pick 5H,5C] [--hint]`: render the deal screen instead of the turn.
        session.settings.deal = args.contains("--deal")
        if args.contains("--deal") {
            session.newTurn(seed: value("--seed").flatMap(UInt64.init) ?? 42)
            advance(session, to: value("--turn").flatMap(Int.init) ?? 1)
            for n in (value("--pick") ?? "").split(separator: ",") {
                if let c = session.dealing?.dealt.player.first(where: { $0.notation == String(n) }) { session.togglePick(c) }
            }
            if args.contains("--hint") { session.showHint(asked: true) }
            render(session, to: out)
            exit(0)
        }
        session.newTurn(seed: value("--seed").flatMap(UInt64.init) ?? 42)
        advance(session, to: value("--turn").flatMap(Int.init) ?? 1)
        for set in (value("--trace") ?? "").split(separator: ";") { session.submit(positions(set)) }
        // `--burn g11`: burn that grid card. `--play`: the medium bot plays the rest of the turn.
        if let cell = value("--burn"), let p = Board.parse(cell) { session.arm("burn"); session.submit([p]) }
        if args.contains("--play") { session.dismissWarning(); while !session.over { session.botMove(); session.dismissWarning() } }
        if let kind = value("--arm") { session.arm(kind) }
        if let sel = value("--select") { session.selection = positions(Substring(sel)) }
        if args.contains("--end") { session.send(.endTurn) }
        // `--breakdown g31,g21`: play that set's breakdown instantly and render its last frame.
        if let set = value("--breakdown"), var t = session.turn {
            session.dismissWarning()
            let before = t.state
            if let ev = try? t.apply(.trace(positions: positions(Substring(set)))), let score = ev.first(where: { if case .score = $0 { return true }; return false }) {
                session.playback.instant = true
                Task { @MainActor in
                    await session.playBreakdown(score, before: before)
                    render(session, to: out)
                    exit(0)
                }
                return
            }
        }
        render(session, to: out)
        exit(0)
    }

    /// `--turn N`: the medium bot plays the game's turns before turn N (throwing its best classic
    /// keep at each deal), so the deck shows what those turns made.
    static func advance(_ session: GameSession, to turn: Int) {
        while let g = session.game, g.turn < turn, !g.over {
            if let d = session.dealing {
                for c in Deal.classicKeep(d.dealt.player).thrown { session.togglePick(c) }
                session.throwToCrib()
            }
            session.dismissWarning()
            while !session.over { session.botMove(); session.dismissWarning() }
            if session.moreTurns { session.nextTurn() } else { break }
        }
    }

    static func render(_ session: GameSession, to out: String) {
        let view = PhoneView(session: session).padding(24).background(Theme.page).environment(\.colorScheme, .light)
        let r = ImageRenderer(content: view); r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: out))
        }
    }
}
