//
//  FullScreenSwipeTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The swipe on the preview (`FullScreenSwipe`): down into full screen, up out of it, far enough or thrown, never sideways; and the
/// video growing out of its card under the finger (`FullScreenMorph`).
@Suite("Full screen swipe")
struct FullScreenSwipeTests {
    private func drag(_ height: CGFloat, sideways: CGFloat = 0) -> CGSize {
        CGSize(width: sideways, height: height)
    }

    @Test func downTakesTheVideoToFullScreenAndUpBringsItBack() {
        let editor = FullScreenSwipe(isFullScreen: false)
        #expect(editor.follow(drag(160)) == 0.5)
        #expect(editor.follow(drag(500)) == 1)
        #expect(editor.follow(drag(-60)) == 0, "up is not the way in")
        #expect(editor.changes(drag(45), predicted: drag(45)))
        #expect(!editor.changes(drag(30), predicted: drag(60)), "short of the distance it settles back")
        #expect(editor.speed(drag(640)) == 2, "a finger at 640 pt/s carries the video two ways' worth a second")
        let full = FullScreenSwipe(isFullScreen: true)
        #expect(full.follow(drag(-320)) == 1)
        #expect(full.changes(drag(-50), predicted: drag(-50)))
        #expect(!full.changes(drag(90), predicted: drag(300)), "down is not the way out")
    }

    @Test func aThrowChangesItHoweverShortAndSidewaysNeverDoes() {
        let editor = FullScreenSwipe(isFullScreen: false)
        #expect(editor.changes(drag(20), predicted: drag(260)))
        #expect(editor.follow(drag(60, sideways: 80)) == 0)
        #expect(!editor.changes(drag(60, sideways: 80), predicted: drag(300, sideways: 300)))
    }

    /// From the card (its place, size and corners) to the whole screen, the arrow from the card's foot to over the hint.
    @Test func theVideoGrowsOutOfItsCardIntoFullScreen() {
        let card = CGRect(x: 100, y: 80, width: 200, height: 356)
        let full = CGRect(x: 0, y: 0, width: 400, height: 712)
        let screen = CGSize(width: 400, height: 712)
        var morph = FullScreenMorph(card: card, full: full, screen: screen, cardRadius: 6, moves: true, shown: 0)
        #expect(morph.scale == 0.5)
        #expect(morph.offset == CGSize(width: 0, height: -98))
        #expect(morph.cornerRadius == 12, "the card's 6 pt corners, on a picture drawn at half its size")
        #expect(morph.arrowCenter == CGPoint(x: 200, y: card.maxY - 22))
        #expect(morph.hintOpacity == 0)
        #expect(morph.pictureOpacity == 1)
        morph.shown = 1
        #expect(morph.scale == 1 && morph.offset == .zero && morph.cornerRadius == 0)
        #expect(morph.arrowCenter == CGPoint(x: 200, y: 712 - 70 - 4 - 22))
        #expect(morph.hintOpacity == 1)
        morph.shown = 1.05
        #expect(morph.cover == 1, "the dark and the hint never overshoot with the spring")
    }

    @Test func withReduceMotionFullScreenFadesInPlace() {
        let morph = FullScreenMorph(
            card: CGRect(x: 100, y: 80, width: 200, height: 356), full: CGRect(x: 0, y: 0, width: 400, height: 712),
            screen: CGSize(width: 400, height: 712), cardRadius: 6, moves: false, shown: 0.5
        )
        #expect(morph.scale == 1 && morph.offset == .zero && morph.cornerRadius == 0)
        #expect(morph.pictureOpacity == 0.5)
        #expect(morph.arrowCenter == CGPoint(x: 200, y: 712 - 70 - 4 - 22), "the arrow waits over the hint")
    }
}
