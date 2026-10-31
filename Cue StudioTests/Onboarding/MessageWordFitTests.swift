//
//  MessageWordFitTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// 1.4: the practice script's words take the largest size that lets the page fit above its button, and the page scrolls only when even the
/// smallest doesn't fit.
struct MessageWordFitTests {
    /// A column that is 40 pt shorter at each step down (21 pt: 760, 13 pt: 600).
    private let heights: [CGFloat: CGFloat] = [21: 760, 19: 720, 17: 680, 15: 640, 13: 600]

    @Test func roomToSpareKeepsTheBoardsSize() {
        #expect(MessageWordFit.choice(heights: heights, available: 800) == .init(size: 21, scrolls: false))
        #expect(MessageWordFit.choice(heights: heights, available: 760) == .init(size: 21, scrolls: false))
    }

    @Test func aShorterPageShrinksTheWordsInsteadOfScrolling() {
        #expect(MessageWordFit.choice(heights: heights, available: 700) == .init(size: 17, scrolls: false))
        #expect(MessageWordFit.choice(heights: heights, available: 600) == .init(size: 13, scrolls: false))
    }

    @Test func onlyWhenNothingFitsDoesItScrollAtTheSmallestSize() {
        #expect(MessageWordFit.choice(heights: heights, available: 541) == .init(size: 13, scrolls: true))
    }

    /// Before the column is measured nothing is known to fit: the smallest size, which can scroll, never words too big for the page.
    @Test func anUnmeasuredSizeNeverCountsAsFitting() {
        #expect(MessageWordFit.choice(heights: [:], available: 800) == .init(size: 13, scrolls: true))
        #expect(MessageWordFit.choice(heights: [17: 600], available: 650) == .init(size: 17, scrolls: false))
        #expect(MessageWordFit.sizes.first == 21)
    }
}
