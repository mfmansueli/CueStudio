//
//  TakeStageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The stage is derived from what the creator did, never set by hand: the first rule that matches wins.
@Suite("TakeStage")
struct TakeStageTests {
    private let script = UUID()

    private func take(_ number: Int, best: Bool = false, exported: Bool = false) -> Take {
        var take = TestData.take(scriptID: script, title: "Script", number: number, isBest: best)
        take.isExported = exported
        return take
    }

    private func stage(_ takes: [Take], drafts: Set<UUID> = []) -> TakeStage {
        TakeStage(takes: takes, hasDraft: { drafts.contains($0) })
    }

    @Test func severalTakesAndNoStarMeansPickTheBest() {
        #expect(stage([take(1), take(2)]) == .pick)
        #expect(stage([take(1), take(2), take(3)]) == .pick)
    }

    @Test func aSingleTakeNeverNeedsPicking() {
        #expect(stage([take(1)]) == .ready)
    }

    @Test func aStarTakesTheVideoOutOfPick() {
        #expect(stage([take(1), take(2, best: true)]) == .ready)
    }

    /// A take recorded after the star was given (the video filmed again) puts it back to pick, and opens first; a star given afterwards, even
    /// to the old take, settles it (14.1-4).
    @Test func aTakeRecordedAfterTheStarIsToPickAgain() {
        let starredAt = Date(timeIntervalSince1970: 1_000)
        var old = take(1, best: true, exported: true)
        old.recordedAt = starredAt.addingTimeInterval(-60)
        old.bestMarkedAt = starredAt
        var again = take(2)
        again.recordedAt = starredAt.addingTimeInterval(3_600)
        #expect(stage([again, old]) == .pick)
        #expect(TakeVideo(takes: [again, old], title: "Script", platform: nil).best?.id == again.id)
        old.bestMarkedAt = again.recordedAt.addingTimeInterval(60)
        #expect(stage([again, old]) == .shared)
        #expect(TakeVideo(takes: [again, old], title: "Script", platform: nil).best?.id == old.id)
    }

    @Test func pickBeatsAnOpenEdit() {
        let takes = [take(1), take(2)]
        #expect(stage(takes, drafts: [takes[0].id]) == .pick)
    }

    @Test func anOpenEditOnAnyTakePutsTheVideoInEdit() {
        let takes = [take(1), take(2, best: true)]
        #expect(stage(takes, drafts: [takes[0].id]) == .edit)
        #expect(stage(takes, drafts: [takes[1].id]) == .edit)
    }

    @Test func anOpenEditBeatsSharedToo() {
        let takes = [take(1, best: true, exported: true)]
        #expect(stage(takes, drafts: [takes[0].id]) == .edit)
    }

    @Test func nothingExportedMeansReadyAndAnExportMeansShared() {
        #expect(stage([take(1, best: true), take(2)]) == .ready)
        #expect(stage([take(1, best: true), take(2, exported: true)]) == .shared)
        #expect(stage([take(1, exported: true)]) == .shared)
    }

    @Test func reopeningAndChangingAFinishedVideoMovesItBackToEdit() {
        var takes = [take(1, best: true, exported: true)]
        #expect(stage(takes) == .shared)
        takes[0].isExported = false
        #expect(stage(takes) == .ready)
        #expect(stage(takes, drafts: [takes[0].id]) == .edit)
    }

    @Test func theStagesRunInOrderAndSharedHasNothingNext() {
        #expect(TakeStage.allCases == [.pick, .edit, .ready, .shared])
        #expect(TakeStage.pick < .edit && TakeStage.edit < .ready && TakeStage.ready < .shared)
        #expect(TakeStage.shared.nextVerb == nil)
        #expect([TakeStage.pick, .edit, .ready].allSatisfy { $0.nextVerb != nil })
    }
}
