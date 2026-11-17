// Beta only: `--snapshot <png> [--seed N] [--turn N] [--trace g30,g31;g00,g01] [--select g10,g11] [--arm swapper|bomb|burn]
// [--burn g11] [--play] [--crib-off] [--end] [--info hand|crib|starter|tray|counter] [--pop g11,g12 [--bomb]]`
// (and `--deal [--pick 5H,5C] [--hint]`, `--breakdown g31,g21 [--stage N]`, `--settings`)
// renders the play screen to a PNG and quits. Used to check the screen from scripts, where screen capture isn't available.
import AppKit
import AVFoundation
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
        if let dir = value("--film") { Film.run(session, cue: value("--cue") ?? "deal", to: dir, seed: value("--seed").flatMap(UInt64.init) ?? 1); return }
        guard let out = value("--snapshot") else { return }
        session.animate = false
        if args.contains("--crib-off") { session.settings.dealer = false }
        // `--strong`: the strong preset hand (4♥ 5♣ 6♦ J♠, starter 5♠), whose 17 wins an opening bonus (r26).
        if args.contains("--strong") { session.settings.hand = "strong" }
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
        // `--info hand`: an info card open. `--pop g11,g12 [--bomb]`: those cards mid-pop, as a score
        // with the breakdown off (or a bomb or burn) shows them.
        if let topic = value("--info") {
            session.info = ["hand": .hand, "crib": .crib, "starter": .starter, "tray": .tray, "counter": .counter][topic]
        }
        if let set = value("--pop") { session.snapshotFlash(Set(positions(Substring(set))), bomb: args.contains("--bomb")) }
        // `--settings`: the settings panel on its own (a popover can't be rendered with the phone).
        if args.contains("--settings") {
            renderWindow(SidePanel(session: session).frame(width: 340, height: 620).environment(\.colorScheme, .dark), size: CGSize(width: 340, height: 620), to: out)
            exit(0)
        }
        // Toasts from the deal (an extra card's prize) would cover the board: hidden unless `--toast`.
        if !args.contains("--toast") { session.hideToast() }
        // `--opening hand|crib [--stage N]`: the opening count (r24) over the empty board, played
        // instantly to its hold, or stopped at its Nth wait.
        if let what = value("--opening"), let e = session.events.first(where: { if case .opening(what, _, _, _, _, _, _, _) = $0 { return true }; return false }) {
            // Steps before this count; its own bonus jokers and later ones haven't landed yet.
            var steps = 0, unlanded: [String] = [], reached = false
            for x in session.events {
                guard case .opening(let w, _, _, _, _, _, let p, let b) = x else { continue }
                if w == what { reached = true }
                if reached { unlanded += b } else { steps += p }
            }
            session.snapshotOpening(steps: steps, unlanded: unlanded)
            session.playback.instant = true
            if let n = value("--stage").flatMap(Int.init) {
                session.playback.stopAt = n
                session.playback.onStop = { render(session, to: out); exit(0) }
            }
            Task { @MainActor in
                await session.playOpening(e, cells: session.state?.cells ?? [])
                render(session, to: out)
                exit(0)
            }
            return
        }
        // `--breakdown g31,g21`: play that set's breakdown instantly and render its last frame.
        if let set = value("--breakdown"), var t = session.turn {
            session.dismissWarning()
            let before = t.state
            if let ev = try? t.apply(.trace(positions: positions(Substring(set)))), let score = ev.first(where: { if case .score = $0 { return true }; return false }) {
                session.playback.instant = true
                // `--stage N`: stop after the breakdown's Nth wait (ui.md › Cue sheet), not at its end.
                if let n = value("--stage").flatMap(Int.init) {
                    session.playback.stopAt = n
                    session.playback.onStop = { render(session, to: out); exit(0) }
                }
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
        render(PhoneView(session: session).padding(24).background(Theme.page).environment(\.colorScheme, .light), to: out)
    }

    /// Renders a view with AppKit controls (toggles, pickers) through an offscreen window, which
    /// ImageRenderer can't draw. At the screen's scale.
    static func renderWindow(_ view: some View, size: CGSize, to out: String) {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        let w = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentView = host
        w.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        w.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
    }

    /// Renders at 2x, the scale every reference shot uses (docs/images/reference/README.md).
    static func render(_ view: some View, to out: String) {
        let r = ImageRenderer(content: view); r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: out))
        }
    }
}

