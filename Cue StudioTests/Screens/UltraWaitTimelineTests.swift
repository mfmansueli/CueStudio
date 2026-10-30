//
//  UltraWaitTimelineTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Ultra AI's scene round the star: its chapters follow the passes without ever holding the script back, each moon is born on its own, a
/// long chapter sends its comets, and the finish falls into the star before its wave.
@MainActor
@Suite("Ultra AI's wait")
struct UltraWaitTimelineTests {
    @Test func eachChapterStartsWithItsPassAndItsMoonIsBornAsTheNextBegins() throws {
        let timeline = UltraWaitTimeline(passStarts: [10, 22, 35], count: 3)
        #expect(timeline.starts == [10, 22, 35])
        #expect(timeline.chapter(at: 9) == nil && timeline.chapter(at: 10) == 0 && timeline.chapter(at: 30) == 1 && timeline.chapter(at: 40) == 2)
        #expect(timeline.moonBirth(of: 0) == 22 && timeline.moonBirth(of: 1) == 35)
        #expect(timeline.moonBirth(of: 2) == nil, "the last moon is born in the finish")
        #expect(timeline.entry(of: 1, at: 22.5) == 0.5 && timeline.entry(of: 1, at: 30) == 1)
    }

    @Test func passesThatComeAtOnceStillBearTheirMoonsOneByOne() {
        let timeline = UltraWaitTimeline(passStarts: [10, 10.1, 10.2], count: 3)
        let expected = [10, 10 + UltraWaitTimeline.hold, 10 + 2 * UltraWaitTimeline.hold]
        #expect(zip(timeline.starts, expected).allSatisfy { abs($0 - $1) < 1e-9 } && timeline.starts.count == 3)
        #expect(timeline.chapter(at: 10.5) == 0, "the scene runs behind; the script never waits for it")
    }

    @Test func withoutTheCheckTheSecondChapterIsTheVoice() {
        let moment = UltraSceneMoment(time: 9, finish: nil, passStarts: [0, 8], count: 2, arrivals: [], pass: 1, passShown: 0.5)
        #expect(moment.beam == 0, "no check, no beam")
        #expect(moment.warmth == 0.5, "the polish warms the disk as it comes")
    }

    @Test func aLongChapterSendsACometEveryTwentySeconds() {
        let timeline = UltraWaitTimeline(passStarts: [0, 10, 60], count: 3)
        #expect(timeline.comets(in: 0, until: 9).isEmpty)
        #expect(timeline.comets(in: 1, until: 55) == [30, 50])
        #expect(timeline.comets(in: 1, until: 200) == [30, 50], "none once the next chapter began")
        let moment = UltraSceneMoment(
            time: 30 + UltraWaitTimeline.cometFlight / 2, finish: nil, passStarts: [0, 10, 60], count: 3, arrivals: [], pass: 1, passShown: 0.5
        )
        #expect(moment.comets == [30] && abs(moment.flare - 1) < 1e-9, "the disk flares as the comet passes over it")
    }

    @Test func shootingStarsComeEverySixToTenSeconds() {
        let moments = UltraWaitTimeline.shootingStars(since: 100, until: 190)
        #expect(moments.first == 104)
        for (earlier, later) in zip(moments, moments.dropFirst()) {
            #expect((6...10).contains(later - earlier))
        }
        #expect(moments == UltraWaitTimeline.shootingStars(since: 100, until: 190), "the same in every run")
    }

    @Test func meteorShowersAndCometsPassOutsideTheRing() {
        let showers = UltraWaitTimeline.showers(since: 0, until: 60)
        let comets = UltraWaitTimeline.passingComets(since: 0, until: 60)
        #expect(showers.first == 7 && comets.first == 10)
        for (earlier, later) in zip(showers, showers.dropFirst()) { #expect((11...16).contains(later - earlier)) }
        for (earlier, later) in zip(comets, comets.dropFirst()) { #expect((13...19).contains(later - earlier)) }
    }

    @Test func theCheckSweepsItsBeamAndTheFinishFallsBeforeItsWave() {
        let checking = UltraSceneMoment(time: 12, finish: nil, passStarts: [0, 11, 30], count: 3, arrivals: [], pass: 1, passShown: 0.2)
        #expect(checking.beam == 1 && checking.warmth == 0)
        let falling = UltraSceneMoment(
            time: 40 + IdeaTransitionService.ultraFlashTime / 2, finish: 40, passStarts: [0, 11, 30], count: 3, arrivals: [], pass: 2, passShown: 1
        )
        #expect(abs(falling.fall - 0.5) < 1e-9 && falling.wave == nil && falling.warmth == 1)
        let flashed = UltraSceneMoment(
            time: 40 + IdeaTransitionService.ultraFlashTime + 0.35, finish: 40, passStarts: [0, 11, 30], count: 3, arrivals: [], pass: 2, passShown: 1
        )
        #expect(flashed.fall == 1 && abs((flashed.wave ?? 0) - 0.5) < 1e-9)
    }

    @Test func theDraftsWordsAreTheDisksSpecks() {
        let arrivals = [
            WritingArrival(pass: 0, fraction: 0.1, time: 3), WritingArrival(pass: 0, fraction: 0.2, time: 4),
            WritingArrival(pass: 1, fraction: 0.1, time: 12),
        ]
        let moment = UltraSceneMoment(time: 13, finish: nil, passStarts: [0, 11], count: 3, arrivals: arrivals, pass: 1, passShown: 0.1)
        #expect(moment.draftArrivals == [3, 4])
    }
}
