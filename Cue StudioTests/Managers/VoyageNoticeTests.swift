//
//  VoyageNoticeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the first voyage says when a step gets done: the four approved lines, only when their "Next" is the step now ahead, and the
/// steps whose tips already said the next thing pass quietly.
@MainActor
@Suite("VoyageNotice")
struct VoyageNoticeTests {
    private let marks = VoyageMarks(stage: .active)

    private func progress(scripts: Int = 1, takes: [Take] = [], shares: Int = 0, practiced: Bool = false, skipped: Bool = false) -> VoyageProgress {
        var marks = marks
        marks.practiced = practiced
        marks.skippedPolish = skipped
        return VoyageProgress(scripts: scripts, takes: takes, shares: shares, marks: marks)
    }

    private func captionedTake(_ scriptID: UUID) -> Take {
        var take = TestData.take(scriptID: scriptID, isBest: true)
        var edit = TakeEdit(sourceDuration: 30, aspect: .portrait)
        edit.captions = [CaptionCue(text: "Hello", start: 0, end: 1)]
        take.edit = edit
        return take
    }

    @Test func eachDoneStepSaysWhatComesNext() {
        let id = UUID()
        #expect(VoyageNotice.message(newlyDone: [.practice], progress: progress(practiced: true), hasCaptions: false)
            == "✓ Rehearsed · Next: record")
        #expect(VoyageNotice.message(newlyDone: [.record], progress: progress(takes: [TestData.take(scriptID: id)]), hasCaptions: false)
            == "✓ Recorded · Next: pick a take")
        #expect(VoyageNotice.message(newlyDone: [.polish], progress: progress(takes: [captionedTake(id)]), hasCaptions: true)
            == "✓ Captions on · Next: share")
        #expect(VoyageNotice.message(newlyDone: [.share], progress: progress(shares: 1), hasCaptions: false)
            == "✓ Your first star is out there")
    }

    @Test func aNextThatIsAlreadyBehindIsNeverSaid() {
        let id = UUID()
        // Recorded and starred in one go: the step ahead is Polish, not Pick.
        let both = progress(takes: [TestData.take(scriptID: id, isBest: true)])
        #expect(VoyageNotice.message(newlyDone: [.record, .pick], progress: both, hasCaptions: false) == nil)
        // A take before ever practicing: recording counts as the practice, and "Next: pick a take" is true.
        let recorded = progress(takes: [TestData.take(scriptID: id)])
        #expect(VoyageNotice.message(newlyDone: [.practice, .record], progress: recorded, hasCaptions: false) == "✓ Recorded · Next: pick a take")
    }

    @Test func writingPickingAndASkippedPolishPassQuietly() {
        let id = UUID()
        #expect(VoyageNotice.message(newlyDone: [.write], progress: progress(), hasCaptions: false) == nil)
        let picked = progress(takes: [TestData.take(scriptID: id, isBest: true)])
        #expect(VoyageNotice.message(newlyDone: [.pick], progress: picked, hasCaptions: false) == nil)
        let skipped = progress(takes: [TestData.take(scriptID: id, isBest: true)], skipped: true)
        #expect(VoyageNotice.message(newlyDone: [.polish], progress: skipped, hasCaptions: false) == nil, "no captions, no 'Captions on'")
    }
}
