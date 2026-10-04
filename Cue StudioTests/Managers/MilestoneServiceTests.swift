//
//  MilestoneServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Videos shared, and the milestones (and icons) they open.
@MainActor
@Suite("MilestoneService")
struct MilestoneServiceTests {
    private func make() -> (MilestoneService, TestDefaults) {
        let defaults = TestDefaults()
        return (MilestoneService(defaults: defaults.defaults), defaults)
    }

    @Test func theFirstShareReachesTheFirstMilestoneOnce() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let take = UUID()
        #expect(service.recordShare(of: take) == 1)
        #expect(service.recordShare(of: take) == nil, "the same video counts once")
        #expect(service.shares == 1)
    }

    @Test func onlyTheStepsAreMilestones() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        var reached: [Int] = []
        for _ in 0..<25 {
            if let milestone = service.recordShare(of: UUID()) { reached.append(milestone) }
        }
        #expect(reached == [1, 10, 25])
        #expect(service.nextMilestone == 50)
    }

    @Test func aToldMilestoneIsNotToldAgainAndTheCountSurvivesARelaunch() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let ids = (0..<10).map { _ in UUID() }
        ids.forEach { service.recordShare(of: $0) }
        service.markCelebrated(10)
        let again = MilestoneService(defaults: defaults.defaults)
        #expect(again.shares == 10 && again.celebrated.contains(10))
        #expect(again.firstShareDate != nil)
    }

    @Test func progressRunsFromOneMilestoneToTheNext() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        #expect(service.progress == 0)
        (0..<5).forEach { _ in service.recordShare(of: UUID()) }
        #expect(abs(service.progress - 4.0 / 9.0) < 0.0001, "5 shared: 4 of the 9 between 1 and 10")
    }

    @Test func iconsOpenWithTheirMilestone() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        #expect(service.isUnlocked(.standard) && !service.isUnlocked(.aurora))
        service.recordShare(of: UUID())
        #expect(service.isUnlocked(.aurora) && !service.isUnlocked(.firstLight))
    }

    @Test func theIconsAreNamedForTheCatalogAndPastTheFirstComeWithPro() {
        #expect(AppIconChoice.standard.alternateName == nil)
        #expect(AppIconChoice(alternateName: "AppIconDeepSpace") == .deepSpace)
        #expect(AppIconChoice(alternateName: "nope") == .standard)
        #expect(AppIconChoice.allCases.filter(\.needsPro) == [.firstLight, .deepSpace, .constellation])
        #expect(AppIconChoice(milestone: 25) == .deepSpace && AppIconChoice(milestone: 7) == nil && AppIconChoice(milestone: 0) == nil)
        #expect(AppIconChoice.allCases.compactMap(\.previewName).count == 4)
    }

    @Test func choosingAnIconSwitchesItAndChoosingTheSameOneDoesNothing() async {
        let service = AppIconService(switcher: InMemoryAppIcon())
        #expect(service.current == .standard)
        #expect(await service.choose(.aurora))
        #expect(service.current == .aurora)
        #expect(await service.choose(.aurora))
    }
}
