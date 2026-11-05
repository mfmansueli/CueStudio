//
//  FilterFanMotion.swift
//  Cue Studio
//

import SwiftUI

/// The movement of a `FilterFan`'s chips: a spring that runs a little past and back as a chip leaves the chosen one, a settling one as it
/// comes home, each delayed by its place in the order (`FilterFanPlan.delay(at:)`), and a fade at either end. The "liquid" version the
/// owner picked (05/11/2026): slower than a plain spring, so the neck between two chips is seen stretching and breaking.
/// With Reduce Motion nothing slides: the chips only fade in and out where they are.
nonisolated enum FilterFanMotion {
    /// A chip leaving the chosen one.
    static let unfold = Animation.spring(response: 0.56, dampingFraction: 0.68)
    /// A chip coming home behind the chosen one (it settles in about `FilterFanPlan.foldTravel`).
    static let fold = Animation.spring(response: 0.44, dampingFraction: 0.86)
    /// The dots coming back once the row is folded.
    static let peekIn = Animation.easeOut(duration: 0.22)
    static let peekOut = Animation.easeOut(duration: 0.09)
    /// What Reduce Motion leaves.
    static let reduced = Animation.easeInOut(duration: 0.2)

    /// How the chip at `index` moves (its place and size).
    static func move(at index: Int, in plan: FilterFanPlan, reduceMotion: Bool) -> Animation? {
        guard !reduceMotion else { return nil }
        return (plan.isOpen ? unfold : fold).delay(plan.delay(at: index))
    }

    /// What fades: a chip's words (and its white, when it is the chosen one), or its fill in the liquid.
    enum Layer {
        case chip
        case fill
    }

    /// How the chip at `index` appears and goes. Unfolding, the fill comes at once (the liquid swells out of the chosen chip) and the words
    /// only once the chip is clear of its neighbours, so names never pile up; folding, the words go (and the white moves to the picked
    /// chip) at once, and the fill near the end of its way home, so it is the liquid that flows back.
    static func fade(at index: Int, in plan: FilterFanPlan, layer: Layer, reduceMotion: Bool) -> Animation {
        guard !reduceMotion else { return reduced }
        let delay = plan.delay(at: index)
        switch (plan.isOpen, layer) {
        case (true, .fill): return .easeOut(duration: 0.12).delay(delay)
        case (true, .chip): return .easeOut(duration: 0.18).delay(delay + 0.18)
        case (false, .chip): return .easeOut(duration: 0.12)
        case (false, .fill): return .easeIn(duration: 0.18).delay(delay + 0.2)
        }
    }

    /// The dots: gone at once as the row opens, back as the last chip lands.
    static func peek(in plan: FilterFanPlan, reduceMotion: Bool) -> Animation {
        guard !reduceMotion else { return reduced }
        return plan.isOpen ? peekOut : peekIn.delay(plan.foldLanding * 0.8)
    }
}
