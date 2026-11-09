//
//  TakeReviewExportIdentityTests.swift
//  Cue StudioTests
//

import Darwin
import Foundation
import Testing
@testable import Cue_Studio

/// A file is reused for a retry only while it would be drawn the same now (`ExportRenderStamp`, kept on the file): a media file that
/// changed, or a file whose record isn't known, is made again, and still counts as the same video for the free exports. Words drawn
/// in the system's face are told on the cover and in the message after sending.
@MainActor
@Suite("Take review · export identity")
struct TakeReviewExportIdentityTests {
    @MainActor
    private struct Scenario {
        let viewModel: TakeReviewViewModel
        let exporter: FakeVideoExporter
        let ledger: ExportLedgerService
        let quota: UsageQuotaService
        let toast: ToastService
        let defaults: TestDefaults
    }

    private let script = TestData.script(text: "Okay, real talk.")

    private func makeScenario(edit: TakeEdit? = nil) -> Scenario {
        let defaults = TestDefaults()
        var take = TestData.take(scriptID: script.id)
        take.edit = edit
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: 0), defaults: defaults.defaults)
        let ledger = ExportLedgerService(store: FakeExportLedgerStore(), quota: quota)
        let exporter = FakeVideoExporter()
        let toast = ToastService()
        let viewModel = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { .free }, exporter: exporter, photos: FakePhotoSaver(),
            sharing: FakeVideoSharing(), ledger: ledger, editing: FakeTakeEditor(), library: library, rules: TestData.rulesService(),
            profile: CreatorProfileService(defaults: defaults.defaults), preferences: PreferencesService(defaults: defaults.defaults),
            drafts: FakeDraftStore(), toast: toast
        )
        return Scenario(viewModel: viewModel, exporter: exporter, ledger: ledger, quota: quota, toast: toast, defaults: defaults)
    }

    private var readyVideo: (TakeReviewViewModel) -> ExportedVideo? {
        { review in
            if case .readyToTravel(let video)? = review.celebration { return video }
            return nil
        }
    }

    @Test func theSameEditDrawnTheSameIsReused() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        scenario.viewModel.celebration = nil
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 1)
        #expect(scenario.quota.exportsUsed == 1)
    }

    /// A file made by a Cue that kept no record (or whose record couldn't be written): what it holds can't be known, so it is made again,
    /// and it is still the video already counted.
    @Test func aFileWithoutARecordIsMadeAgainAndNotCountedTwice() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        // The file as delivered: named after the script and the take, in a folder of its own (`ExportFileName`).
        let operation = try #require(scenario.ledger.operations.first)
        let file = scenario.ledger.fileURL(of: operation)
        #expect(ExportedFileRecord.read(at: file) != nil)
        removexattr(file.path(percentEncoded: false), ExportedFileRecord.attribute, 0)
        scenario.viewModel.celebration = nil
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 2)
        #expect(scenario.quota.exportsUsed == 1)
    }

    /// The voice-over's file changed since the video was made (same name, other sound): the video is made again, without a second export.
    @Test func aMediaFileThatChangedMakesTheVideoAgain() async throws {
        let media = try EditMediaFiles.newFile(pathExtension: "caf")
        try Data(repeating: 1, count: 100).write(to: media.url)
        defer { EditMediaFiles.remove([media.name]) }
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.voiceOvers = [VoiceOverClip(fileName: media.name, duration: 2, anchor: 1)]
        let scenario = makeScenario(edit: edit)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        scenario.viewModel.celebration = nil
        try Data(repeating: 2, count: 300).write(to: media.url)
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 2)
        #expect(scenario.quota.exportsUsed == 1)
    }

    @Test func wordsInTheSystemFontAreToldOnTheCover() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.exporter.unavailableFonts = [FontPackNeed(packID: "noto-sans-jp", weight: .bold)]
        await scenario.viewModel.save()
        #expect(readyVideo(scenario.viewModel)?.fontFallback == .notDownloaded)
        // Saved again with the font still missing: the same file, and it still says so.
        scenario.viewModel.celebration = nil
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 1)
        #expect(readyVideo(scenario.viewModel)?.fontFallback == .notDownloaded)
    }

    @Test func anImportedFontThatIsGoneIsToldToo() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.exporter.missingCustomFamilies = ["My Brand Sans"]
        await scenario.viewModel.save()
        #expect(readyVideo(scenario.viewModel)?.fontFallback == .notOnThisIPhone)
    }

    @Test func aVideoDrawnInItsOwnFontsSaysNothing() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(readyVideo(scenario.viewModel)?.fontFallback == nil)
    }

    @Test func theMessageAfterSendingSaysSoToo() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.exporter.unavailableFonts = [FontPackNeed(packID: "noto-sans-jp", weight: .bold)]
        await scenario.viewModel.share(to: nil)
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.completed(activityType: "com.apple.UIKit.activity.AirDrop"), for: share)
        #expect(scenario.toast.message?.contains("Some words use the system font") == true)
    }
}
