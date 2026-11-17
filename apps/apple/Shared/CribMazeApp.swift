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
            CommandGroup(replacing: .newItem) {
                Button("New Turn") { session.newTurn() }.keyboardShortcut("n")
                Button("Same Seed Again") { session.newTurn(seed: session.seed) }.keyboardShortcut("r")
            }
        }
    }
}
