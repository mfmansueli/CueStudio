//
//  ExportProRulesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The owner's export rules (06/11/2026): 4K export is Cue Pro, a 4K recording exports in 1080p without it (the take and its edit untouched), the
/// quota is asked before any work, a corrected video is another export while the same video again costs nothing, and the editor's Done says when
/// the last free export is the one it would use.
@MainActor
@Suite("Export · Pro rules")
struct ExportProRulesTests {
    @MainActor
    private struct Scenario {
        let viewModel: TakeReviewViewModel
        let exporter: FakeVideoExporter
        let editor: FakeTakeEditor
        let quota: UsageQuotaService
        let ledger: ExportLedgerService
        let takes: TakeLibraryService
        let scheduler: FakeContinuedTaskScheduler
        let preferences: PreferencesService
        let defaults: TestDefaults
        let take: Take
        let plan: Plan

        var used: Int { quota.exportsUsed }
    }

    private final class Plan {
        var tier: MembershipTier
        init(_ tier: MembershipTier) { self.tier = tier }
    }

    private func makeScenario(
        tier: MembershipTier = .free, used: Int = 0, resolution: VideoResolution = .hd1080,
        edit: TakeEdit? = TakeEdit(sourceDuration: 20, aspect: .portrait)
    ) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id)
        take.resolution = resolution
        take.edit = edit
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: used), defaults: defaults.defaults)
        let ledger = ExportLedgerService(store: FakeExportLedgerStore(), quota: quota)
        let exporter = FakeVideoExporter()
        let editor = FakeTakeEditor()
        let scheduler = FakeContinuedTaskScheduler()
        let preferences = PreferencesService(defaults: defaults.defaults)
        let plan = Plan(tier)
        let viewModel = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { plan.tier }, exporter: exporter, photos: FakePhotoSaver(),
            sharing: FakeVideoSharing(), ledger: ledger, editing: editor, library: library, rules: TestData.rulesService(),
            profile: CreatorProfileService(defaults: defaults.defaults), preferences: preferences, drafts: FakeDraftStore(), toast: ToastService(),
            background: BackgroundExportRunner(scheduler: scheduler) { {} }
        )
        return Scenario(
            viewModel: viewModel, exporter: exporter, editor: editor, quota: quota, ledger: ledger, takes: takes, scheduler: scheduler,
            preferences: preferences, defaults: defaults, take: take, plan: plan
        )
    }

    private func readyVideo(_ viewModel: TakeReviewViewModel) -> ExportedVideo? {
        guard case .readyToTravel(let video)? = viewModel.celebration else { return nil }
        return video
    }

    // MARK: - 4K is Pro

    /// Without Pro, 4K isn't picked: "4K export is Cue Pro" asks, and the 4K recording is saved in 1080p.
    @Test func withoutProFourKAsksAndARecordingInFourKExportsInHD() async throws {
        let scenario = makeScenario(resolution: .uhd4K)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        #expect(viewModel.exportsFourKRecordingInHD)
        viewModel.setQuality(.uhd4K)
        #expect(viewModel.offersFourKPro)
        #expect(viewModel.quality == .hd1080 && viewModel.exportQuality == .hd1080)
        await viewModel.save()
        let options = try #require(scenario.exporter.exports.last)
        #expect(options.shortSide == 1080)
        #expect(readyVideo(viewModel)?.formatLabel.hasPrefix("1080P") == true)
        // The recording stays as it was: only the file is smaller.
        #expect(scenario.takes.take(id: scenario.take.id)?.resolution == .uhd4K)
    }

    @Test func proExportsAFourKRecordingInFourK() async throws {
        let scenario = makeScenario(tier: .subscriber, resolution: .uhd4K)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        #expect(!viewModel.exportsFourKRecordingInHD)
        viewModel.setQuality(.uhd4K)
        #expect(!viewModel.offersFourKPro && viewModel.exportQuality == .uhd4K)
        await viewModel.save()
        let options = try #require(scenario.exporter.exports.last)
        #expect(options.shortSide == nil, "4K keeps the recording's resolution")
        #expect(readyVideo(viewModel)?.formatLabel.hasPrefix("4K") == true)
    }

    /// Pro bought from the question: the video goes in 4K. A plan that ends with 4K picked exports in 1080p, on a Try again or a share alike.
    @Test func buyingProFromTheQuestionPicksFourKAndAnEndedPlanExportsInHD() async throws {
        let scenario = makeScenario(resolution: .uhd4K)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        viewModel.setQuality(.uhd4K)
        viewModel.fourKProPurchased()
        #expect(viewModel.quality == .hd1080, "nothing bought, nothing changes")
        scenario.plan.tier = .subscriber
        viewModel.fourKProPurchased()
        #expect(viewModel.exportQuality == .uhd4K)
        scenario.plan.tier = .free
        #expect(viewModel.exportQuality == .hd1080)
        await viewModel.share(to: nil)
        #expect(scenario.exporter.exports.last?.shortSide == 1080)
    }

    @Test func aRecordingInHDHasNoFourKNote() {
        let scenario = makeScenario(resolution: .hd1080)
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.viewModel.exportsFourKRecordingInHD)
    }

    // MARK: - The quota, before any work

    /// The last free export used, then the video corrected: the new edit is another export, and "Your video is ready" asks before the export
    /// starts (no "Exporting your video", no render, no captions heard).
    @Test func aCorrectedVideoWithNoExportsLeftAsksBeforeAnyWork() async throws {
        let scenario = makeScenario(used: UsagePolicy.freeExports - 1)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await viewModel.save()
        #expect(scenario.used == UsagePolicy.freeExports)
        #expect(scenario.scheduler.requests.count == 1)
        try scenario.takes.applyEdit(TakeEdit(sourceDuration: 25, aspect: .portrait), to: scenario.take.id)
        viewModel.burnsInCaptions = true
        await viewModel.save()
        #expect(viewModel.showsExportReady)
        #expect(scenario.scheduler.requests.count == 1, "no export started")
        #expect(scenario.exporter.exports.count == 1)
        #expect(scenario.editor.captionRequests == 0, "no captions made for a video that waits")
        #expect(viewModel.phase == .delivered(.photoLibrary(assetID: "asset-1")))
        #expect(scenario.preferences.exportsInFlight.isEmpty)
        #expect(scenario.used == UsagePolicy.freeExports)
    }

    /// The same edit again, with none left: no question, nothing counted (the take's file may be gone: made again, same export).
    @Test func theSameVideoAgainWithNoneLeftCostsNothing() async throws {
        let scenario = makeScenario(used: UsagePolicy.freeExports - 1)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        await viewModel.save()
        // "Ready to travel" closed, then the review: its file goes.
        viewModel.celebration = nil
        viewModel.leave()
        await viewModel.save()
        #expect(!viewModel.showsExportReady)
        #expect(scenario.exporter.exports.count == 2, "made again: the file had gone")
        #expect(scenario.used == UsagePolicy.freeExports)
    }

    /// An edit made inside a "Share to universe" queue that already counted is the same export, even with no free exports left.
    @Test func anEditInsideACountedQueueCostsNothingWithNoneLeft() async throws {
        let scenario = makeScenario(used: UsagePolicy.freeExports - 1)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        let first = try #require(await viewModel.prepare(alsoSavingToPhotos: true))
        #expect(scenario.used == UsagePolicy.freeExports)
        viewModel.queueOperation = { first.operationID }
        try scenario.takes.applyEdit(TakeEdit(sourceDuration: 25, aspect: .portrait), to: scenario.take.id)
        let second = try #require(await viewModel.prepare(alsoSavingToPhotos: false))
        #expect(!viewModel.showsExportReady)
        #expect(second.operationID != first.operationID)
        #expect(viewModel.isCounted(second))
        #expect(scenario.used == UsagePolicy.freeExports)
    }

    // MARK: - Done's line

    @Test func doneSaysTheLastFreeExportAndNoneLeftOnlyWhenItCosts() async throws {
        let scenario = makeScenario(used: UsagePolicy.freeExports - 1)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        let edit = try #require(scenario.take.edit)
        #expect(viewModel.doneExportNote(for: edit) == FreeExportLabels.meter(left: 1))
        #expect(viewModel.doneExportNote(for: edit)?.text == "LAST FREE EXPORT")
        await viewModel.save()
        // That very video is out: Done says nothing about it.
        #expect(viewModel.doneExportNote(for: edit) == nil)
        // A corrected one would need Pro.
        let corrected = TakeEdit(sourceDuration: 25, aspect: .portrait)
        #expect(viewModel.doneExportNote(for: corrected)?.tone == .exhausted)
        #expect(viewModel.doneExportNote(for: corrected)?.text == "0 OF 3 LEFT · EXPORT WITH PRO")
    }

    @Test(arguments: [MembershipTier.subscriber, .free])
    func doneSaysNothingOnProOrWithExportsToSpare(tier: MembershipTier) throws {
        let scenario = makeScenario(tier: tier, used: 0)
        defer { scenario.defaults.tearDown() }
        let edit = try #require(scenario.take.edit)
        #expect(scenario.viewModel.doneExportNote(for: edit) == nil)
    }
}
