//
//  TakeReviewBackgroundExportTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The review's export as one piece of work iOS can let run outside Cue: its progress and how it runs while it lasts, the
/// take marked while it runs (still marked at the next launch = it stopped with Cue, and its review says so), iOS ending it,
/// and a full iPhone told before any work.
@MainActor
@Suite("Take review · background export")
struct TakeReviewBackgroundExportTests {
    private struct Scenario {
        let viewModel: TakeReviewViewModel
        let exporter: FakeVideoExporter
        let photos: FakePhotoSaver
        let scheduler: FakeContinuedTaskScheduler
        let preferences: PreferencesService
        let toast: ToastService
        let quota: UsageQuotaService
    }

    private let script = TestData.script(text: "Okay, real talk.")

    private func makeScenario(
        take: Take, defaults: TestDefaults, freeSpace: Int64? = 50_000_000_000,
        scheduler: FakeContinuedTaskScheduler = FakeContinuedTaskScheduler()
    ) -> Scenario {
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: 0), defaults: defaults.defaults)
        let exporter = FakeVideoExporter()
        let photos = FakePhotoSaver()
        let preferences = PreferencesService(defaults: defaults.defaults)
        let toast = ToastService()
        let viewModel = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { .free }, exporter: exporter, photos: photos,
            sharing: FakeVideoSharing(), ledger: ExportLedgerService(store: FakeExportLedgerStore(), quota: quota), editing: FakeTakeEditor(),
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: preferences, drafts: FakeDraftStore(), toast: toast,
            background: BackgroundExportRunner(scheduler: scheduler) { {} }, freeSpace: { freeSpace }
        )
        return Scenario(
            viewModel: viewModel, exporter: exporter, photos: photos, scheduler: scheduler, preferences: preferences, toast: toast, quota: quota
        )
    }

    @Test func theFileAndTheSaveRunAsOneTaskIOSCanCarryOn() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let scenario = makeScenario(take: TestData.take(scriptID: script.id), defaults: defaults)
        await scenario.viewModel.save()
        #expect(scenario.photos.savedURLs.count == 1)
        let task = try #require(scenario.scheduler.task)
        #expect(task.reports.contains(0.5))
        #expect(task.finished == true)
        #expect(scenario.scheduler.requests.map(\.title) == ["Exporting your video"])
        // Nothing left running, nothing left marked.
        #expect(scenario.viewModel.exportProgress == nil)
        #expect(scenario.viewModel.exportMode == nil)
        #expect(scenario.preferences.exportsInFlight.isEmpty)
    }

    @Test func anExportStillMarkedAtTheNextLaunchStoppedWithCue() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let take = TestData.take(scriptID: script.id)
        let before = PreferencesService(defaults: defaults.defaults)
        // Cue closed while the export ran.
        before.exportsInFlight.insert(take.id)
        let scenario = makeScenario(take: take, defaults: defaults)
        #expect(scenario.preferences.exportsInFlight.isEmpty)
        #expect(scenario.preferences.stoppedExports == [take.id])
        #expect(scenario.viewModel.exportStopped)
        // Closing the notice forgets it, for good.
        scenario.viewModel.dismissStoppedExport()
        #expect(!scenario.viewModel.exportStopped)
        #expect(PreferencesService(defaults: defaults.defaults).stoppedExports.isEmpty)
    }

    @Test func exportingAgainClearsTheStoppedNotice() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let take = TestData.take(scriptID: script.id)
        PreferencesService(defaults: defaults.defaults).exportsInFlight.insert(take.id)
        let scenario = makeScenario(take: take, defaults: defaults)
        #expect(scenario.viewModel.exportStopped)
        await scenario.viewModel.save()
        #expect(!scenario.viewModel.exportStopped)
        #expect(scenario.preferences.stoppedExports.isEmpty)
    }

    @Test func iOSEndingTheExportTellsTheCreatorAndSavesNothing() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let scheduler = FakeContinuedTaskScheduler()
        let scenario = makeScenario(take: TestData.take(scriptID: script.id), defaults: defaults, scheduler: scheduler)
        scenario.exporter.beforeFinishing = { scheduler.task?.expire() }
        await scenario.viewModel.save()
        #expect(scenario.viewModel.phase == .failed)
        #expect(scenario.viewModel.exportFailure?.line == "iOS stopped the export before it finished. Your edit is safe.")
        #expect(scenario.photos.savedURLs.isEmpty)
        #expect(scheduler.task?.finished == false)
        #expect(scenario.preferences.exportsInFlight.isEmpty)
    }

    // MARK: - Cancel export (leaving the review while it exports)

    /// "Cancel export" while the file is made: nothing is saved or counted, nothing says it failed, nothing stays marked; with iOS's
    /// continued task and without it.
    @Test(arguments: [true, false])
    func cancellingWhileTheFileIsMadeLeavesNothing(continuedTask: Bool) async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let scheduler = FakeContinuedTaskScheduler()
        scheduler.supportsBackgroundGPU = continuedTask
        let scenario = makeScenario(take: TestData.take(scriptID: script.id), defaults: defaults, scheduler: scheduler)
        let viewModel = scenario.viewModel
        scenario.exporter.beforeFinishing = {
            #expect(viewModel.canCancelExport)
            #expect(viewModel.cancelExport())
        }
        await viewModel.save()
        #expect(scenario.photos.savedURLs.isEmpty)
        #expect(scenario.quota.exportsUsed == 0)
        #expect(viewModel.phase == .idle)
        #expect(viewModel.exportFailure == nil)
        #expect(viewModel.runningAction == nil)
        #expect(!viewModel.canCancelExport)
        #expect(scenario.preferences.exportsInFlight.isEmpty)
    }

    /// A step that didn't hear the cancel ends late with its file: still nothing saved or counted, and its copy goes.
    @Test func aRenderThatEndsAfterTheCancelSavesNothing() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let scenario = makeScenario(take: TestData.take(scriptID: script.id), defaults: defaults)
        let viewModel = scenario.viewModel
        scenario.exporter.ignoresCancellation = true
        scenario.exporter.beforeFinishing = { viewModel.cancelExport() }
        await viewModel.save()
        let file = try #require(scenario.exporter.files.first)
        #expect(scenario.photos.savedURLs.isEmpty)
        #expect(scenario.quota.exportsUsed == 0)
        #expect(viewModel.exportFailure == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    /// Once the video is being saved it can't be called back: "Cancel export" says so (false), and the save ends as it would have.
    @Test func aSaveUnderWayCantBeCancelledAndEndsSaved() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let scenario = makeScenario(take: TestData.take(scriptID: script.id), defaults: defaults)
        let viewModel = scenario.viewModel
        scenario.photos.whileSaving = {
            #expect(!viewModel.canCancelExport)
            #expect(!viewModel.cancelExport())
        }
        await viewModel.save()
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.quota.exportsUsed == 1)
        guard case .readyToTravel? = viewModel.celebration else {
            Issue.record("The save shows as saved")
            return
        }
    }

    /// Nothing exporting: nothing to cancel.
    @Test func withNoExportThereIsNothingToCancel() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let scenario = makeScenario(take: TestData.take(scriptID: script.id), defaults: defaults)
        #expect(!scenario.viewModel.canCancelExport)
        #expect(!scenario.viewModel.cancelExport())
    }

    @Test func aFullIPhoneIsToldBeforeAnyWork() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let scenario = makeScenario(take: TestData.take(scriptID: script.id), defaults: defaults, freeSpace: 20_000_000)
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.isEmpty)
        #expect(scenario.viewModel.exportFailure?.line.hasPrefix("Not enough space on this iPhone. Free about ") == true)
    }
}
