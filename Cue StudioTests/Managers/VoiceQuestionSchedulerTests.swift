//
//  VoiceQuestionSchedulerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// 08 §3–§5: the order of the queue, and when the My Cue Voice tip may show, with a fake clock.
@MainActor
@Suite("My Cue Voice question scheduler")
struct VoiceQuestionSchedulerTests {
    private final class Clock {
        /// Noon, so a few hours either way stay on the same day.
        var now = Date(timeIntervalSince1970: 1_799_971_200 + 12 * 3600)

        func advance(days: Double) { now.addTimeInterval(days * 24 * 3600) }
    }

    private struct Rig {
        let scheduler: VoiceQuestionScheduler
        let profile: CreatorProfileService
        let clock: Clock
        let defaults: TestDefaults
    }

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    /// A creator who has the essentials, has opened the app on two days and has a script.
    private func make(essentials: Bool = true, openedDays: Int = 2) -> Rig {
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        if essentials {
            profile.saveVoiceSetup(role: .entertainer, niches: [.food], vocabulary: .simple, sounds: [.casual])
            profile.answerAudienceLevel(.some)
        }
        let clock = Clock()
        let scheduler = VoiceQuestionScheduler(profile: profile, defaults: defaults.defaults, now: { clock.now }, calendar: Self.utc)
        for index in 0..<openedDays {
            if index > 0 { clock.advance(days: 1) }
            scheduler.registerAppOpen()
        }
        return Rig(scheduler: scheduler, profile: profile, clock: clock, defaults: defaults)
    }

    private func tip(_ rig: Rig, scripts: Int = 1, ai: Bool = true) -> VoiceQuestion? {
        rig.scheduler.tipQuestion(isAIAvailable: ai, scriptCount: scripts)
    }

    // MARK: - The queue

    @Test func missingEssentialsComeFirstThenPersonalityInTableOrder() {
        let rig = make(essentials: false)
        defer { rig.defaults.tearDown() }
        #expect(Array(rig.scheduler.remaining.prefix(5)) == [.role, .topics, .audience, .tone, .endings])
        let order = rig.scheduler.remaining.filter { $0.layer == .personality }
        #expect(order == [.endings, .openings, .formats, .length, .humor, .platforms, .energy, .sentences, .words, .swearing, .phrases, .avoid])
    }

