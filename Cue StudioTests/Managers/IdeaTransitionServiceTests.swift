//
//  IdeaTransitionServiceTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// 09 §8: the star that is the transition from an idea to its script lasts at least three seconds, opens into the page when the script is
/// ready, and leaves the way it came on Cancel or an error. The clock is moved by hand, so nothing here waits for real time.
@MainActor
@Suite("Idea transition")
struct IdeaTransitionServiceTests {
    /// Time that only moves when the test says so; whoever sleeps is woken once the clock has passed its moment.
    @MainActor
    private final class ManualClock {
        private(set) var time: TimeInterval = 1_000
        private var sleepers: [(wake: TimeInterval, resume: CheckedContinuation<Void, Never>)] = []

        func sleep(_ seconds: TimeInterval) async {
            await withCheckedContinuation { continuation in
                sleepers.append((time + seconds, continuation))
            }
        }

        /// Moves the clock `seconds` forward, waking the sleepers whose moment came, then lets them run.
        func advance(_ seconds: TimeInterval) async {
            // Whoever is about to sleep gets to register first (a task started a moment ago has not run yet).
            for _ in 0..<5 { await Task.yield() }
            time += seconds
            let due = sleepers.filter { $0.wake <= time }
            sleepers.removeAll { $0.wake <= time }
            for sleeper in due { sleeper.resume.resume() }
            for _ in 0..<5 { await Task.yield() }
        }
    }

    private final class Calls {
        var aborted = 0
        var arrived = 0
    }

    private func make() -> (IdeaTransitionService, ManualClock, Calls) {
        let clock = ManualClock()
        let service = IdeaTransitionService(sleep: { await clock.sleep($0) }, now: { clock.time })
        return (service, clock, Calls())
    }

    private func begin(_ service: IdeaTransitionService, _ calls: Calls) {
        service.begin(
            from: CGPoint(x: 300, y: 700), idea: "3 things I stopped buying", platformName: "TikTok",
            abort: { calls.aborted += 1 }, arrive: { calls.arrived += 1 }
        )
    }

    /// Runs `contentReady()` in the background, so the test can move the clock while it waits.
    private func ready(_ service: IdeaTransitionService) -> Task<Void, Never> {
        Task { await service.contentReady() }
    }

    @Test func theStarRisesThenWaitsForTheAI() async {
        let (service, clock, calls) = make()
        #expect(service.phase == .idle && !service.isActive)
        begin(service, calls)
        #expect(service.phase == .rising && service.isActive)
        await clock.advance(0.59)
        #expect(service.phase == .rising)
        await clock.advance(0.02)
        #expect(service.phase == .waiting)
        #expect(service.idea == "3 things I stopped buying" && service.platformName == "TikTok")
    }

    @Test func aFastAnswerStillTakesThreeSecondsFromTheTap() async {
        let (service, clock, calls) = make()
        begin(service, calls)
        await clock.advance(0.7)
        let finished = ready(service)
        await clock.advance(2.0)
        #expect(service.phase == .waiting, "2.7 s: still waiting for the minimum")
        #expect(calls.arrived == 0)
        await clock.advance(0.31)
        #expect(service.phase == .revealing)
        #expect(calls.arrived == 1 && calls.aborted == 0)
        // The page may start writing once the cover and the ring are done (0.64 s).
        await clock.advance(IdeaTransitionService.revealLead + 0.01)
        await finished.value
    }

    @Test func aSlowAnswerIsNotHeldBack() async {
        let (service, clock, calls) = make()
        begin(service, calls)
        await clock.advance(5)
        let finished = ready(service)
        await Task.yield()
        #expect(service.phase == .revealing, "the minimum has passed: it opens at once")
        await clock.advance(IdeaTransitionService.revealLead + 0.01)
        await finished.value
    }

    @Test func theTransitionEndsByItselfAfterTheLanding() async {
        let (service, clock, calls) = make()
        begin(service, calls)
        await clock.advance(5)
        let finished = ready(service)
        await clock.advance(IdeaTransitionService.revealLead + 0.01)
        await finished.value
        #expect(service.phase == .revealing)
        await clock.advance(IdeaTransitionService.landingDuration + IdeaTransitionService.caretHold + 0.01)
        #expect(service.phase == .idle)
    }

    @Test func nothingHappensForAScriptOpenedAnyOtherWay() async {
        let (service, _, _) = make()
        await service.contentReady()
        #expect(service.phase == .idle)
    }

    @Test func cancelLeavesTakesTheScriptAwayAndIsNotAnError() async {
        let (service, clock, calls) = make()
        begin(service, calls)
        await clock.advance(1)
        service.cancel()
        #expect(service.phase == .leaving && !service.leftBecauseOfError)
        #expect(calls.aborted == 1 && calls.arrived == 0)
        await clock.advance(IdeaTransitionService.fallDuration + IdeaTransitionService.leaveFadeDuration + 0.01)
        #expect(service.phase == .idle)
        service.cancel()
        #expect(calls.aborted == 1, "a second Cancel does nothing")
    }

    @Test func anErrorLeavesTheSameWayAndSaysSo() {
        let (service, _, calls) = make()
        begin(service, calls)
        service.fail()
        #expect(service.phase == .leaving && service.leftBecauseOfError)
        #expect(calls.aborted == 1)
    }

    @Test func cancelIsIgnoredOnceTheScriptIsOpening() async {
        let (service, clock, calls) = make()
        begin(service, calls)
        await clock.advance(5)
        let finished = ready(service)
        await Task.yield()
        service.cancel()
        #expect(service.phase != .leaving)
        #expect(calls.aborted == 0)
        await clock.advance(IdeaTransitionService.revealLead + 0.01)
        await finished.value
    }

    @Test func aSpeedOfOneHalfMakesEveryTimingHalfAsLong() async {
        let (service, clock, calls) = make()
        service.speed = 0.5
        begin(service, calls)
        await clock.advance(0.31)
        #expect(service.phase == .waiting)
        let finished = ready(service)
        await clock.advance(1.2)
        #expect(service.phase == .revealing, "1.5 s is the minimum at half speed")
        await clock.advance(IdeaTransitionService.revealLead)
        await finished.value
    }

    @Test func thePhrasesEndWithTheOneForThePlatformAndTheFinishIsSeparate() {
        let phrases = IdeaTransitionService.phrases(platform: "Reels")
        #expect(phrases.count == 7)
        #expect(phrases.first == "Finding your hook…")
        #expect(phrases.last == "Shaping it for Reels")
        #expect(IdeaTransitionService.finishPhrase == "Almost camera-ready")
    }
}
