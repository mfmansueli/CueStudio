//
//  TimelineLaneLookTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// What sits on a track grows with it (`TimelineLaneLook`): at 28 pt the sizes tracks had before they grew, at 44 pt (a track
/// alone) a 14.5 pt name, and in between, every track out or under a panel, a step between.
@MainActor
@Suite("Timeline · how a track's contents grow")
struct TimelineLaneLookTests {
    @Test func atTheBaseEverythingIsTheSizeItWas() {
        let look = TimelineLaneLook(laneHeight: TimelineLaneLook.base)
        #expect(look.labelSize == 11.5)
        #expect(look.symbolSize == 10)
        #expect(look.badgeSize == 10.5)
        #expect(look.badgeHeight == 18)
        #expect(look.radius == Metrics.laneItemRadius)
        #expect(look.padding == 7)
        #expect(look.gap == 5)
        #expect(look.hintSize == 12)
        #expect(look.gutterSymbolSize == 14)
        #expect(look.chevronSize == 8)
    }

    @Test func aTrackAloneHasAFourteenAndAHalfPointNameAndABiggerChooser() {
        let look = TimelineLaneLook(laneHeight: EditorHeightClass.regular.laneHeight)
        #expect(look.labelSize == 14.5)
        #expect(look.symbolSize == 14)
        #expect(look.radius == 8)
        #expect(look.padding == 9)
        #expect(look.hintSize == 13.5)
        #expect(look.gutterSymbolSize == 17)
        #expect(look.chevronSize == 10.5)
        // The badge stays inside the track.
        #expect(look.badgeHeight < EditorHeightClass.regular.laneHeight)
    }

    @Test func everyTrackOutOrUnderAPanelItIsInBetween() {
        // Every track out on an iPhone 17 (36 pt), and under a panel (40 pt).
        #expect(TimelineLaneLook(laneHeight: 36).labelSize == 13)
        #expect(TimelineLaneLook(laneHeight: 40).labelSize == 13.5)
        // Never smaller than it was, on the shortest track.
        let shortest = TimelineLaneLook(laneHeight: 22)
        let base = TimelineLaneLook(laneHeight: TimelineLaneLook.base)
        #expect(shortest.labelSize == base.labelSize)
        #expect(shortest.gutterSymbolSize == base.gutterSymbolSize)
        #expect(shortest.chevronSize == base.chevronSize)
    }

    /// The current track's square: 40 × 36 with corners of 9 on a 44 pt track, a rounded square, not a capsule; 4 pt short of
    /// the track at each edge until 26 pt, never taller than the track.
    @Test func theChoosersSquareKeepsRoundedCornersAtEveryHeight() {
        let alone = TimelineLaneLook(laneHeight: 44)
        #expect(alone.chooserHeight == 36)
        #expect(alone.chooserRadius == 9)
        #expect(TimelineLaneLook(laneHeight: 40).chooserHeight == 32)
        #expect(TimelineLaneLook(laneHeight: 40).chooserRadius == 8)
        #expect(TimelineLaneLook(laneHeight: 28).chooserHeight == 26)
        #expect(TimelineLaneLook(laneHeight: 22).chooserHeight == 22)
        for height in stride(from: CGFloat(22), through: 56, by: 1) {
            let look = TimelineLaneLook(laneHeight: height)
            #expect(look.chooserHeight <= height)
            #expect(look.chooserRadius < look.chooserHeight / 2, "a square with rounded corners at \(height) pt, not a capsule")
        }
    }
}