    @Test func answeredQuestionsLeaveTheQueueAndTheExampleWaitsForTwoVoiceScripts() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        #expect(rig.scheduler.remaining.first == .endings)
        #expect(!rig.scheduler.remaining.contains(.example))
        rig.scheduler.recordVoiceScript(UUID())
        #expect(!rig.scheduler.remaining.contains(.example))
        rig.scheduler.recordVoiceScript(UUID())
        #expect(rig.scheduler.remaining.last == .example)
    }

    @Test func aMomentPullsItsQuestionForwardOnce() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.note(.firstExport)
        #expect(rig.scheduler.remaining.first == .platforms)
        // Once each: noting it again changes nothing, and answering removes it.
        rig.scheduler.note(.firstExport)
        #expect(rig.scheduler.state.pulledForward == ["firstExport"])
        rig.profile.answer(.platforms, with: VoiceOption(id: Platform.tiktok.rawValue, label: "TikTok"))
        #expect(rig.scheduler.remaining.first == .endings)
    }

    @Test func theSecondEditOfAVoiceScriptAsksHowTechnicalTheWordsAre() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        let id = UUID()
        rig.scheduler.recordVoiceScript(id)
        rig.scheduler.noteEdit(ofScript: id)
        #expect(rig.scheduler.remaining.first == .endings)
        rig.scheduler.noteEdit(ofScript: id)
        #expect(rig.scheduler.remaining.first == .words)
        rig.scheduler.noteEdit(ofScript: UUID())
        #expect(rig.scheduler.state.generatedEdits == 2)
    }

    // MARK: - When it shows

    @Test func nothingShowsBeforeTwoDaysAScriptAndAppleIntelligence() {
        let oneDay = make(openedDays: 1)
        defer { oneDay.defaults.tearDown() }
        #expect(tip(oneDay) == nil)
        let ready = make()
        defer { ready.defaults.tearDown() }
        #expect(tip(ready, scripts: 0) == nil)
        #expect(tip(ready, ai: false) == nil)
        #expect(tip(ready) == .endings)
    }

    @Test func noTipOnADayAToolWasIntroducedAndAShownTipTellsTheNotifications() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        var told = 0
        rig.scheduler.onTipShown = { told += 1 }
        rig.scheduler.otherIntroductionToday = { true }
        #expect(tip(rig) == nil)
        rig.scheduler.otherIntroductionToday = { false }
        #expect(tip(rig) == .endings)
        rig.scheduler.tipShown()
        #expect(told == 1)
    }

    @Test func noTipWhenTheVoiceIsOffOrComplete() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.profile.profile.usesVoiceInAI = false
        #expect(tip(rig) == nil)
    }

    @Test func oneTipADayAndThreeInAWeek() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.tipShown()
        #expect(tip(rig) == nil, "one a day")
        rig.clock.advance(days: 1)
        #expect(tip(rig) != nil)
        rig.scheduler.tipShown()
        rig.clock.advance(days: 1)
        rig.scheduler.tipShown()
        rig.clock.advance(days: 1)
        #expect(tip(rig) == nil, "three in a rolling week")
        rig.clock.advance(days: 5)
        #expect(tip(rig) != nil)
    }

    // MARK: - Dismissals

    @Test func aDismissalSnoozesThatQuestionForThreeDaysAndTheNextOneComesOn() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.dismissed(.endings)
        #expect(tip(rig) == .openings)
        rig.clock.advance(days: 2)
        #expect(tip(rig) == .openings)
        rig.clock.advance(days: 1.1)
        #expect(tip(rig) == .endings)
    }

    @Test func aQuestionDismissedTwiceGoesToTheEndOfTheQueue() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.dismissed(.endings)
        rig.clock.advance(days: 4)
        rig.scheduler.answered(.openings)
        rig.scheduler.dismissed(.endings)
        rig.clock.advance(days: 4)
        #expect(rig.scheduler.remaining.last == .endings)
        #expect(tip(rig) != .endings)
    }

    @Test func threeDismissalsInARowPauseEverythingForTwoWeeks() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.dismissed(.endings)
        rig.scheduler.dismissed(.openings)
        rig.scheduler.dismissed(.formats)
        rig.clock.advance(days: 13)
        #expect(tip(rig) == nil)
        rig.clock.advance(days: 1.1)
        #expect(tip(rig) != nil)
    }

    @Test func anAnswerBreaksTheStreakOfDismissals() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.dismissed(.endings)
        rig.scheduler.dismissed(.openings)
        rig.scheduler.answered(.formats)
        rig.scheduler.dismissed(.length)
        #expect(rig.scheduler.state.pausedUntil == nil)
    }

    @Test func noneOfTheseSkipsTheQuestionForGoodButStaysOnTheFullPage() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.skipped(.endings)
        #expect(!rig.scheduler.remaining.contains(.endings))
        rig.clock.advance(days: 30)
        #expect(tip(rig) == .openings)
        #expect(!rig.profile.profile.isFilled(VoiceField.endings), "skipping fills nothing")
    }

    // MARK: - Stopping

    @Test func itStopsAtOneHundredAndTheCompleteToastShowsOnce() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        #expect(!rig.scheduler.completionToastIsDue())
        rig.profile.profile = Self.fullProfile()
        #expect(tip(rig) == nil)
        #expect(rig.scheduler.isFinished)
        #expect(rig.scheduler.completionToastIsDue())
        rig.scheduler.completionToastShown()
        #expect(!rig.scheduler.completionToastIsDue())
    }

    @Test func resetClearsTheHistoryButNotTheDaysOpened() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.dismissed(.endings)
        rig.scheduler.skipped(.openings)
        rig.scheduler.reset()
        #expect(rig.scheduler.state.skipped.isEmpty && rig.scheduler.state.snoozedUntil.isEmpty)
        #expect(rig.scheduler.state.firstEligibleDays.count == 2)
    }

    @Test func theStateSurvivesARelaunch() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.scheduler.dismissed(.endings)
        rig.scheduler.skipped(.openings)
        let again = VoiceQuestionScheduler(profile: rig.profile, defaults: rig.defaults.defaults, now: { rig.clock.now }, calendar: Self.utc)
        #expect(again.state == rig.scheduler.state)
    }

    @Test func theTipsGatesCanBeOpenForUITests() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let scheduler = VoiceQuestionScheduler(profile: profile, defaults: defaults.defaults, skipsGates: true)
        #expect(scheduler.tipQuestion(isAIAvailable: true, scriptCount: 0) == .role)
    }

    // MARK: - Helpers

    static func fullProfile() -> CreatorProfile {
        var profile = CreatorProfile(niches: [.tech], role: .personal)
        profile.confirm(.audience)
        profile.confirm(.tone)
        profile.audienceLevel = .some
        profile.openings = ["a"]
        profile.endings = ["b"]
        profile.phrases = ["c"]
        profile.formats = [.list]
        profile.style = VoiceDelivery(energy: .high, sentences: .mixed, words: .someSlang, swearing: .mild)
        profile.avoid = ["Politics"]
        profile.reach = VoiceReach(platforms: [.reels], length: .longer, humor: .lot)
        profile.examples = (1...3).map { VoiceExample(text: "Example \($0)") }
        return profile
    }
}
