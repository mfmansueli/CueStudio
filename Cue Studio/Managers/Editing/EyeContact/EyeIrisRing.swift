//
//  EyeIrisRing.swift
//  Cue Studio
//

import Foundation

/// One ring of the filmed iris: for any angle, the nearest seen angle below and above it, so a hidden arc can be filled with the
/// seen iris mirrored across its edge.
nonisolated struct EyeIrisRing {
    let usable: Bool
    /// Degrees to the nearest seen angle going down and going up, per whole degree.
    private let down: [Int]
    private let up: [Int]

    init(_ seen: [Bool]) {
        let count = seen.count
        usable = seen.filter { $0 }.count >= 20
        var down = [Int](repeating: count, count: count), up = [Int](repeating: count, count: count)
        if usable {
            for _ in 0..<2 {
                for angle in 0..<count {
                    down[angle] = seen[angle] ? 0 : min(down[angle], down[(angle + count - 1) % count] + 1)
                }
                for angle in stride(from: count - 1, through: 0, by: -1) {
                    up[angle] = seen[angle] ? 0 : min(up[angle], up[(angle + 1) % count] + 1)
                }
            }
        }
        self.down = down
        self.up = up
    }

    /// The seen angle `angle` (degrees) mirrors to across the nearer edge of its hidden arc; nil when the ring has too little iris.
    func mirror(_ angle: Double) -> Double? {
        guard usable else { return nil }
        let bin = Int(angle) % down.count
        let below = angle - Double(down[bin]) - 0.5, above = angle + Double(up[bin]) + 0.5
        return angle - below <= above - angle ? below - (angle - below) : above + (above - angle)
    }
}
