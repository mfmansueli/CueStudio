//
//  PopEase.swift
//  Cue Studio
//

import Foundation

/// How a caption or an overlay that pops in grows: from a share of its size to full, a little past it on the way.
nonisolated enum PopEase {
    /// The size of a line `elapsed` seconds after it came in, as a share of its full size: it starts at `start` and grows to
    /// full over `duration`, going a little past it on the way (ease-out with a small overshoot), so a caption lands rather
    /// than appears. 1 before and after.
    static func scale(from start: Double, elapsed: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0, elapsed < duration else { return 1 }
        let progress = min(max(elapsed / duration, 0), 1)
        // Ease-out-back: overshoots the end by about 10% of the way, then settles.
        let c1 = 1.2
        let c3 = c1 + 1
        let eased = 1 + c3 * pow(progress - 1, 3) + c1 * pow(progress - 1, 2)
        return start + (1 - start) * eased
    }
}
