//
//  ShareFlowTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Share to universe" (8.1), from the networks to the last "Posted on {network}?": one export for all of them, what counts and when, and only a yes
/// lights a planet.
@MainActor
@Suite("ShareFlow")
struct ShareFlowTests {
    private struct Scenario {
        let flow: ShareFlow
        let review: TakeReviewViewModel
        let exporter: FakeVideoExporter
        let photos: FakePhotoSaver
        let ledger: ExportLedgerService
        let quota: UsageQuotaService
        let queues: ShareQueueService
        let milestones: MilestoneService
        let toast: ToastService
        let take: Take
        let defaults: TestDefaults
        var finished: Finished
    }

    /// What `onFinished` heard.
    @MainActor
    final class Finished {
        var networks: [ShareDestination]?
    }

    private func makeScenario(usedExports: Int = 0, platform: Platform? = .tiktok) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id)
        take.platform = platform
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: usedExports), defaults: defaults.defaults)
        let exporter = FakeVideoExporter()
        let photos = FakePhotoSaver()
        let ledger = ExportLedgerService(store: FakeExportLedgerStore(), quota: quota)
        let toast = ToastService()
        let review = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { .free },
            exporter: exporter, photos: photos, sharing: FakeVideoSharing(), ledger: ledger, editing: FakeTakeEditor(), library: library,
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: PreferencesService(defaults: defaults.defaults), drafts: FakeDraftStore(), toast: toast
        )
        let queues = ShareQueueService(defaults: defaults.defaults)
        let milestones = MilestoneService(defaults: defaults.defaults)
        let flow = ShareFlow(
            review: review, queues: queues, milestones: milestones, library: library, defaults: defaults.defaults, toast: toast
        )
        flow.settle = .zero
        flow.copies = { _ in }
        let finished = Finished()
        flow.onFinished = { _, networks in finished.networks = networks }
        return Scenario(
            flow: flow, review: review, exporter: exporter, photos: photos, ledger: ledger, quota: quota, queues: queues, milestones: milestones,
            toast: toast, take: take, defaults: defaults, finished: finished
        )
    }

    /// The Ready screen's video: rendered, nothing delivered.
    private func rendered(_ scenario: Scenario) async -> ExportedVideo? {
        await scenario.review.render()
        guard case .readyToTravel(let video)? = scenario.review.celebration else { return nil }
        return video
    }

    // MARK: - Making the file

    @Test func renderingTheFileCountsNothingAndNeedsNoFreeExports() async throws {
        let scenario = makeScenario(usedExports: 5)
        defer { scenario.defaults.tearDown() }
        _ = try #require(await rendered(scenario))
        #expect(scenario.exporter.exports.count == 1)
        #expect(scenario.quota.exportsUsed == 5)
        #expect(!scenario.review.showsExportReady, "making the file is free; delivering it is not")
    }

    @Test func theNetworkTheScriptIsForIsTickedAndTheOthersAreNot() async throws {
        let scenario = makeScenario(platform: .reels)
        defer { scenario.defaults.tearDown() }
        scenario.flow.openPicker(with: try #require(await rendered(scenario)))
        #expect(scenario.flow.picked == [.reels] && scenario.flow.step == .picker)
        scenario.flow.toggle(.linkedin)
        scenario.flow.toggle(.reels)
        #expect(scenario.flow.picked == [.linkedin], "the order is the order they were picked")
    }

    @Test func theButtonSaysWhatItDoes() async throws {
        let scenario = makeScenario(platform: nil)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.flow.startTitle == "Pick a network" && !scenario.flow.canStart)
        scenario.flow.toggle(.tiktok)
        #expect(scenario.flow.startTitle == "Share to TikTok")
        scenario.flow.toggle(.reels)
        scenario.flow.toggle(.linkedin)
        #expect(scenario.flow.startTitle == "Share to 3 networks")
    }

    @Test func theCostLineSaysWhatIsLeft() async throws {
        let scenario = makeScenario(usedExports: 2)
        defer { scenario.defaults.tearDown() }
        scenario.flow.openPicker(with: try #require(await rendered(scenario)))
        #expect(scenario.flow.costLine?.text == "Uses 1 free export · 2 left after this")
    }

    // MARK: - One export for every network

    @Test func startingExportsOnceSavesToPhotosAndCountsOne() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.flow.openPicker(with: try #require(await rendered(scenario)))
        scenario.flow.toggle(.reels)
        scenario.flow.toggle(.linkedin)
        await scenario.flow.start()
        #expect(scenario.exporter.exports.count == 1, "one file for the three networks")
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.quota.exportsLeft(for: .free) == 4, "one export, not three")
        #expect(scenario.queues.queue(forTake: scenario.take.id)?.items.map(\.network) == [.tiktok, .reels, .linkedin])
        #expect(scenario.flow.step == .explainer, "two or more networks, the first time")
    }

    @Test func withoutSavingToPhotosNothingIsCountedUntilTheFileLeaves() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.flow.openPicker(with: try #require(await rendered(scenario)))
        scenario.flow.alsoSavesToPhotos = false
        await scenario.flow.start()
        #expect(scenario.photos.savedURLs.isEmpty && scenario.quota.exportsUsed == 0)
        #expect(scenario.flow.step == .step(.tiktok), "one network: no explanation")
    }

    @Test func theExplanationIsShownTwiceAndThenNoMore() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        for round in 1...3 {
            scenario.flow.openPicker(with: try #require(await rendered(scenario)))
            if round == 1 { scenario.flow.toggle(.reels) }
            await scenario.flow.start()
            if round <= ShareFlow.explainerTimes {
                #expect(scenario.flow.step == .explainer, "round \(round)")
                scenario.flow.finishExplainer()
            } else {
                #expect(scenario.flow.step == .step(.tiktok), "round \(round)")
            }
            #expect(scenario.flow.step == .step(.tiktok))
        }
    }

    @Test func withNoFreeExportsLeftStartingAsksForProAndMakesNoQueue() async throws {
        let scenario = makeScenario(usedExports: 5)
        defer { scenario.defaults.tearDown() }
        scenario.flow.openPicker(with: try #require(await rendered(scenario)))
        await scenario.flow.start()
        #expect(scenario.review.showsExportReady)
        #expect(scenario.queues.queue(forTake: scenario.take.id) == nil)
        #expect(scenario.photos.savedURLs.isEmpty)
        #expect(scenario.flow.costLine?.isWarning == true)
    }

    @Test func aVideoAlreadyCountedCostsNothingMoreToShare() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let video = try #require(await rendered(scenario))
        await scenario.review.save()
        scenario.flow.openPicker(with: video)
        #expect(scenario.flow.costLine?.text == "This video's export is already counted")
        let used = scenario.quota.exportsUsed
        await scenario.flow.start()
        #expect(scenario.quota.exportsUsed == used)
    }

    // MARK: - A network's turn

    /// The flow answers a finished sheet from a task of its own: waits (up to two seconds) for it to have run, however busy the tests around are.
    private func eventually(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    private func startedWithThree(_ scenario: Scenario) async throws {
        scenario.flow.openPicker(with: try #require(await rendered(scenario)))
        scenario.flow.toggle(.reels)
        scenario.flow.toggle(.linkedin)
        await scenario.flow.start()
        scenario.flow.finishExplainer()
    }

    @Test func theStepCopiesTheCaption() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        var copied: [String] = []
        scenario.flow.copies = { copied.append($0) }
        try await startedWithThree(scenario)
        #expect(copied.last == scenario.review.postCaption && scenario.flow.caption == scenario.review.postCaption)
        scenario.flow.caption = "My own words"
        scenario.flow.copy()
        #expect(copied.last == "My own words")
    }

    @Test func aFinishedShareSheetAsksWhetherItWentLive() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        try await startedWithThree(scenario)
        let operation = try #require(scenario.queues.queue(forTake: scenario.take.id)?.operationID)
        let share = ActivityShare(operationID: operation, url: URL(filePath: "/tmp/x.mov"), destination: .tiktok)
        scenario.review.activityFinished(.completed(activityType: "com.zhiliaoapp.musically.share"), for: share)
        await eventually { scenario.flow.step == .confirm(.tiktok) }
        #expect(scenario.flow.step == .confirm(.tiktok))
        #expect(scenario.review.celebration.map { if case .sentOff = $0 { true } else { false } } != true, "no send-off yet")
        #expect(scenario.milestones.shares == 0, "a share sheet is not a post")
    }

    @Test func aCancelledShareSheetGoesBackToTheStep() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        try await startedWithThree(scenario)
        let operation = try #require(scenario.queues.queue(forTake: scenario.take.id)?.operationID)
        scenario.review.activityFinished(.cancelled, for: ActivityShare(operationID: operation, url: URL(filePath: "/tmp/x.mov"), destination: .tiktok))
        try await Task.sleep(for: .milliseconds(50))
        #expect(scenario.flow.step == .step(.tiktok))
    }

    @Test func onlyYesCountsAndLightsThePlanet() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        try await startedWithThree(scenario)
        scenario.flow.notYet(.tiktok)
        #expect(scenario.flow.step == .step(.tiktok) && scenario.milestones.shares == 0)
        scenario.flow.confirmLive(.tiktok)
        #expect(scenario.milestones.shares == 1)
        #expect(scenario.milestones.records.first?.platforms == [.tiktok])
        #expect(scenario.flow.step == .step(.reels), "the next network comes up")
    }

    @Test func eachConfirmedNetworkAddsItsPlanetButTheVideoCountsOnce() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        try await startedWithThree(scenario)
        scenario.flow.confirmLive(.tiktok)
        scenario.flow.confirmLive(.reels)
        scenario.flow.confirmLive(.linkedin)
        #expect(scenario.milestones.shares == 1)
        #expect(scenario.milestones.records.first?.platforms == [.tiktok, .reels, .linkedin])
    }

    @Test func theSendOffPlaysWhenTheLastNetworkIsConfirmed() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        try await startedWithThree(scenario)
        scenario.flow.confirmLive(.tiktok)
        scenario.flow.postLater(.reels)
        scenario.flow.confirmLive(.linkedin)
        #expect(scenario.flow.step == nil)
        #expect(scenario.finished.networks == [.tiktok, .linkedin], "Reels was left for later: it is not in the send-off")
        #expect(scenario.queues.later(forTake: scenario.take.id).map(\.network) == [.reels])
    }

    @Test func ifNothingWentLiveThereIsNoSendOff() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.flow.openPicker(with: try #require(await rendered(scenario)))
        scenario.flow.alsoSavesToPhotos = false
        await scenario.flow.start()
        scenario.flow.postLater(.tiktok)
        #expect(scenario.finished.networks == nil)
        #expect(scenario.toast.message == "Saved · continue anytime")
        #expect(scenario.milestones.shares == 0)
    }

    @Test func closingLeavesTheRestForLaterAndTheCardGoes() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        try await startedWithThree(scenario)
        scenario.flow.confirmLive(.tiktok)
        scenario.flow.close()
        #expect(scenario.flow.step == nil)
        #expect(scenario.queues.pending == nil)
        #expect(scenario.queues.later(forTake: scenario.take.id).map(\.network) == [.reels, .linkedin])
        #expect(scenario.toast.message == "Saved · continue anytime")
    }

    @Test func resumingBringsTheNetworkBackWithItsFile() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        try await startedWithThree(scenario)
        scenario.flow.close()
        await scenario.flow.resume(.linkedin)
        #expect(scenario.flow.step == .step(.linkedin))
        #expect(scenario.queues.queue(forTake: scenario.take.id)?.current?.network == .linkedin)
    }

    @Test func anEditInsideTheQueueIsTheSameExport() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        try await startedWithThree(scenario)
        #expect(scenario.quota.exportsUsed == 1)
        // The creator edits first: the file is made again with other settings, and nothing more is spent.
        scenario.review.setQuality(.uhd4K)
        scenario.review.burnsInCaptions = true
        let again = await scenario.review.prepare(alsoSavingToPhotos: false, continuing: scenario.queues.queue(forTake: scenario.take.id)?.operationID)
        #expect(again != nil)
        #expect(scenario.quota.exportsUsed == 1)
        #expect(scenario.exporter.exports.count >= 2)
    }
}