/// `--film <file.mp4> --cue deal|opening|trace|breakdown|bomb`: plays one cue in an offscreen window and
/// films the window, so the video shows the cue five times slower than the game plays it
/// (fx.json › waits.slowMotion). Screen capture isn't needed: the window draws itself. Drawing a
/// frame takes about 120 ms, so the cue plays at 15x and each frame is stamped at a third of the
/// time it was taken: about 24 frames a second of video.
@MainActor enum Film {
    static func run(_ session: GameSession, cue: String, to out: String, seed: UInt64) {
        session.settings.timer = false
        session.settings.deal = cue == "deal"
        session.settings.breakdown = cue == "breakdown" || cue == "opening"
        // Only the opening cue plays the opening count; the others start from the dealt board.
        session.playsOpening = cue == "opening"
        session.playback.autoContinue = true
        session.newTurn(seed: seed)
        let slow = fx.waits.slowMotion, filmed = slow * 3
        Motion.scale = filmed
        session.hideToast()
        let size = CGSize(width: 450, height: 960)
        let host = NSHostingView(rootView: PhoneView(session: session).padding(24).background(Theme.page).environment(\.colorScheme, .light))
        host.frame = CGRect(origin: .zero, size: size)
        let w = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = host
        w.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        w.orderFrontRegardless()

        // Each cue: what to do, at what game time in ms, and how long to film in all (game ms).
        let s = { (n: String) in Board.parse(n)! }
        let steps: [(Double, () -> Void)]
        let length: Double
        switch cue {
        case "trace":   // a combo lighting as the trace grows, then the pop and the board change
            steps = [(400, { session.selection = [s("g02")] }), (900, { session.selection = [s("g02"), s("g03")] }),
                     (1500, { session.selection = []; session.submit([s("g02"), s("g03")]) })]
            length = 3000
        case "breakdown":
            steps = [(400, { session.submit([s("g31"), s("g32"), s("g33"), s("c3")]) })]
            length = 8000
        case "opening":   // r24: the hand and crib counted over the empty board, then the grid deals in
            steps = []
            length = 30000
        case "bomb":
            steps = [(400, { session.arm("bomb") }), (900, { session.submit([s("g00")]) })]
            length = 2400
        default:        // the deal: twelve cards in, then nothing (the throw needs a tap on the view)
            steps = []
            length = 2000
        }

        guard let writer = try? AVAssetWriter(outputURL: URL(fileURLWithPath: out), fileType: .mp4) else { exit(1) }
        try? FileManager.default.removeItem(atPath: out)
        let px = (w: Int(size.width * 2), h: Int(size.height * 2))
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: px.w, AVVideoHeightKey: px.h])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: px.w, kCVPixelBufferHeightKey as String: px.h])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        Task { @MainActor in
            let start = Date()
            var pending = steps, frame: Int64 = 0
            while true {
                let real = Date().timeIntervalSince(start), t = real * 1000 / filmed
                while let next = pending.first, next.0 <= t { pending.removeFirst(); next.1() }
                if t > length { break }
                if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds), let pool = adaptor.pixelBufferPool, input.isReadyForMoreMediaData {
                    host.cacheDisplay(in: host.bounds, to: rep)
                    var buf: CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buf)
                    if let buf, let img = rep.cgImage {
                        CVPixelBufferLockBaseAddress(buf, [])
                        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: px.w, height: px.h, bitsPerComponent: 8,
                                            bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
                        ctx?.draw(img, in: CGRect(x: 0, y: 0, width: px.w, height: px.h))
                        CVPixelBufferUnlockBaseAddress(buf, [])
                        // Stamped with when it was taken, scaled to 5x, so a slow frame doesn't speed the video up.
                        adaptor.append(buf, withPresentationTime: CMTime(seconds: real * slow / filmed, preferredTimescale: 600))
                        frame += 1
                    }
                }
                try? await Task.sleep(for: .milliseconds(2))   // lets the run loop step the animations
            }
            input.markAsFinished()
            await writer.finishWriting()
            exit(writer.status == .completed ? 0 : 1)
        }
    }
}
