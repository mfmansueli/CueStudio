//
//  TakeVideoKeyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A video is a script's takes for one network (owner, 09/11/2026), and a library from before learns each take's network once.
@Suite("TakeVideoKey")
struct TakeVideoKeyTests {
    private let script = UUID()

    private func take(_ scriptID: UUID?, _ number: Int, _ platform: Platform?) -> Take {
        var take = TestData.take(scriptID: scriptID, number: number)
        take.platform = platform
        return take
    }

    @Test func aScriptsTakesForOneNetworkAreOneVideo() {
        let reels1 = take(script, 1, .reels), reels2 = take(script, 2, .reels), shorts = take(script, 3, .shorts)
        #expect(reels1.videoKey == reels2.videoKey)
        #expect(reels1.videoKey != shorts.videoKey)
        #expect(reels1.videoKey.takes(in: [reels1, shorts, reels2]).map(\.number) == [1, 2])
        #expect(TakeVideoKey.count(in: [reels1, reels2, shorts]) == 2)
    }

    @Test func aTakeWithoutAScriptIsAVideoOfItsOwn() {
        let first = take(nil, 1, .tiktok), second = take(nil, 2, .tiktok)
        #expect(first.videoKey != second.videoKey)
        #expect(first.videoKey.id == first.id.uuidString)
    }

    @Test func theIdNamesTheScriptAndTheNetwork() {
        #expect(take(script, 1, .reels).videoKey.id == "\(script.uuidString).reels")
        #expect(take(script, 1, nil).videoKey.id == script.uuidString)
    }

    @Test func theFirstCelebrationAndTheVoyageCountVideosTheSameWay() {
        let takes = [take(script, 1, .reels), take(script, 2, .shorts)]
        #expect(FirstCelebration.recordedVideos(in: takes) == 2)
        #expect(VoyageProgress.hasSingleTake(takes), "each network's video has one take")
        #expect(!VoyageProgress.hasSingleTake([take(script, 1, .reels), take(script, 2, .reels)]))
    }

    // MARK: - The one-time migration

    @Test func everyTakeOfAScriptGetsItsCurrentNetwork() {
        let gone = UUID()
        let takes = [take(script, 1, .tiktok), take(script, 2, nil), take(gone, 1, .reels), take(nil, 1, nil)]
        let result = TakePlatformMigration.migrated(takes) { $0 == script ? .shorts : nil }
        #expect(result.changed == 2)
        #expect(result.takes.map(\.platform) == [.shorts, .shorts, .reels, nil], "a gone script's take keeps its own; freestyle stays nil")
        #expect(result.takes.map(\.id) == takes.map(\.id))
        #expect(TakeVideoKey.count(in: result.takes) == 3, "the script's takes stay one video")
    }

    @Test func onlyTheNetworkChanges() {
        var starred = take(script, 1, .tiktok)
        starred.isBest = true
        starred.bestMarkedAt = TestData.now
        starred.isExported = true
        let migrated = TakePlatformMigration.migrated([starred]) { _ in .reels }.takes[0]
        var expected = starred
        expected.platform = .reels
        #expect(migrated == expected)
    }

    @MainActor
    @Test func theLibraryAdoptsTheNetworksAndSavesThem() {
        let repository = FakeTakeRepository(takes: [take(script, 1, .tiktok), take(script, 2, .tiktok)])
        let service = TakeLibraryService(repository: repository)
        service.load()
        #expect(service.adoptScriptNetworks { _ in .youtube } == 2)
        #expect(service.takes.allSatisfy { $0.platform == .youtube })
        #expect(repository.takes.allSatisfy { $0.platform == .youtube })
        #expect(service.adoptScriptNetworks { _ in .youtube } == 0, "nothing left to change")
    }
}
