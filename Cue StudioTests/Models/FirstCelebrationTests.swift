//
//  FirstCelebrationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// D4 (owner, 09/11/2026): one full screen in the first journey at most. A post confirmed right away makes the send-off the celebration (the
/// first star and the milestone icon in it); a review left without one keeps the first star for Takes; a post confirmed later gets the icon due.
@Suite("FirstCelebration")
struct FirstCelebrationTests {
    private func leaving(
        flightDone: Bool = true, firstStarShown: Bool = false, celebrations: Bool = true, imported: Bool = false, videos: Int = 1, posts: Int = 0
    ) -> FirstCelebration.LeavingFacts {
        FirstCelebration.LeavingFacts(
            flightDone: flightDone, firstStarShown: firstStarShown, celebrations: celebrations, takeIsImported: imported,
            recordedVideos: videos, confirmedPosts: posts
        )
    }

    // MARK: - Posted right away

    @Test func theFirstPostConfirmedRightAwayToldInTheSendOffWithAurora() {
        let moment = FirstCelebration.sendOff(firstStarShown: false, isFirstVideo: true, confirmedPosts: 1, dueMilestone: 1)
        #expect(moment.isFirstStar)
        #expect(moment.milestone == 1 && moment.icon == .aurora)
    }

    @Test func aStarAlreadyLitInTakesIsNotToldAgainButAuroraStillIs() {
        // Left the review first (the star lit in Takes), posted later: the send-off shows the icon, not the star.
        let moment = FirstCelebration.sendOff(firstStarShown: true, isFirstVideo: true, confirmedPosts: 1, dueMilestone: 1)
        #expect(!moment.isFirstStar)
        #expect(moment.icon == .aurora)
    }

    @Test func laterPostsTellOnlyTheMilestoneDue() {
        #expect(FirstCelebration.sendOff(firstStarShown: true, isFirstVideo: true, confirmedPosts: 5, dueMilestone: nil) == SendOffMoment())
        let tenth = FirstCelebration.sendOff(firstStarShown: true, isFirstVideo: true, confirmedPosts: 10, dueMilestone: 10)
        #expect(!tenth.isFirstStar && tenth.icon == .firstLight)
        #expect(FirstCelebration.sendOff(firstStarShown: true, isFirstVideo: true, confirmedPosts: 25, dueMilestone: 25).icon == .deepSpace)
        #expect(FirstCelebration.sendOff(firstStarShown: true, isFirstVideo: true, confirmedPosts: 50, dueMilestone: 50).icon == .constellation)
    }

    @Test func aSecondPostWithTheStarUntoldIsNotTheFirstStar() {
        #expect(!FirstCelebration.sendOff(firstStarShown: false, isFirstVideo: true, confirmedPosts: 2, dueMilestone: nil).isFirstStar)
    }

    @Test func aFirstPostOfALaterOrImportedVideoIsNotTheFirstStarButOpensAurora() {
        // A library with other recorded videos (or a video brought from Photos): "FIRST VIDEO" would not be true; the icon still is.
        let moment = FirstCelebration.sendOff(firstStarShown: false, isFirstVideo: false, confirmedPosts: 1, dueMilestone: 1)
        #expect(!moment.isFirstStar)
        #expect(moment.icon == .aurora)
    }

    // MARK: - Left without posting

    @Test func leavingTheFirstVideosReviewWithoutAPostKeepsTheStarForTakes() {
        #expect(FirstCelebration.takesKeepsFirstStar(leaving()))
    }

    @Test func noStarForTakesOnceItWasToldOrAPostWasConfirmed() {
        #expect(!FirstCelebration.takesKeepsFirstStar(leaving(firstStarShown: true)))
        #expect(!FirstCelebration.takesKeepsFirstStar(leaving(posts: 1)), "the send-off told it")
    }

    @Test func noStarForAnImportedVideoAMidFlightReviewOrWithCelebrationsOff() {
        #expect(!FirstCelebration.takesKeepsFirstStar(leaving(imported: true)))
        #expect(!FirstCelebration.takesKeepsFirstStar(leaving(flightDone: false)))
        #expect(!FirstCelebration.takesKeepsFirstStar(leaving(celebrations: false)))
    }

    @Test func theStarIsTheFirstVideosNotTheThirds() {
        #expect(!FirstCelebration.takesKeepsFirstStar(leaving(videos: 3)))
    }

    @Test func aScriptsTakesAreOneVideoAndImportsDontCount() {
        let script = UUID()
        var imported = TestData.take(scriptID: nil)
        imported.origin = .imported
        let takes = [TestData.take(scriptID: script, number: 1), TestData.take(scriptID: script, number: 2), imported]
        #expect(FirstCelebration.recordedVideos(in: takes) == 1, "a retake is the same video")
        #expect(FirstCelebration.recordedVideos(in: takes + [TestData.take(scriptID: nil)]) == 2, "a freestyle take is a video of its own")
    }
}
