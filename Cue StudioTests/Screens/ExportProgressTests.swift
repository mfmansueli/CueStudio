//
//  ExportProgressTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The review's export card follows the export's real stages: a stage that can't measure itself has no number, a stage never goes
/// back (a late report of an earlier one is dropped), and iOS's Live Activity hears only the frames being written.
@MainActor
@Suite("Export progress")
struct ExportProgressTests {
    /// Reports the stages it is given, one by one, and what the review showed after each.
    @MainActor
    private final class StagedExporter: VideoExporting {
        var stages: [ExportProgress] = []
        var shown: [ExportProgress?] = []
        var review: TakeReviewViewModel?

        func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (ExportProgress) -> Void)?) async throws -> ExportResult {
            for stage in stages {
                progress?(stage)
                shown.append(review?.exportProgress)
            }
            let file = URL.temporaryDirectory.appending(path: "Cue-test-\(UUID().uuidString.prefix(8)).mov")
            try Data([0]).write(to: file)
            return ExportResult(url: file)
        }
    }

    private let script = TestData.script(text: "Okay, real talk.")

    private func makeReview(exporter: StagedExporter, scheduler: FakeContinuedTaskScheduler, defaults: TestDefaults) -> TakeReviewViewModel {
        let take = TestData.take(scriptID: script.id)
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: 0), defaults: defaults.defaults)
        let review = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { .free }, exporter: exporter, photos: FakePhotoSaver(),
            sharing: FakeVideoSharing(), ledger: ExportLedgerService(store: FakeExportLedgerStore(), quota: quota), editing: FakeTakeEditor(),
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: PreferencesService(defaults: defaults.defaults), drafts: FakeDraftStore(), toast: ToastService(),
            background: BackgroundExportRunner(scheduler: scheduler, screenAwake: ScreenAwake { _ in }) { {} }
        )
        exporter.review = review
        return review
    }

    @Test func aFractionIsKeptBetweenZeroAndOne() {
        #expect(ExportProgress(.rendering, fraction: 1.4).fraction == 1)
        #expect(ExportProgress(.motion, fraction: -0.2).fraction == 0)
        #expect(ExportProgress(.sound).fraction == nil)
        #expect(ExportProgress.Stage.preparing < .fonts && .fonts < .motion && .motion < .sound && .sound < .rendering)
    }

    @Test func theCardShowsEachStageAndNeverGoesBack() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let exporter = StagedExporter()
        exporter.stages = [
            .preparing, ExportProgress(.motion, fraction: 0.4), ExportProgress(.sound),
            // The analysis's last report, arriving after the sound started.
            ExportProgress(.motion, fraction: 0.9),
            ExportProgress(.rendering, fraction: 0.25), ExportProgress(.rendering, fraction: 1),
        ]
        let scheduler = FakeContinuedTaskScheduler()
        let review = makeReview(exporter: exporter, scheduler: scheduler, defaults: defaults)
        await review.render()
        #expect(exporter.shown == [
            .preparing, ExportProgress(.motion, fraction: 0.4), ExportProgress(.sound), ExportProgress(.sound),
            ExportProgress(.rendering, fraction: 0.25), ExportProgress(.rendering, fraction: 1),
        ])
        // The Live Activity hears the frames, not the analysis's percentage nor a stage without a number.
        #expect(scheduler.task?.reports == [0.25, 1, 1])
        #expect(review.exportProgress == nil)
    }

    @Test func anExportStartsAtPreparingWithoutANumber() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let exporter = StagedExporter()
        exporter.stages = [ExportProgress(.fonts)]
        let review = makeReview(exporter: exporter, scheduler: FakeContinuedTaskScheduler(), defaults: defaults)
        await review.render()
        #expect(exporter.shown == [ExportProgress(.fonts)])
        #expect(exporter.shown.allSatisfy { $0?.fraction == nil })
    }
}
