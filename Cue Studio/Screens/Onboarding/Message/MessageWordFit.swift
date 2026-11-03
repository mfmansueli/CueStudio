//
//  MessageWordFit.swift
//  Cue Studio
//

import CoreGraphics

/// How big the practice script's words are on 1.4: the board's 21 pt when the page fits with it, smaller for a longer language or a shorter
/// iPhone, so the heading, the card, the note and the button stay on one screen without scrolling. Only when even the smallest
/// size doesn't fit (an iPhone SE, a large text size) does the page scroll, at that smallest size so there is as little to scroll as can be.
nonisolated enum MessageWordFit {
    /// The sizes the words can take, largest first (the board's 21 pt is the first).
    static let sizes: [CGFloat] = [21, 19, 17, 15, 13]

    /// What the page does: the words' size, and whether it scrolls.
    struct Choice: Equatable {
        let size: CGFloat
        let scrolls: Bool
    }

    /// The largest size whose page (`heights`: the height of the words' column at each size, for the whole script) fits the `available`
    /// height above the button; the smallest, scrolling, when none does. A size not measured yet doesn't fit (so the page never shows
    /// words too big for it while it measures).
    static func choice(heights: [CGFloat: CGFloat], available: CGFloat) -> Choice {
        // Half a point of slack: a measured height and the space for it can differ by rounding.
        if let size = sizes.first(where: { heights[$0].map { $0 <= available + 0.5 } ?? false }) {
            return Choice(size: size, scrolls: false)
        }
        return Choice(size: sizes[sizes.count - 1], scrolls: true)
    }
}
