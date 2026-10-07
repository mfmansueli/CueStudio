//
//  SheetReveal.swift
//  Cue Studio
//

import SwiftUI

/// How a control comes out of the sheet . The sheet has one number, how far it is out (`progress`, 0 in and 1 out), and every
/// control reads its own part of it: from `start` to `end` it fades in, rises into its place and grows to its size, eased at both ends. The
/// windows overlap and run from the bottom up, so as the sheet opens the controls arrive one after another, and as it closes they leave in
/// the opposite order. Because it is a function of the sheet's position, the same motion follows a finger and a settling animation, and it
/// can be reversed half way.
struct SheetReveal: ViewModifier {
    let progress: CGFloat
    let start: CGFloat
    let end: CGFloat
    /// Grows a little past its size before it settles (the record button).
    var overshoot = false

    /// How far the control is, 0...1, eased.
    private var amount: CGFloat {
        Self.smoothstep(progress, from: start, to: end)
    }

    func body(content: Content) -> some View {
        let eased = amount
        let size = overshoot ? 0.5 + 0.5 * Self.backOut(eased) : 0.86 + 0.14 * eased
        content
            .opacity(Double(eased))
            .scaleEffect(size)
            .offset(y: (1 - eased) * 18)
    }

    /// 0 before `start`, 1 after `end`, an S-curve between.
    static func smoothstep(_ value: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        let t = min(max((value - start) / max(end - start, 0.001), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Ease out with a small overshoot: 1.05 at its highest, back to 1 at the end.
    static func backOut(_ t: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.2
        let c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }
}

extension View {
    /// The control arrives as the sheet's `progress` goes from `start` to `end` (`SheetReveal`).
    func sheetReveal(_ progress: CGFloat, from start: CGFloat, to end: CGFloat, overshoot: Bool = false) -> some View {
        modifier(SheetReveal(progress: progress, start: start, end: end, overshoot: overshoot))
    }
}
