//
//  FirstVoyageServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The first voyage's service: who sees it, what it keeps, one tip at a time, the segments lit once, hiding and bringing it back,
/// the end, and "Delete my Cue data".
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
        #expect(makeScenario().service.showsCard)
        let veteran = makeScenario(shares: 1).service
        #expect(!veteran.showsCard)
        #expect(veteran.marks.stage == .notNeeded)
        #expect(!veteran.canBeTurnedOn)
    }

    @Test func theStageIsDecidedOnceAndKept() {
        let defaults = UserDefaults(suiteName: "voyage-\(UUID().uuidString)")!
        let first = makeScenario(defaults: defaults).service
        first.markPracticed()
        // Sharing later doesn't turn it into "not needed": the card says the voyage is complete instead.
        let again = makeScenario(shares: 1, defaults: defaults).service
        #expect(again.marks.stage == .active)
        #expect(again.marks.practiced)
        #expect(again.progress.isComplete)
    }

    @Test func uiTestsWithoutTheArgumentNeverSeeItAndNothingIsSaved() {
        let scenario = makeScenario(isEnabled: false)
        #expect(!scenario.service.showsCard)
        scenario.service.markPracticed()
        scenario.service.setOn(true)
        #expect(!scenario.service.showsCard)
        #expect(scenario.defaults.data(forKey: DefaultsKey.firstVoyage) == nil)
    }

    @Test func onlyTheNextStepsTipShowsAndClosingItIsForGood() {
        let script = TestData.script()
        let service = makeScenario(scripts: [script]).service
        service.markPracticed()
        // Next is recording: no tip of its own. Practice is done, so its tip is over too.
        #expect(service.progress.current == .record)
        #expect(!service.showsTip(for: .practice))

        let fresh = makeScenario(scripts: [script]).service
        #expect(fresh.showsTip(for: .practice))
        #expect(!fresh.showsTip(for: .pick))
        fresh.closeTip(.practice)
        #expect(!fresh.showsTip(for: .practice))
        #expect(fresh.progress.current == .practice, "closing the tip doesn't do the step")
    }

    @Test func skippingPolishMovesOnToSharing() {
        let script = TestData.script()
        let service = makeScenario(scripts: [script], takes: [TestData.take(scriptID: script.id, isBest: true)]).service
        #expect(service.showsTip(for: .polish))
        service.skipPolish()
        #expect(service.progress.current == .share)
        #expect(service.showsTip(for: .share))
        #expect(!service.showsTip(for: .polish))
    }

    @Test func eachStepLightsUpOnce() {
        let script = TestData.script()
        let defaults = UserDefaults(suiteName: "voyage-\(UUID().uuidString)")!
        let before = makeScenario(scripts: [script], defaults: defaults).service
        #expect(before.stepsToCelebrate == [.write])
        before.markCelebrated([.write])
        #expect(before.stepsToCelebrate.isEmpty)
        // A take later: recording, and the practice it counts as, light up; writing doesn't again.
        let after = makeScenario(scripts: [script], takes: [TestData.take(scriptID: script.id)], defaults: defaults).service
        #expect(after.stepsToCelebrate == [.practice, .record])
    }

    @Test func hidingPutsItAwayUntilSettingsBringsItBack() {
        let service = makeScenario().service
        service.setOn(false)
        #expect(!service.showsCard)
        #expect(!service.showsTip(for: .write))
        #expect(service.canBeTurnedOn)
        service.setOn(true)
        #expect(service.showsCard)
    }

    @Test func closingTheCompletedCardEndsTheVoyageForGood() {
        let scenario = makeScenario()
        scenario.milestones.recordShare(of: UUID())
        #expect(scenario.service.showsCard, "the card says the voyage is complete")
        #expect(scenario.service.progress.current == nil)
        scenario.service.finish()
        #expect(!scenario.service.showsCard)
        #expect(!scenario.service.canBeTurnedOn)
        scenario.service.setOn(true)
        #expect(!scenario.service.showsCard)
    }

    @Test func deletingTheDataStartsTheVoyageOver() {
        let scenario = makeScenario()
        scenario.service.markPracticed()
        scenario.service.setOn(false)
        scenario.service.reset()
        #expect(scenario.service.showsCard)
        #expect(!scenario.service.marks.practiced)
    }
}
