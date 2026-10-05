//
//  DockFoldTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// 09 §6: the dock's first row folds when the list scrolls down past 40 pt (moving more than 2 pt), unfolds on any upward movement of
/// more than 2 pt or back near the top, and never folds while the field has the focus. The list bouncing at its end is not a scroll.
@MainActor
struct DockFoldTests {
    /// A fold and the list it reads.
    @MainActor
    private final class Reader {
        let fold = DockFold()

        @discardableResult
        func read(_ offset: CGFloat, end: CGFloat = 2_000, isEditing: Bool = false) -> Bool {
            fold.update(DockFold.Position(offset: offset, end: end), isEditing: isEditing)
        }
    }

    /// Scrolls a long list to each offset in turn and says whether the row is folded after the last one.
    private func fold(_ offsets: [CGFloat], isEditing: Bool = false) -> Bool {
        let reader = Reader()
        for offset in offsets { reader.read(offset, isEditing: isEditing) }
        return reader.fold.isFolded
    }

    @Test func startsUnfolded() {
        #expect(!DockFold().isFolded)
    }

    @Test func foldsScrollingDownPastTheThreshold() {
        #expect(!fold([30]))
        #expect(!fold([30, 40]))
        #expect(fold([30, 40, 60]))
    }

    @Test func aTinyMoveDoesNotCountAsADirection() {
        // Down by 2 pt keeps it folded; up by 2 pt does too; up by 3 pt unfolds.
        #expect(fold([100, 102]))
        #expect(fold([100, 102, 100]))
        #expect(!fold([100, 102, 100, 97]))
    }

    @Test func aSlowScrollAddsUpItsSmallSteps() {
        // A frame at a time the list moves less than the slop; together it is a scroll down, and then one up.
        let down: [CGFloat] = stride(from: 30, through: 50, by: 1).map { $0 }
        #expect(fold(down))
        #expect(!fold(down + stride(from: 49, through: 44, by: -1).map { $0 }))
    }

    @Test func unfoldsOnAnyUpwardMovement() {
        #expect(fold([200]))
        #expect(!fold([200, 190]))
    }

    @Test func unfoldsNearTheTop() {
        #expect(!fold([200, 20]))
    }

    @Test func neverFoldsWhileEditing() {
        #expect(!fold([300, 500], isEditing: true))
        let reader = Reader()
        #expect(reader.read(500))
        #expect(!reader.read(600, isEditing: true))
    }

    @Test func theFieldTakingTheFocusUnfolds() {
        let reader = Reader()
        reader.read(500)
        #expect(!reader.fold.unfold() && !reader.fold.isFolded)
    }

    @Test func theBounceAtTheEndDoesNotUnfold() {
        let reader = Reader()
        // Scrolled down into the end, pulled past it, and let go: the list comes back to its end by itself.
        for offset: CGFloat in [900, 980, 1_000, 1_030, 1_015, 1_000] {
            reader.read(offset, end: 1_000)
        }
        #expect(reader.fold.isFolded)
        // Then the creator scrolls up: that unfolds.
        #expect(!reader.read(990, end: 1_000))
    }

    @Test func aShortListFoldsPastHalfOfItsScrollAndRestsFoldedAtItsEnd() {
        // 29 pt of scroll (measured on an iPhone): pulled to 43 pt and let go, it comes back to its end and stays folded there.
        let short = Reader()
        for offset: CGFloat in [5, 12, 18, 29, 43, 35, 29.3] { short.read(offset, end: 29.3) }
        #expect(short.fold.isFolded)
        // Scrolling it up unfolds it.
        #expect(!short.read(24, end: 29.3))
    }

    @Test func aListThatHardlyScrollsNeverFolds() {
        // 10 pt of scroll: pulled past its end it goes beyond 40 pt, but there is nothing under the dock to make room for.
        let short = Reader()
        for offset: CGFloat in [5, 20, 45, 60] { short.read(offset, end: 10) }
        #expect(!short.fold.isFolded)
    }
}
