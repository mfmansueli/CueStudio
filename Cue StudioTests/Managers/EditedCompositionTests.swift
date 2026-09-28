//
//  EditedCompositionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("EditedComposition")
struct EditedCompositionTests {
    @Test func soundDipsOnlyWhereSomethingWasRemoved() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 20)
        timeline.split(atEdited: 30)
        // Pieces [0,10] [10,20] [20,30] [30,60]; removing [10,20] leaves one real seam at edited 10.
        timeline.removeSegment(id: timeline.segments[1].id)
        let fades = EditedComposition.fades(for: timeline)
        let length = EditedComposition.cutFade
        #expect(fades == [
            EditedComposition.Fade(start: 10 - length, duration: length, fromVolume: 1, toVolume: 0),
            EditedComposition.Fade(start: 10, duration: length, fromVolume: 0, toVolume: 1),
        ])
    }

    @Test func anUncutTakeHasNoFades() {
        #expect(EditedComposition.fades(for: EditTimeline(sourceDuration: 30)).isEmpty)
    }

    @Test func fadesFitInsideTinyPieces() {
        var timeline = EditTimeline(sourceDuration: 1)
        timeline.split(atEdited: 0.3)
        timeline.split(atEdited: 0.315)
        timeline.split(atEdited: 0.6)
        timeline.remove([TimeSpan(start: 0.4, end: 0.5)])
        for fade in EditedComposition.fades(for: timeline) {
            #expect(fade.duration <= EditedComposition.cutFade)
            #expect(fade.start >= 0)
        }
    }
}
