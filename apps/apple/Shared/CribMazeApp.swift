import AppKit
import CribMaze
import SwiftUI

@main
struct CribMazeApp: App {
    @State private var session: GameSession
    init() {
        let s = GameSession()
        Snapshot.runIfAsked(s)
        _session = State(initialValue: s)
    }
    var body: some Scene {
        WindowGroup(Edition.name) {
            MatchTurnView(session: session)
        }
        .windowResizability(.contentSize)   // the window is the phone, nothing more
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(Edition.name)") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(string: BuildLine.text, attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]),
                    ])
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Turn") { session.newTurn() }.keyboardShortcut("n")
                Button("Same Seed Again") { session.newTurn(seed: session.seed) }.keyboardShortcut("r")
            }
        }
    }
}

/// Which build this is and what it plays (PORTING.md › Versions): "Mac 0.15.4 · spec 2 · r23".
enum BuildLine {
    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
    static var text: String {
        "Mac \(version) · spec \(CribMazeGame.specVersion) · \(MatchTurn.rulesVersion.replacingOccurrences(of: "match-", with: ""))"
    }
}
