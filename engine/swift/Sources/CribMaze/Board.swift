// The match board's positions (engine.md › The match board › Positions).
//
// Positions are numbered in canonical order: grid g00 to g33 (0 to 15), then
// hand h0 to h3 (16 to 19), crib c0 to c3 (20 to 23), then the starter (24).

public typealias Pos = Int

public enum Board {
    public static let count = 25
    public static let grid = 0..<16
    public static let hand = 16..<20
    public static let crib = 20..<24
    public static let starter = 24

    public static func isGrid(_ p: Pos) -> Bool { p < 16 }
    public static func isEdge(_ p: Pos) -> Bool { p >= 16 }
    public static func g(_ r: Int, _ c: Int) -> Pos { r * 4 + c }

    /// Board coordinates (row, column): grid (r, c), crib (i, 4), hand (4, i), starter (4, 4).
    public static func coords(_ p: Pos) -> (r: Int, c: Int) {
        switch p {
        case 0..<16: return (p / 4, p % 4)
        case 16..<20: return (4, p - 16)
        case 20..<24: return (p - 20, 4)
        default: return (4, 4)
        }
    }
    public static func at(_ r: Int, _ c: Int) -> Pos? {
        switch (r, c) {
        case (0...3, 0...3): return g(r, c)
        case (4, 0...3): return 16 + c
        case (0...3, 4): return 20 + r
        case (4, 4): return starter
        default: return nil
        }
    }
    /// Touching: coordinates differ by at most 1 in both row and column.
    public static func touching(_ a: Pos, _ b: Pos) -> Bool {
        let x = coords(a), y = coords(b)
        return a != b && abs(x.r - y.r) <= 1 && abs(x.c - y.c) <= 1
    }
    public static let neighbours: [[Pos]] = (0..<25).map { a in (0..<25).filter { touching(a, $0) } }

    /// The name used in events and records: g12, h0, c3, s.
    public static func name(_ p: Pos) -> String {
        switch p {
        case 0..<16: return "g\(p / 4)\(p % 4)"
        case 16..<20: return "h\(p - 16)"
        case 20..<24: return "c\(p - 20)"
        default: return "s"
        }
    }
    public static func parse(_ s: String) -> Pos? { (0..<25).first { name($0) == s } }

    /// Whether positions are connected through touching, in any order.
    public static func connected(_ ps: [Pos]) -> Bool {
        guard let first = ps.first else { return false }
        var seen: Set<Pos> = [first], stack = [first]
        let all = Set(ps)
        while let p = stack.popLast() {
            for n in neighbours[p] where all.contains(n) && !seen.contains(n) { seen.insert(n); stack.append(n) }
        }
        return seen.count == all.count
    }

    /// Every connected set of 2 to `maxSize` positions, each as its positions in
    /// ascending (canonical) order, listed in lexicographic order: the order a
    /// search "in position order" meets them. Computed once per size.
    public static func connectedSets(maxSize: Int) -> [[Pos]] {
        var masks = Set<UInt32>()
        var frontier: [UInt32] = (0..<25).map { UInt32(1) << UInt32($0) }
        for _ in 2...max(2, maxSize) {
            var next: [UInt32] = []
            for m in frontier {
                for p in 0..<25 where m >> UInt32(p) & 1 == 1 {
                    for n in neighbours[p] where m >> UInt32(n) & 1 == 0 {
                        let x = m | (UInt32(1) << UInt32(n))
                        if masks.insert(x).inserted { next.append(x) }
                    }
                }
            }
            frontier = next
        }
        let lists = masks.map { m in (0..<25).filter { m >> UInt32($0) & 1 == 1 } }
        return lists.sorted { a, b in
            for (x, y) in zip(a, b) where x != y { return x < y }
            return a.count < b.count
        }
    }
}
