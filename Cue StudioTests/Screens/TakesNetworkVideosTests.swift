//
//  TakesNetworkVideosTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The library and Takes with a video per script and network (owner, 09/11/2026): the star, the review's strip, Delete with Undo, the
/// script's scope and the universe's planets.
@MainActor
@Suite("Takes · a video per network")
struct TakesNetworkVideosTests {
    private let script = UUID()

    private func take(_ number: Int, _ platform: Platform?, hoursAgo: Double = 1) -> Take {
        var take = TestData.take(scriptID: script, number: number, recordedAt: TestData.now.addingTimeInterval(-hoursAgo * 3600))
        take.platform = platform
        return take
    }

    private func makeViewModel(_ recorded: [Take]) -> (TakesViewModel, TakeLibraryService, ToastService) {
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: recorded))
        takes.load()
        let toast = ToastService()
        let viewModel = TakesViewModel(
            takes: takes, library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])), drafts: FakeDraftStore(),
            presentation: PresentationService(), toast: toast, now: { TestData.now }
        )
        return (viewModel, takes, toast)
    }

    // MARK: - The library

    @Test func theStarIsOnePerVideoNotPerScript() {
        let reels = take(1, .reels), shorts = take(2, .shorts)
        let (_, takes, _) = makeViewModel([reels, shorts])
        takes.setBest(reels.id, isBest: true)
        takes.setBest(shorts.id, isBest: true)
        #expect(takes.take(id: reels.id)?.isBest == true, "the Reels video keeps its star")
        #expect(takes.take(id: shorts.id)?.isBest == true)
    }

    @Test func theReviewsStripIsTheVideosTakes() {
        let reels1 = take(1, .reels), reels2 = take(2, .reels), shorts = take(3, .shorts)
        let (_, takes, _) = makeViewModel([reels1, reels2, shorts])
        #expect(takes.siblings(of: reels2).map(\.number) == [1, 2])
        #expect(takes.siblings(of: shorts).map(\.number) == [3])
    }

    @Test func aTakeRecordedForAnotherNetworkKeepsItsOwn() throws {
        let takes = TakeLibraryService(repository: FakeTakeRepository())
        let script = TestData.script(platform: .reels)
        let url = URL.temporaryDirectory.appending(path: "clip-\(UUID().uuidString).mov")
        let session = try takes.addTake(fileAt: url, duration: 30, script: script, camera: CameraSettings(), platform: .shorts)
        let plain = try takes.addTake(fileAt: url, duration: 30, script: script, camera: CameraSettings())
        #expect(session.platform == .shorts)
        #expect(plain.platform == .reels, "nil takes the script's network")
        #expect(plain.number == 2, "numbers keep counting per script")
    }

    // MARK: - Takes

    @Test func deleteGoesAtOnceAndUndoBringsEveryTakeBack() throws {
        let first = take(1, .reels, hoursAgo: 2), second = take(2, .reels), other = take(3, .shorts, hoursAgo: 0.5)
        let (viewModel, takes, toast) = makeViewModel([second, first, other])
        let before = takes.takes
        let video = try #require(viewModel.allVideos.first { $0.platform == .reels })
        viewModel.delete(video)
        #expect(takes.takes.map(\.id) == [other.id])
        #expect(toast.message == "Video deleted · 2 takes")
        try #require(toast.action).perform()
        #expect(takes.takes == before)
    }

    @Test func aScriptsScopeCountsOnlyItsVideosInThePipeline() {
        let mine = take(1, .reels), elsewhere = TestData.take(scriptID: UUID(), number: 1)
        let (viewModel, _, _) = makeViewModel([mine, elsewhere])
        #expect(viewModel.pipeline.count(of: .ready) == 2)
        viewModel.apply(TakesRequest(script: script, title: "Mine"), sharedVideos: [])
        #expect(viewModel.pipeline.count(of: .ready) == 1)
        #expect(viewModel.pipeline.next?.video.takes.first?.id == mine.id)
    }

    @Test func aPlanetShowsTheVideoPostedThereWhateverItWasRecordedFor() {
        let reels = take(1, .reels)
        let (viewModel, _, _) = makeViewModel([reels])
        let posted = UniverseVideo(id: reels.id, date: TestData.now, platforms: [.tiktok])
        let year = Calendar.current.component(.year, from: TestData.now)
        viewModel.apply(TakesRequest(platform: .tiktok, topic: nil, year: year), sharedVideos: [posted])
        #expect(viewModel.filter.platform == nil, "the network chip stays on All")
        #expect(viewModel.sections.flatMap(\.videos).map(\.platform) == [.reels])
    }
}
