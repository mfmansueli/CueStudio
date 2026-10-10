//
//  VoyageProgressTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The first voyage's steps, read from what the creator has: nothing is locked, a step done out of order counts, and the first
/// video shared completes the voyage.
@Suite("VoyageProgress")
struct VoyageProgressTests {
    private let marks = VoyageMarks(stage: .active)

    private func take(best: Bool = false, edit: TakeEdit? = nil) -> Take {
        var take = TestData.take(scriptID: UUID(), isBest: best)
        take.edit = edit
        return take
    }

    @Test func aNewCreatorStartsAtWriting() {
        let progress = VoyageProgress(scripts: 0, takes: [], shares: 0, marks: marks)
        #expect(progress.done.isEmpty)
        #expect(progress.current == .write)
        #expect(!progress.isComplete)
    }

    @Test func theFirstFlightLeavesWritingAndPracticeDone() {
        var practiced = marks
        practiced.practiced = true
        let progress = VoyageProgress(scripts: 1, takes: [], shares: 0, marks: practiced)
        #expect(progress.done == [.write, .practice])
        #expect(progress.current == .record)
        #expect(progress.doneCount == 2)
    }

    @Test func recordingCountsAsPracticeSoSkippingItNeverLeavesTheStepBehind() {
        let progress = VoyageProgress(scripts: 1, takes: [take()], shares: 0, marks: marks)
        #expect(progress.done.isSuperset(of: [.write, .practice, .record]))
        #expect(progress.current == .pick)
    }

    @Test func aStarOrAnOpenedEditPicksTheBestTake() {
        #expect(VoyageProgress(scripts: 1, takes: [take(best: true)], shares: 0, marks: marks).current == .polish)
        #expect(VoyageProgress(scripts: 1, takes: [take(edit: TakeEdit(sourceDuration: 30, aspect: .portrait))], shares: 0, marks: marks).current == .polish)
    }

    @Test func captionsACutPauseOrASkipPolishIt() {
        var captioned = TakeEdit(sourceDuration: 30, aspect: .portrait)
        captioned.captions = [CaptionCue(text: "Hello", start: 0, end: 1)]
        #expect(VoyageProgress(scripts: 1, takes: [take(best: true, edit: captioned)], shares: 0, marks: marks).current == .share)

        var cleaned = TakeEdit(sourceDuration: 30, aspect: .portrait)
        cleaned.suggestions = [CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 2, end: 3), confidence: 0.9, status: .removed)]
        #expect(VoyageProgress(scripts: 1, takes: [take(best: true, edit: cleaned)], shares: 0, marks: marks).current == .share)

        var kept = TakeEdit(sourceDuration: 30, aspect: .portrait)
        kept.suggestions = [CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 2, end: 3), confidence: 0.9, status: .kept)]
        #expect(VoyageProgress(scripts: 1, takes: [take(best: true, edit: kept)], shares: 0, marks: marks).current == .polish)

        var skipped = marks
        skipped.skippedPolish = true
        #expect(VoyageProgress(scripts: 1, takes: [take(best: true)], shares: 0, marks: skipped).current == .share)
    }

    @Test func theFirstShareCompletesTheVoyageWhateverWasSkipped() {
        let progress = VoyageProgress(scripts: 0, takes: [], shares: 1, marks: marks)
        #expect(progress.isComplete)
        #expect(progress.current == nil)
        #expect(progress.doneCount == VoyageProgress.stepCount)
    }

    @Test func aStepDoneOutOfOrderCountsAndTheCardNamesTheFirstAhead() {
        // A freestyle take with no script: writing counts (there is something to post), and picking is next.
        let progress = VoyageProgress(scripts: 0, takes: [take()], shares: 0, marks: marks)
        #expect(progress.done.contains(.write))
        #expect(progress.current == .pick)
    }
}
