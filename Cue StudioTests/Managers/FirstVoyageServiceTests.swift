//
//  FirstVoyageServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The first voyage's service: who sees it, what it keeps, one tip at a time (the next step's), ✕ for the session, the first draft's
/// tip once, the steps done counted once (nothing said) and the first share ending it, the tips seen in place not floating again,
/// hiding and bringing it back, what is measured, and "Delete my Cue data".
@MainActor
@Suite("FirstVoyageService")
struct FirstVoyageServiceTests {
    private struct Scenario {
        let service: FirstVoyageService
        let library: ScriptLibraryService
        let takes: TakeLibraryService
        let milestones: MilestoneService
        let defaults: UserDefaults
    }

    private func makeScenario(
        scripts: [Script] = [], takes: [Take] = [], shares: Int = 0, defaults: UserDefaults? = nil, isEnabled: Bool = true
    ) -> Scenario {
        let defaults = defaults ?? UserDefaults(suiteName: "voyage-\(UUID().uuidString)")!
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: scripts))
        library.load()
        let takeLibrary = TakeLibraryService(repository: FakeTakeRepository(takes: takes))
        takeLibrary.load()
        let milestones = MilestoneService(defaults: defaults)
        for _ in 0..<shares { milestones.recordShare(of: UUID()) }
        let service = FirstVoyageService(library: library, takes: takeLibrary, milestones: milestones, defaults: defaults, isEnabled: isEnabled)
        return Scenario(service: service, library: library, takes: takeLibrary, milestones: milestones, defaults: defaults)
    }

    @Test func aNewCreatorGetsTheGuideAndOneWhoSharedBeforeNever() {
        let fresh = makeScenario().service
        #expect(fresh.isActive)
        #expect(fresh.floatingStep == .write)
        let veteran = makeScenario(shares: 1).service
        #expect(!veteran.isActive)
        #expect(veteran.floatingStep == nil)
        #expect(veteran.marks.stage == .notNeeded)
        #expect(!veteran.canBeTurnedOn)
    }

    @Test func theStageIsDecidedOnceAndKept() {
        let defaults = UserDefaults(suiteName: "voyage-\(UUID().uuidString)")!
        let first = makeScenario(defaults: defaults).service
        first.markPracticed()
        // Sharing later doesn't turn it into "not needed": the voyage says the first star is out there instead.
        let again = makeScenario(shares: 1, defaults: defaults).service
        #expect(again.marks.stage == .active)
        #expect(again.marks.practiced)
        #expect(again.progress.isComplete)
    }

    @Test func uiTestsWithoutTheArgumentNeverSeeItAndNothingIsSaved() {
        let scenario = makeScenario(isEnabled: false)
        #expect(scenario.service.floatingStep == nil)
        scenario.service.markPracticed()
        scenario.service.setOn(true)
        #expect(scenario.service.floatingStep == nil)
        #expect(scenario.defaults.data(forKey: DefaultsKey.firstVoyage) == nil)
    }

    @Test func onlyTheNextStepsTipShows() {
        let script = TestData.script()
        let service = makeScenario(scripts: [script]).service
        #expect(service.showsTip(for: .practice))
        #expect(service.floatingStep == .practice)
        #expect(!service.showsTip(for: .write) && !service.showsTip(for: .record) && !service.showsTip(for: .pick))
        service.markPracticed()
        #expect(service.floatingStep == .record)
        #expect(!service.showsTip(for: .practice))
    }

    @Test func closingATipPutsItAwayForTheSessionOnly() {
        let script = TestData.script()
        let defaults = UserDefaults(suiteName: "voyage-\(UUID().uuidString)")!
        let today = makeScenario(scripts: [script], defaults: defaults).service
        today.closeTip(.practice, at: .page)
        #expect(!today.showsTip(for: .practice))
        #expect(today.floatingStep == nil, "nothing floats either")
        #expect(today.progress.current == .practice, "closing the tip doesn't do the step")
        // The next session, the step is still ahead: its tip is back.
        let tomorrow = makeScenario(scripts: [script], defaults: defaults).service
        #expect(tomorrow.showsTip(for: .practice))
    }

    @Test func skippingPolishMovesOnToSharing() {
        let script = TestData.script()
        let service = makeScenario(scripts: [script], takes: [TestData.take(scriptID: script.id, isBest: true)]).service
        #expect(service.showsTip(for: .polish))
        service.skipPolish(at: .editor)
        #expect(service.progress.current == .share)
        #expect(service.showsTip(for: .share))
        #expect(!service.showsTip(for: .polish))
    }

    @Test func theFirstDraftsTipShowsOnceForACueDraftBeforeTheFirstTake() {
        let script = TestData.script()
        let defaults = UserDefaults(suiteName: "voyage-\(UUID().uuidString)")!
        let service = makeScenario(scripts: [script], defaults: defaults).service
        #expect(service.showsDraftTip(isCueDraft: true))
        #expect(!service.showsDraftTip(isCueDraft: false), "a script the creator wrote isn't Cue's draft")
        service.finishDraftTip(acted: true)
        #expect(!service.showsDraftTip(isCueDraft: true))
        #expect(!makeScenario(scripts: [script], defaults: defaults).service.showsDraftTip(isCueDraft: true), "it doesn't come back")
        let recorded = makeScenario(scripts: [script], takes: [TestData.take(scriptID: script.id)]).service
        #expect(!recorded.showsDraftTip(isCueDraft: true), "after the first take it's late for it")
    }

    @Test func eachStepDoneIsCountedOnceAndNothingIsSaid() {
        let script = TestData.script()
        let service = makeScenario(scripts: [script]).service
        #expect(service.stepsToAnnounce == [.write])
        service.noteStepsDone()
        #expect(service.stepsToAnnounce.isEmpty)
        service.markPracticed()
        #expect(service.stepsToAnnounce == [.practice])
        service.noteStepsDone()
        #expect(service.stepsToAnnounce.isEmpty && service.marks.announced == [.write, .practice])
    }

    @Test func theFirstShareEndsTheVoyage() {
        let scenario = makeScenario()
        scenario.milestones.recordShare(of: UUID())
        #expect(scenario.service.progress.current == nil)
        scenario.service.noteStepsDone()
        #expect(scenario.service.marks.stage == .finished)
        #expect(!scenario.service.canBeTurnedOn)
        scenario.service.setOn(true)
        #expect(!scenario.service.isActive)
    }

    @Test func aStepSeenInItsPlaceDoesNotFloatAgainThisSession() {
        let script = TestData.script()
        let defaults = UserDefaults(suiteName: "voyage-\(UUID().uuidString)")!
        let service = makeScenario(scripts: [script], defaults: defaults).service
        #expect(service.floatingStep == .practice)
        service.tipShown(.practice, at: .page)
        #expect(service.floatingStep == nil, "the page already said it")
        #expect(service.showsTip(for: .practice), "it still shows in its place")
        #expect(makeScenario(scripts: [script], defaults: defaults).service.floatingStep == .practice, "the next session it may float again")
    }

    @Test func aSingleTakeIsPickedByItselfAndTwoNeedTheCreator() {
        let script = TestData.script()
        let one = makeScenario(scripts: [script], takes: [TestData.take(scriptID: script.id)]).service
        #expect(one.progress.done.contains(.pick), "nothing to choose between")
        #expect(one.progress.current == .polish)
        let two = makeScenario(scripts: [script], takes: [TestData.take(scriptID: script.id), TestData.take(scriptID: script.id, number: 2)]).service
        #expect(two.progress.current == .pick)
        #expect(!VoyageStep.pick.tipMessage().contains("other"), "the tip never talks of takes that aren't there")
    }

    @Test func aVideoImportedFromPhotosIsNotAScriptAPracticeOrARecording() {
        var imported = TestData.take(scriptID: nil)
        imported.origin = .imported
        let service = makeScenario(takes: [imported]).service
        let done = service.progress.done
        #expect(!done.contains(.write) && !done.contains(.practice) && !done.contains(.record))
        #expect(service.progress.current == .write)
    }

    @Test func captionsAnExportMadeForItselfAreNotPickOrPolish() {
        let script = TestData.script()
        var take = TestData.take(scriptID: script.id)
        var edit = TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        edit.captions = [CaptionCue(text: "Hello", start: 0, end: 1)]
        take.edit = edit
        let first = TestData.take(scriptID: script.id, number: 2)
        let service = makeScenario(scripts: [script], takes: [take, first]).service
        #expect(!service.progress.done.contains(.pick), "an edit is not a pick")
        #expect(!service.progress.done.contains(.polish), "captions only cached by an export are shown off")
        edit.showsCaptions = true
        #expect(VoyageProgress.isPolished(edit), "turned on, they are the creator's polish")
    }

    @Test func hidingPutsItAwayUntilSettingsBringsItBackWithItsTips() {
        let service = makeScenario().service
        service.closeTip(.write, at: .scripts)
        service.setOn(false)
        #expect(service.floatingStep == nil)
        #expect(service.canBeTurnedOn)
        service.noteStepsDone()
        #expect(service.marks.announced.isEmpty, "a hidden guide counts nothing")
        service.setOn(true)
        #expect(service.floatingStep == .write, "turning it on brings the closed tip back too")
    }

    @Test func whatIsMeasuredIsTheStepThePlaceAndTheOutcomeAndShownCountsOnce() {
        let script = TestData.script()
        let service = makeScenario(scripts: [script]).service
        var events: [VoyageTelemetryEvent] = []
        service.report = { events.append($0) }
        service.tipShown(.practice, at: .page)
        service.tipShown(.practice, at: .page)
        service.tipShown(.practice, at: .scripts)
        service.tipActed(.practice, at: .scripts)
        service.closeTip(.practice, at: .page)
        service.draftTipShown()
        service.finishDraftTip(acted: false)
        #expect(events.map(\.parameters) == [
            ["tip": "practice", "place": "page", "outcome": "shown"],
            ["tip": "practice", "place": "scripts", "outcome": "shown"],
            ["tip": "practice", "place": "scripts", "outcome": "acted"],
            ["tip": "practice", "place": "page", "outcome": "closed"],
            ["tip": "draft", "place": "page", "outcome": "shown"],
            ["tip": "draft", "place": "page", "outcome": "closed"],
        ])
        events = []
        service.markPracticed()
        service.noteStepsDone()
        #expect(events.map(\.parameters) == [
            ["tip": "write", "outcome": "stepDone"], ["tip": "practice", "outcome": "stepDone"],
        ])
    }

    @Test func marksSavedByTheCardStillOpen() throws {
        // The first build of the voyage saved "closedTips" and "celebrated": the steps it lit stay said, the closed tips are forgotten.
        let json = #"{"stage":"active","practiced":true,"closedTips":[1],"celebrated":[0,1]}"#
        let marks = try JSONDecoder().decode(VoyageMarks.self, from: Data(json.utf8))
        #expect(marks.practiced)
        #expect(marks.announced == [.write, .practice])
        #expect(!marks.sawDraftTip)
    }

    @Test func deletingTheDataStartsTheVoyageOver() {
        let scenario = makeScenario()
        scenario.service.markPracticed()
        scenario.service.closeTip(.write, at: .scripts)
        scenario.service.setOn(false)
        scenario.service.reset()
        #expect(scenario.service.floatingStep == .write)
        #expect(!scenario.service.marks.practiced)
    }

    @Test func aPracticeIsFiveSecondsOfTextMovingOn() {
        #expect(!PracticeEvidence.counts(playedFor: 1, advanced: 200), "Play and Stop again")
        #expect(!PracticeEvidence.counts(playedFor: 30, advanced: 0), "the text never moved")
        #expect(PracticeEvidence.counts(playedFor: 5, advanced: 24))
    }
}
