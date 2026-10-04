//
//  TakePipelineTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("TakePipeline")
struct TakePipelineTests {
    private func video(_ title: String, _ stage: TakeStage, hoursAgo: Double) -> TakeVideo {
        let take = TestData.take(
            scriptID: UUID(), title: title, number: 1, recordedAt: TestData.now.addingTimeInterval(-hoursAgo * 3600)
        )
        return TakeVideo(takes: [take], title: title, platform: .tiktok, stage: stage)
    }

    @Test func countsEveryStage() {
        let pipeline = TakePipeline(videos: [
            video("A", .ready, hoursAgo: 1), video("B", .ready, hoursAgo: 2), video("C", .shared, hoursAgo: 3),
        ])
        #expect(pipeline.count(of: .pick) == 0)
        #expect(pipeline.count(of: .edit) == 0)
        #expect(pipeline.count(of: .ready) == 2)
        #expect(pipeline.count(of: .shared) == 1)
    }

    @Test func nextIsTheEarliestStageWithAVideoWaiting() {
        let pipeline = TakePipeline(videos: [
            video("New ready", .ready, hoursAgo: 1), video("Editing", .edit, hoursAgo: 2), video("Shared", .shared, hoursAgo: 3),
        ])
        #expect(pipeline.next?.stage == .edit)
        #expect(pipeline.next?.video.title == "Editing")
    }

    @Test func nextPicksBeforeEditingBeforePosting() {
        let all = [video("Post", .ready, hoursAgo: 1), video("Edit", .edit, hoursAgo: 2), video("Pick", .pick, hoursAgo: 3)]
        #expect(TakePipeline(videos: all).next?.stage == .pick)
        #expect(TakePipeline(videos: Array(all.prefix(2))).next?.stage == .edit)
        #expect(TakePipeline(videos: Array(all.prefix(1))).next?.stage == .ready)
    }

    @Test func nextIsTheVideoThatHasWaitedLongestInThatStage() {
        // Newest first, as the library lists them.
        let pipeline = TakePipeline(videos: [
            video("Newest", .ready, hoursAgo: 1), video("Middle", .ready, hoursAgo: 5), video("Oldest", .ready, hoursAgo: 9),
        ])
        #expect(pipeline.next?.video.title == "Oldest")
    }

    @Test func nothingIsNextWhenEverythingIsSharedOrThereIsNothing() {
        #expect(TakePipeline(videos: [video("Done", .shared, hoursAgo: 1)]).next == nil)
        #expect(TakePipeline(videos: []).next == nil)
    }
}
