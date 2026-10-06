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

    @Test func eachShareKeepsItsDateItsPlatformAndItsTopic() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let take = UUID()
        let when = Date(timeIntervalSince1970: 1_780_000_000)
        service.recordShare(of: take, at: when, platform: .reels, topic: "niche.food")
        let again = MilestoneService(defaults: defaults.defaults)
        #expect(again.records == [ShareRecord(takeID: take, date: when, platforms: [.reels], topic: "niche.food")])
    }

    @Test func videosCountedBeforeRecordsExistedKeepCountingWithoutADate() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let old = UUID()
        defaults.defaults.set([old.uuidString], forKey: DefaultsKey.sharedTakeIDs)
        let service = MilestoneService(defaults: defaults.defaults)
        #expect(service.shares == 1 && service.sharedTakeIDs == [old])
        #expect(service.records == [ShareRecord(takeID: old, date: nil, topic: nil)])
        #expect(service.recordShare(of: old) == nil, "and it still counts once")
    }

    @Test func thePlanetsRememberWhatTheyHadWhenTheScreenWasLastOpen() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        #expect(service.seenPlanetCounts(year: 2026).isEmpty)
        service.markPlanetsSeen([.tiktok: 12, .reels: 6], year: 2026)
        #expect(service.seenPlanetCounts(year: 2026)[.tiktok] == 12)
        #expect(service.seenPlanetCounts(year: 2025).isEmpty, "each year has its own")
    }

    @Test func aVideoSharedToAnotherNetworkCountsOnceButAddsTheNetwork() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let take = UUID()
        #expect(service.recordShare(of: take, platform: .tiktok) == 1)
        #expect(service.recordShare(of: take, platform: .reels) == nil, "the milestone was told with the first")
        #expect(service.recordShare(of: take, platform: .reels) == nil && service.shares == 1)
        #expect(service.records.first?.platforms == [.tiktok, .reels])
        #expect(MilestoneService(defaults: defaults.defaults).records.first?.platforms == [.tiktok, .reels])
    }

    @Test func aRecordSavedWithOnePlatformStillReads() throws {
        let take = UUID()
        let json = #"[{"takeID":"\#(take.uuidString)","platform":"reels","topic":"niche.food"}]"#
        let records = try JSONDecoder().decode([ShareRecord].self, from: Data(json.utf8))
        #expect(records == [ShareRecord(takeID: take, date: nil, platforms: [.reels], topic: "niche.food")])
    }

    @Test func theMilestonesAreCountedInTheLiveYear() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
        (0..<12).forEach { _ in service.recordShare(of: UUID(), at: lastYear) }
        #expect(service.shares == 12 && service.yearShares == 0)
        #expect(service.nextMilestone == 1, "a new year starts its road again")
        service.recordShare(of: UUID())
        #expect(service.yearShares == 1 && service.nextMilestone == 10)
    }

    @Test func anIconWonInAnEarlierYearIsNotCelebratedAgain() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        let lastYear = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
        var reached: [Int] = []
        (0..<12).forEach { _ in if let step = service.recordShare(of: UUID(), at: lastYear) { reached.append(step) } }
        #expect(reached == [1, 10])
        #expect(service.recordShare(of: UUID()) == nil, "the first share of the new year reaches 1 again, but Aurora is already theirs")
        #expect(service.isUnlocked(.firstLight))
    }
}
