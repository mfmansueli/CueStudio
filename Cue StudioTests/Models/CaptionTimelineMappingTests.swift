//
//  CaptionTimelineMappingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("Caption timeline boundaries")
struct CaptionTimelineMappingTests {
    @Test func segmentTimedLineIntersectingBothTrimEdgesIsClamped() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.captions = [CaptionCue(text: "kept", start: 1, end: 9)]
        edit.timeline.trimStart(to: 3)
        edit.timeline.trimEnd(to: 6)
        #expect(edit.editedCaptions.map(\.span) == [TimeSpan(start: 0, end: 3)])
        #expect(edit.editedCaptions[0].needsTimingReview)
        #expect(!edit.captions[0].needsTimingReview)
        #expect(edit.captions[0].span == TimeSpan(start: 1, end: 9))
    }

    @Test func aLineIsClippedSeparatelyOnEitherSideOfARemovedPiece() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.captions = [CaptionCue(text: "segment", start: 2, end: 8)]
        edit.timeline.removeEdited(4...6)
        #expect(edit.editedCaptions.map(\.span) == [TimeSpan(start: 2, end: 4), TimeSpan(start: 4, end: 6)])
        #expect(Set(edit.editedCaptions.map(\.id)).count == 2)
    }

    @Test func wordsCannotExtendBeyondTheRetainedAudioAtDoubleSpeed() {
        var edit = TakeEdit(sourceDuration: 5, aspect: .portrait)
        edit.captions = [CaptionCue(words: [CaptionWord(text: "word", start: 1, end: 3)])]
        edit.timeline.trimStart(to: 1.5)
        edit.timeline.trimEnd(to: 2.5)
        edit.timeline.setSpeed(2)
        #expect(edit.editedCaptions[0].span == TimeSpan(start: 0, end: 0.5))
        #expect(edit.editedCaptions[0].words[0].start == 0)
        #expect(edit.editedCaptions[0].words[0].end == 0.5)
    }

    @Test func aSplitWithoutRemovalKeepsOneStableCaption() {
        var edit = TakeEdit(sourceDuration: 5, aspect: .portrait)
        edit.captions = [CaptionCue(words: [CaptionWord(text: "first", start: 1, end: 2), CaptionWord(text: "last", start: 2, end: 3)])]
        let before = edit.editedCaptions
        edit.timeline.split(atEdited: 2)
        #expect(edit.editedCaptions == before)
    }

    @Test func reorderingAndCopiesFollowTheirSourceAndHaveStableIdentities() {
        var edit = TakeEdit(sourceDuration: 6, aspect: .portrait)
        edit.captions = [CaptionCue(text: "first", start: 0.5, end: 1.5), CaptionCue(text: "last", start: 4.5, end: 5.5)]
        edit.timeline.split(atEdited: 3)
        edit.timeline.moveSegment(from: 1, to: 0)
        #expect(edit.editedCaptions.map(\.text) == ["last", "first"])
        #expect(edit.editedCaptions.map(\.start) == [1.5, 3.5])
        edit.timeline.duplicateSegment(id: edit.timeline.segments[0].id)
        let instances = edit.editedCaptions
        #expect(instances.map(\.text) == ["last", "last", "first"])
        #expect(Set(instances.map(\.id)).count == 3)
        #expect(instances == edit.editedCaptions)
    }

    @Test func anotherTakeNeverUsesTheMainTakesCaptions() {
        var edit = TakeEdit(sourceDuration: 4, aspect: .portrait)
        let source = UUID()
        var other = CaptionCue(text: "other", start: 1, end: 2)
        other.sourceID = source
        edit.captions = [CaptionCue(text: "main", start: 1, end: 2), other]
        edit.timeline.insertClip(source: source, duration: 3)
        #expect(edit.editedCaptions.map(\.start) == [1, 5])
        var manual = CaptionCue(text: "other take", start: 1, end: 2)
        manual.sourceID = source
        #expect(CaptionRevision.split(manual, beforeWord: 1)?.1.sourceID == source)
        var timed = CaptionCue(words: [CaptionWord(text: "other", start: 1, end: 1.4), CaptionWord(text: "take", start: 1.5, end: 2)])
        timed.sourceID = source
        #expect(CaptionRevision.split(timed, beforeWord: 1)?.1.sourceID == source)
    }
}
