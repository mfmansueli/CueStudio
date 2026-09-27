//
//  TakeReviewViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("TakeReviewViewModel")
struct TakeReviewViewModelTests {
    private struct Scenario {
        let viewModel: TakeReviewViewModel
        let exporter: FakeVideoExporter
        let photos: FakePhotoSaver
        let quota: UsageQuotaService
        let takes: TakeLibraryService
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(tier: MembershipTier = .free, usedExports: Int = 0) -> Scenario {
        let defaults = TestDefaults()
        let take = TestData.take(scriptID: UUID())
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(defaults: defaults.defaults, now: { TestData.now })
        for _ in 0..<usedExports { quota.recordCleanExport(tier: .free) }
        let exporter = FakeVideoExporter()
        let photos = FakePhotoSaver()
        let toast = ToastService()
        let viewModel = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { tier },
            exporter: exporter, photos: photos, toast: toast
        )
        return Scenario(viewModel: viewModel, exporter: exporter, photos: photos, quota: quota, takes: takes, toast: toast, defaults: defaults)
    }

    @Test func freeSaveIsCleanAndCounted() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports == [ExportOptions(aspect: .portrait, watermark: false)])
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.quota.cleanExportsLeft(for: .free) == 4)
        #expect(scenario.toast.message == "Saved to Photos · 4 of 5 clean exports left")
    }

    @Test func exhaustedExportsOpenThePaywallFirst() async {
        let scenario = makeScenario(usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.viewModel.paywall == .export)
        #expect(scenario.exporter.exports.isEmpty)
        #expect(scenario.viewModel.exportNotice == "Free exports used — saves with a watermark")
    }

    @Test func watermarkFallbackExportsWithTheBadge() async {
        let scenario = makeScenario(usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        await scenario.viewModel.exportWithWatermark()
        #expect(scenario.exporter.exports == [ExportOptions(aspect: .portrait, watermark: true)])
        #expect(scenario.toast.message == "Saved with watermark")
        #expect(scenario.quota.cleanExportsUsed == 5)
    }

    @Test func proExportsAreCleanAndUncounted() async {
        let scenario = makeScenario(tier: .subscriber, usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.first?.watermark == false)
        #expect(scenario.toast.message == "Saved to Photos")
        #expect(scenario.viewModel.exportNotice == nil)
    }

    @Test func shareHandsTheFileToTheShareSheet() async {
        let scenario = makeScenario(tier: .subscriber)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share()
        #expect(scenario.viewModel.shareURL != nil)
        #expect(scenario.photos.savedURLs.isEmpty)
    }

    @Test func markingTheBestTake() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.toggleBest()
        #expect(scenario.viewModel.take?.isBest == true)
        #expect(scenario.toast.message == "Marked as best take")
    }
}
