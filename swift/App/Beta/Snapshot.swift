// Beta only: `--snapshot <png> [--seed N] [--trace g30,g31;g00,g01] [--select g10,g11] [--arm swapper|bomb] [--crib-off] [--end]`
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
        session.newTurn(seed: value("--seed").flatMap(UInt64.init) ?? 42)
        for set in (value("--trace") ?? "").split(separator: ";") { session.submit(positions(set)) }
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

    static func render(_ session: GameSession, to out: String) {
        let view = PhoneView(session: session).padding(24).background(Theme.page).environment(\.colorScheme, .light)
        let r = ImageRenderer(content: view); r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: out))
        }
    }
}
