//
//  FirstVoyageServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The first voyage's service: who sees it, what it keeps, one tip at a time (the next step's), ✕ for the session, the first draft's
/// tip once, the notices said once and the first share ending it, hiding and bringing it back, what is measured, and "Delete my Cue
/// data".
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

    @Test func eachStepIsSaidOnceAndOnlyWhenItsNextIsTrue() {
        let script = TestData.script()
        let defaults = UserDefaults(suiteName: "voyage-\(UUID().uuidString)")!
        let before = makeScenario(scripts: [script], defaults: defaults).service
        #expect(before.stepsToAnnounce == [.write])
        #expect(before.takeNotice(hasCaptions: false) == nil, "writing passes quietly")
        #expect(before.stepsToAnnounce.isEmpty)
        before.markPracticed()
        #expect(before.takeNotice(hasCaptions: false) == "✓ Rehearsed · Next: record")
        #expect(before.takeNotice(hasCaptions: false) == nil, "said once")
        // Two takes, one starred: recording and picking at once; "Next: pick a take" would be wrong, so nothing is said.
        let after = makeScenario(
            scripts: [script], takes: [TestData.take(scriptID: script.id, isBest: true), TestData.take(scriptID: script.id, number: 2)],
            defaults: defaults
        ).service
        #expect(after.stepsToAnnounce == [.record, .pick])
        #expect(after.takeNotice(hasCaptions: false) == nil)
    }

    @Test func theFirstShareIsSaidAndEndsTheVoyage() {
        let scenario = makeScenario()
        scenario.milestones.recordShare(of: UUID())
        #expect(scenario.service.progress.current == nil)
        #expect(scenario.service.takeNotice(hasCaptions: false) == "✓ Your first star is out there")
        #expect(scenario.service.marks.stage == .finished)
        #expect(!scenario.service.canBeTurnedOn)
        scenario.service.setOn(true)
        #expect(!scenario.service.isActive)
    }

    @Test func hidingPutsItAwayUntilSettingsBringsItBackWithItsTips() {
        let service = makeScenario().service
        service.closeTip(.write, at: .scripts)
        service.setOn(false)
        #expect(service.floatingStep == nil)
        #expect(service.canBeTurnedOn)
        #expect(service.takeNotice(hasCaptions: false) == nil, "a hidden guide says nothing")
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
        _ = service.takeNotice(hasCaptions: false)
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
}
