// The UI's cue timings and motions, from config/fx.json (ui.md › Motion). No numbers here:
// every client reads the same file, so the Mac and the ports move alike.
import Foundation
import SwiftUI
import CribMaze

/// One motion: a spring (duration and bounce) or an ease curve, in milliseconds.
struct MotionSpec: Decodable {
    let type: String
    let ms: Double
    var bounce: Double = 0
    var `repeat` = false

    enum CodingKeys: String, CodingKey { case type, ms, bounce, `repeat` }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        ms = try c.decode(Double.self, forKey: .ms)
        bounce = try c.decodeIfPresent(Double.self, forKey: .bounce) ?? 0
        `repeat` = try c.decodeIfPresent(Bool.self, forKey: .repeat) ?? false
    }

    /// The SwiftUI animation, stretched by slow motion unless `scaled` is false.
    func animation(scaled: Bool = true) -> Animation {
        let s = (scaled ? Motion.t(ms) : ms) / 1000
        let a: Animation = switch type {
        case "spring": .spring(duration: s, bounce: bounce)
        case "easeIn": .easeIn(duration: s)
        case "easeInOut": .easeInOut(duration: s)
        case "linear": .linear(duration: s)
        default: .easeOut(duration: s)
        }
        return `repeat` ? a.repeatForever(autoreverses: true) : a
    }
}

struct FX: Decodable {
    struct Motions: Decodable {
        struct Board: Decodable { let select, pop, change, pick, helpText, stepsCount, numberRoll, stepsBump, stepsUnbump: MotionSpec }
        struct Hint: Decodable { let show, blink: MotionSpec }
        struct Deal: Decodable { let card, `throw`, starter: MotionSpec }
        struct Breakdown: Decodable { let fade, setLeave, rowFly, banner, tally, tallyLine, light, unlight, powerUp, totalFly: MotionSpec }
        struct Clock: Decodable { let look, wedge, pulse: MotionSpec }
        let board: Board, hint: Hint, deal: Deal, breakdown: Breakdown, clock: Clock
    }
    struct Waits: Decodable {
        struct Speed: Decodable, Hashable { let name: String; let ms: Double }
        struct Breakdown: Decodable {
            let speeds: [Speed]
            let beforeRow, rowBeat, beforeBanner, beforeTally, comboLitPercent, afterTotal, rowStagger, flyHome: Double
        }
        struct Board: Decodable { let pop, bombPop, settle: Double }
        struct Float: Decodable { let life: Double; let keys: [Double]; let startScale, peakScale, startY, midRise, rise: Double }
        struct Deal: Decodable { let gap, throwToStarter, starterToTurn: Double }
        struct Clock: Decodable {
            let secondsFrom, warningPercent: Int
            let urgencyPercent: [Int]
            let halfBreath: [Double]
            let breathDepth: [Double]
        }
        let breakdown: Breakdown, board: Board, float: Float, toast: Double, deal: Deal, clock: Clock, slowMotion: Double
    }
    let version: Int
    let motions: Motions
    let waits: Waits

    /// Loaded once from the app's bundled config folder. The file MUST be there (ui.md › Motion).
    static let shared: FX = {
        do {
            guard let url = Bundle.main.url(forResource: "config", withExtension: nil)?.appendingPathComponent("fx.json") else {
                throw ConfigError(description: "config folder missing from the app")
            }
            return try JSONDecoder().decode(FX.self, from: Data(contentsOf: url))
        } catch { fatalError("config/fx.json didn't load: \(error)") }
    }()
}

/// Shorthand for the shared FX motions and waits.
@inline(__always) var fx: FX { FX.shared }
