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
        let apps: FakeAppOpener
        let editor: FakeTakeEditor
        let quota: UsageQuotaService
        let takes: TakeLibraryService
        let toast: ToastService
        let defaults: TestDefaults
    }

    /// A plan that can change mid-test, like buying Pro from the paywall.
    private final class Plan {
        var tier: MembershipTier
        init(_ tier: MembershipTier) { self.tier = tier }
    }

    private func makeScenario(tier: MembershipTier = .free, usedExports: Int = 0, take: Take? = nil) -> Scenario {
        makeScenario(plan: Plan(tier), usedExports: usedExports, take: take)
    }

    private func makeScenario(plan: Plan, usedExports: Int = 0, take: Take? = nil) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: "Okay, real talk.")
        let take = take ?? TestData.take(scriptID: script.id)
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(defaults: defaults.defaults)
        for _ in 0..<usedExports { quota.recordCleanExport(tier: .free) }
        let exporter = FakeVideoExporter()
        let photos = FakePhotoSaver()
        let apps = FakeAppOpener()
        let editor = FakeTakeEditor()
        let toast = ToastService()
        let viewModel = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { plan.tier },
            exporter: exporter, photos: photos, apps: apps, editing: editor, library: library,
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: PreferencesService(defaults: defaults.defaults), toast: toast
        )
        return Scenario(
            viewModel: viewModel, exporter: exporter, photos: photos, apps: apps, editor: editor,
            quota: quota, takes: takes, toast: toast, defaults: defaults
        )
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

    @Test func buyingProFinishesTheExportClean() async {
        let plan = Plan(.free)
        let scenario = makeScenario(plan: plan, usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.viewModel.paywall == .export)
        plan.tier = .subscriber
        await scenario.viewModel.continueAfterPurchase()
        #expect(scenario.exporter.exports == [ExportOptions(aspect: .portrait, watermark: false)])
        #expect(scenario.photos.savedURLs.count == 1)
    }

    @Test func aTakeSavedWithTheWatermarkExportsCleanOnPro() async {
        let plan = Plan(.free)
        let scenario = makeScenario(plan: plan, usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        await scenario.viewModel.exportWithWatermark()
        plan.tier = .lifetime
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.map(\.watermark) == [true, false])
    }

    @Test func moreHandsTheFileToTheShareSheet() async {
        let scenario = makeScenario(tier: .subscriber)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        #expect(scenario.viewModel.shareURL != nil)
        #expect(scenario.photos.savedURLs.isEmpty)
    }

    @Test func sharingToAPlatformSavesThenOpensItsApp() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.showsShareSheet = true
        await scenario.viewModel.share(to: .reels)
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.apps.opened == [.reels])
        #expect(scenario.viewModel.shareURL == nil)
        #expect(!scenario.viewModel.showsShareSheet)
        #expect(scenario.toast.message == "Ready to post on Reels · 4 of 5 clean left")
        #expect(scenario.viewModel.take?.isExported == true)
    }

    @Test func aMissingAppFallsBackToTheShareSheet() async {
        let scenario = makeScenario(tier: .subscriber)
        defer { scenario.defaults.tearDown() }
        scenario.apps.installed = []
        scenario.viewModel.showsShareSheet = true
        await scenario.viewModel.share(to: .tiktok)
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.viewModel.shareURL != nil)
        // The system share sheet opens on top of Share to.
        #expect(scenario.viewModel.showsShareSheet)
    }

    @Test func sharingPastTheFreeLimitAsksFirst() async {
        let scenario = makeScenario(usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: .shorts)
        #expect(scenario.viewModel.paywall == .export)
        #expect(scenario.apps.opened.isEmpty)
        await scenario.viewModel.exportWithWatermark()
        #expect(scenario.exporter.exports.first?.watermark == true)
        #expect(scenario.apps.opened == [.shorts])
        #expect(scenario.toast.message == "Ready to post on Shorts")
    }

    @Test func burnInCaptionsWritesThemFromTheScript() async {
        let scenario = makeScenario(tier: .subscriber)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.burnsInCaptions = true
        await scenario.viewModel.share(to: .tiktok)
        let options = scenario.exporter.exports.first
        #expect(options?.burnsInCaptions == true)
        #expect(options?.edit?.showsCaptions == true)
        #expect(options?.edit?.captions == scenario.editor.captions)
        #expect(scenario.editor.captionScript == "Okay, real talk.")
        // The captions are for this export only; the take isn't edited.
        #expect(scenario.viewModel.take?.edit == nil)
    }

    @Test func burnInCaptionsKeepsTheEditsCaptions() async {
        var take = TestData.take(scriptID: nil)
        var edit = TakeEdit(sourceDuration: take.duration, aspect: .portrait)
        edit.captions = [CaptionCue(text: "Mine.", start: 0, end: 1)]
        take.edit = edit
        let scenario = makeScenario(tier: .subscriber, take: take)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.burnsInCaptions = true
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.first?.edit?.captions.map(\.text) == ["Mine."])
        #expect(scenario.editor.captionScript == nil)
    }

    @Test func fourKIsPro() {
        let free = makeScenario()
        defer { free.defaults.tearDown() }
        free.viewModel.setQuality(.uhd4K)
        #expect(free.viewModel.quality == .hd1080)
        #expect(free.viewModel.paywall == .fourK)

        let pro = makeScenario(tier: .subscriber)
        defer { pro.defaults.tearDown() }
        pro.viewModel.setQuality(.uhd4K)
        #expect(pro.viewModel.quality == .uhd4K)
        #expect(pro.viewModel.paywall == nil)
    }

    @Test func qualityOnlyScalesDown() async {
        var take = TestData.take(scriptID: nil)
        take.resolution = .uhd4K
        let scenario = makeScenario(tier: .subscriber, take: take)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.shareMeta == "0:30 · 9:16 · 1080p")
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.last?.shortSide == 1080)

        scenario.viewModel.setQuality(.uhd4K)
        #expect(scenario.viewModel.shareMeta == "0:30 · 9:16 · 4K")
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.last?.shortSide == nil)
    }

    @Test func fourKOfA1080pTakeStays1080p() {
        let scenario = makeScenario(tier: .subscriber)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setQuality(.uhd4K)
        #expect(scenario.viewModel.shareMeta == "0:30 · 9:16 · 1080p")
    }

    @Test func markingTheBestTake() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.toggleBest()
        #expect(scenario.viewModel.take?.isBest == true)
        #expect(scenario.toast.message == "Take 1 marked as best")
    }

    @Test func savingMarksTheTakeShared() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.take?.isExported == false)
        await scenario.viewModel.save()
        #expect(scenario.viewModel.take?.isExported == true)
    }

    // MARK: - Best take

    /// Three takes of a script that reads in about 30 s: one stopped early, one on time, one long.
    private func makeBestTakeScenario(tier: MembershipTier) -> (viewModel: TakeReviewViewModel, takes: [Take], toast: ToastService, defaults: TestDefaults) {
        let defaults = TestDefaults()
        let script = TestData.script(text: Array(repeating: "word", count: 75).joined(separator: " "))
        let durations: [TimeInterval] = [12, 31, 45]
        let all = durations.enumerated().map { index, duration in
            var take = TestData.take(scriptID: script.id, number: index + 1, recordedAt: TestData.now.addingTimeInterval(Double(index) * 60))
            take.duration = duration
            return take
        }
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: all))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let toast = ToastService()
        let viewModel = TakeReviewViewModel(
            takeID: all[0].id, takes: takes, quota: UsageQuotaService(defaults: defaults.defaults), tier: { tier },
            exporter: FakeVideoExporter(), photos: FakePhotoSaver(), apps: FakeAppOpener(), editing: FakeTakeEditor(),
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: PreferencesService(defaults: defaults.defaults), toast: toast
        )
        return (viewModel, all, toast, defaults)
    }

    @Test func suggestsTheCompleteTakeClosestToTheScript() {
        let scenario = makeBestTakeScenario(tier: .subscriber)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.offersBestSuggestion)
        #expect(!scenario.viewModel.locksBestSuggestion)
        #expect(scenario.viewModel.suggestBest()?.id == scenario.takes[1].id)
        #expect(scenario.toast.message == "Take 2 looks best — tap ☆ to keep it")
        // A suggestion, not a pick: the creator keeps it with the star.
        #expect(scenario.viewModel.siblings.allSatisfy { !$0.isBest })
    }

    @Test func bestTakeSuggestionIsPro() {
        let scenario = makeBestTakeScenario(tier: .free)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.locksBestSuggestion)
        #expect(scenario.viewModel.suggestBest() == nil)
        #expect(scenario.viewModel.paywall == .bestTake)
    }

    @Test func aSingleTakeHasNothingToCompare() {
        let scenario = makeScenario(tier: .subscriber)
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.viewModel.offersBestSuggestion)
    }

    @Test func deletingShowsTheNewestSiblingNext() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let script = UUID()
        let first = TestData.take(scriptID: script, number: 1)
        let second = TestData.take(scriptID: script, number: 2)
        let third = TestData.take(scriptID: script, number: 3)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [first, second, third]))
        takes.load()
        let viewModel = TakeReviewViewModel(
            takeID: second.id, takes: takes, quota: UsageQuotaService(defaults: defaults.defaults), tier: { .free },
            exporter: FakeVideoExporter(), photos: FakePhotoSaver(), apps: FakeAppOpener(), editing: FakeTakeEditor(),
            library: ScriptLibraryService(repository: FakeScriptRepository()), rules: TestData.rulesService(),
            profile: CreatorProfileService(defaults: defaults.defaults), preferences: PreferencesService(defaults: defaults.defaults),
            toast: ToastService()
        )
        #expect(viewModel.siblings.map(\.number) == [1, 2, 3])
        #expect(viewModel.delete()?.id == third.id)
        #expect(takes.takes.count == 2)
    }

    @Test func deletingTheLastTakeLeavesTheReview() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.delete() == nil)
        #expect(scenario.takes.takes.isEmpty)
        #expect(scenario.toast.message == "Take 1 deleted")
    }

    @Test func metaLineShowsWhenPlatformFrameAndQuality() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.metaLine.hasSuffix("· TikTok · 9:16 · 1080p"))
    }
}
