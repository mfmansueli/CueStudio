//
//  QuickEditExportModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Export from the editor: never above the recording (resolution, frame rate), the edit as it is,
/// real progress, saved to Photos, counted like every export, and the paywall when the free ones
/// are used up.
@MainActor
@Suite("Quick edit export")
struct QuickEditExportModelTests {
    private struct Scenario {
        let model: QuickEditExportModel
        let exporter: FakeVideoExporter
        let photos: FakePhotoSaver
        let quota: UsageQuotaService
        let takes: TakeLibraryService
        let take: Take
    }

    private func makeScenario(
        resolution: VideoResolution = .hd1080, frameRate: FrameRate = .fps30, used: Int = 0, tier: MembershipTier = .free
    ) -> Scenario {
        var take = TestData.take(scriptID: nil, number: 3)
        take.resolution = resolution
        take.frameRate = frameRate
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let defaults = UserDefaults(suiteName: "export-\(UUID().uuidString)") ?? .standard
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: used), defaults: defaults)
        let exporter = FakeVideoExporter()
        let photos = FakePhotoSaver()
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.timeline.trimEnd(to: 10)
        let model = QuickEditExportModel(
            take: take, videoURL: URL(fileURLWithPath: "/tmp/take.mov"), edit: { edit }, takes: takes, quota: quota,
            tier: { tier }, exporter: exporter, photos: photos, editing: FakeTakeEditor()
        )
        return Scenario(model: model, exporter: exporter, photos: photos, quota: quota, takes: takes, take: take)
    }

    @Test func nothingAboveTheRecording() {
        let hd = makeScenario()
        #expect(hd.model.canExport(.hd720))
        #expect(hd.model.canExport(.hd1080))
        #expect(!hd.model.canExport(.uhd4K))
        #expect(hd.model.frameRates == [30, 60])
        #expect(!hd.model.canExport(frameRate: 60))
        #expect(hd.model.limitNote == "4K needs a take recorded in 4K. 60 fps needs a take recorded at 60 fps.")
        let uhd = makeScenario(resolution: .uhd4K, frameRate: .fps60)
        #expect(uhd.model.canExport(.uhd4K))
        #expect(uhd.model.canExport(frameRate: 60))
        #expect(uhd.model.limitNote == nil)
        let film = makeScenario(frameRate: .fps24)
        #expect(film.model.frameRates == [24, 60])
        #expect(film.model.frameRate == 24)
    }

    @Test func theSizeFollowsResolutionAndFrameRate() {
        let scenario = makeScenario(resolution: .uhd4K, frameRate: .fps60)
        // 10 s at 1080p: about 22 MB.
        #expect(scenario.model.estimatedSize == "≈ 22 MB")
        scenario.model.resolution = .uhd4K
        scenario.model.frameRate = 60
        #expect(scenario.model.estimatedSize == "≈ 98 MB")
    }

    @Test func anExportSavesToPhotosAndCounts() async {
        let scenario = makeScenario()
        #expect(scenario.model.exportsLeftLabel == "5 of 5 free exports left")
        scenario.model.resolution = .hd720
        await scenario.model.start()
        guard case .done = scenario.model.phase else {
            Issue.record("Expected done, got \(scenario.model.phase)")
            return
        }
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.quota.exportsUsed == 1)
        #expect(scenario.takes.take(id: scenario.take.id)?.isExported == true)
        let options = scenario.exporter.exports.first
        #expect(options?.shortSide == 720)
        #expect(options?.frameRate == 30)
        #expect(abs((options?.edit?.editedDuration ?? 0) - 10) < 0.001)
        #expect(scenario.model.exportsLeftLabel == "4 of 5 free exports left")
    }

    @Test func usedUpOpensThePaywallThenGoesOn() async {
        var tier = MembershipTier.free
        var take = TestData.take(scriptID: nil, number: 3)
        take.resolution = .hd1080
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let defaults = UserDefaults(suiteName: "export-\(UUID().uuidString)") ?? .standard
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: UsagePolicy.freeExports), defaults: defaults)
        let exporter = FakeVideoExporter()
        let model = QuickEditExportModel(
            take: take, videoURL: URL(fileURLWithPath: "/tmp/take.mov"), edit: { TakeEdit(sourceDuration: 20, aspect: .portrait) },
            takes: takes, quota: quota, tier: { tier }, exporter: exporter, photos: FakePhotoSaver(), editing: FakeTakeEditor()
        )
        await model.start()
        #expect(model.paywall == .export)
        #expect(exporter.exports.isEmpty)
        tier = .subscriber
        await model.continueAfterPurchase()
        #expect(exporter.exports.count == 1)
        #expect(model.exportsLeftLabel == nil)
    }

    @Test func aFailureSaysWhyAndCanBeTriedAgain() async {
        let scenario = makeScenario()
        scenario.exporter.error = VideoExportError.exportUnavailable
        await scenario.model.start()
        guard case .failed = scenario.model.phase else {
            Issue.record("Expected failed, got \(scenario.model.phase)")
            return
        }
        #expect(scenario.quota.exportsUsed == 0)
        scenario.model.retry()
        #expect(scenario.model.phase == .setup)
    }
}
