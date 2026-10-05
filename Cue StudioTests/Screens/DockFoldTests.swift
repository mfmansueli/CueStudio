//
//  DockFoldTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// 09 §6: the dock's first row folds when the list scrolls down past 40 pt (moving more than 2 pt), unfolds on any upward movement of
/// more than 2 pt or back near the top, and never folds while the field has the focus.
@MainActor
struct DockFoldTests {
    /// Scrolls to each offset in turn and says whether the row is folded after the last one.
    private func fold(_ offsets: [CGFloat], isEditing: Bool = false) -> Bool {
        var fold = DockFold()
        for offset in offsets { fold.update(offset: offset, isEditing: isEditing) }
        return fold.isFolded
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

    @Test func unfoldsOnAnyUpwardMovement() {
        #expect(fold([200]))
        #expect(!fold([200, 190]))
    }

    @Test func unfoldsNearTheTop() {
        #expect(!fold([200, 20]))
    }

    @Test func neverFoldsWhileEditing() {
        #expect(!fold([300, 500], isEditing: true))
        var folding = DockFold()
        folding.update(offset: 500, isEditing: false)
        #expect(folding.isFolded)
        folding.update(offset: 600, isEditing: true)
        #expect(!folding.isFolded)
    }
}
