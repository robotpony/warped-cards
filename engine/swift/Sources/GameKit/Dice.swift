// Seeded, named random streams, exactly as engine.md › Dice describes.
// The reference is cribbage/minigames/mocks/dice.js; fixtures/dice.json holds its values.

/// One random draw, kept so a record holds every roll.
public struct Roll: Codable, Sendable, Equatable {
    public let stream: String
    public let purpose: String
    public let n: Int
    public let value: Int
    public init(stream: String, purpose: String, n: Int, value: Int) {
        self.stream = stream; self.purpose = purpose; self.n = n; self.value = value
    }
}

/// FNV-1a, 64-bit, over the UTF-8 bytes of a name.
public func fnv1a64(_ text: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for b in text.utf8 { h ^= UInt64(b); h = h &* 0x100_0000_01b3 }
    return h
}

/// SplitMix64, used to seed each stream.
public struct SplitMix64: Sendable {
    private var s: UInt64
    public init(seed: UInt64) { s = seed }
    public mutating func next() -> UInt64 {
        s = s &+ 0x9e37_79b9_7f4a_7c15
        var z = s
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}

/// One named stream: xoshiro256** seeded by SplitMix64 from (game seed XOR FNV-1a(name)).
public struct DiceStream: Sendable {
    public let name: String
    private var s: (UInt64, UInt64, UInt64, UInt64)

    public init(gameSeed: UInt64, name: String) {
        self.name = name
        var sm = SplitMix64(seed: gameSeed ^ fnv1a64(name))
        s = (sm.next(), sm.next(), sm.next(), sm.next())
    }

    @inline(__always) private static func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 { (x << k) | (x >> (64 - k)) }

    public mutating func next64() -> UInt64 {
        let result = Self.rotl(s.1 &* 5, 7) &* 9
        let t = s.1 << 17
        s.2 ^= s.0; s.3 ^= s.1; s.1 ^= s.2; s.0 ^= s.3
        s.2 ^= t; s.3 = Self.rotl(s.3, 45)
        return result
    }

    /// An integer from 0 to n − 1, each equally likely (Lemire's method with rejection).
    public mutating func below(_ n: Int) -> Int {
        precondition(n >= 1, "below(n) needs n >= 1")
        let bn = UInt64(n)
        var m = next64().multipliedFullWidth(by: bn)
        if m.low < bn {
            let t = (0 &- bn) % bn
            while m.low < t { m = next64().multipliedFullWidth(by: bn) }
        }
        return Int(m.high)
    }
}

/// All of a game's streams. Every draw is logged as a Roll; the caller drains them per step.
public struct Dice: Sendable {
    public private(set) var seed: UInt64
    private var streams: [String: DiceStream] = [:]
    public private(set) var rolls: [Roll] = []
    /// Scripted mode: rolls handed back in order instead of drawn (replays across generator changes).
    private var script: [Roll]?
    private var scriptAt = 0
    /// In scripted mode, the first draw that didn't match the script (or ran past its end). From
    /// then on draws come from the seed, so a replay can finish and report it.
    public private(set) var scriptProblem: String?

    public init(seed: UInt64) { self.seed = seed }
    public init(scripted rolls: [Roll], seed: UInt64) { self.seed = seed; script = rolls }

    public var isScripted: Bool { script != nil }
    /// Scripted rolls not handed back yet.
    public var scriptLeft: Int { (script?.count ?? 0) - scriptAt }

    /// Starts every stream again from a new seed, as a game does at each hand (engine.md › The
    /// game › Seeds). Scripted dice carry on through their script.
    public mutating func reseed(_ newSeed: UInt64) {
        seed = newSeed
        streams = [:]
    }

    public mutating func below(_ n: Int, stream: String, purpose: String) -> Int {
        var value: Int?
        if let script, scriptProblem == nil {
            if scriptAt < script.count {
                let r = script[scriptAt]
                if r.stream == stream && r.purpose == purpose && r.n == n && r.value < n {
                    value = r.value; scriptAt += 1
                } else {
                    scriptProblem = "roll \(scriptAt + 1): the script has \(r.stream)/\(r.purpose) below \(r.n), the game drew \(stream)/\(purpose) below \(n)"
                }
            } else {
                scriptProblem = "roll \(scriptAt + 1): the script ran out at \(stream)/\(purpose)"
            }
        }
        if value == nil {
            var st = streams[stream] ?? DiceStream(gameSeed: seed, name: stream)
            value = st.below(n)
            streams[stream] = st
        }
        rolls.append(Roll(stream: stream, purpose: purpose, n: n, value: value!))
        return value!
    }

    /// A weighted pick from integer weights, in the order given.
    public mutating func pick<K>(_ weights: [(K, Int)], stream: String, purpose: String) -> K {
        let total = weights.reduce(0) { $0 + $1.1 }
        let d = below(total, stream: stream, purpose: purpose)
        var run = 0
        for (key, w) in weights { run += w; if d < run { return key } }
        preconditionFailure("weights must be positive")
    }

    /// Fisher-Yates from the end, one roll per swap step.
    public mutating func shuffle<T>(_ list: inout [T], stream: String, purpose: String) {
        guard list.count > 1 else { return }
        for i in stride(from: list.count - 1, through: 1, by: -1) {
            let j = below(i + 1, stream: stream, purpose: purpose)
            list.swapAt(i, j)
        }
    }

    /// Hands over the rolls drawn since the last call.
    public mutating func takeRolls() -> [Roll] { defer { rolls = [] }; return rolls }
}
