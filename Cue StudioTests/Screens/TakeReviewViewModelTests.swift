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

    private func makeScenario(tier: MembershipTier = .free, usedExports: Int = 0, take: Take? = nil, type: ScriptType? = nil) -> Scenario {
        makeScenario(plan: Plan(tier), usedExports: usedExports, take: take, type: type)
    }

    private func makeScenario(plan: Plan, usedExports: Int = 0, take: Take? = nil, type: ScriptType? = nil) -> Scenario {
        let defaults = TestDefaults()
        let script = TestData.script(text: "Okay, real talk.", type: type)
        let take = take ?? TestData.take(scriptID: script.id)
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: usedExports), defaults: defaults.defaults)
        let exporter = FakeVideoExporter()
        let photos = FakePhotoSaver()
        let apps = FakeAppOpener()
        let editor = FakeTakeEditor()
        let toast = ToastService()
        let viewModel = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { plan.tier },
            exporter: exporter, photos: photos, apps: apps, editing: editor, library: library,
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: PreferencesService(defaults: defaults.defaults), drafts: FakeDraftStore(), toast: toast
        )
        return Scenario(
            viewModel: viewModel, exporter: exporter, photos: photos, apps: apps, editor: editor,
            quota: quota, takes: takes, toast: toast, defaults: defaults
        )
    }

    @Test func freeSaveIsCounted() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports == [ExportOptions(aspect: .portrait)])
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.quota.exportsLeft(for: .free) == 4)
        #expect(scenario.toast.message == "Saved to Photos · 4 of 5 free exports left")
        #expect(scenario.viewModel.exportNotice == "4 of 5 free exports")
    }

    @Test func pastTheFreeExportsThePaywallOpensAndNothingExports() async {
        let scenario = makeScenario(usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.viewModel.paywall == .export)
        #expect(scenario.exporter.exports.isEmpty)
        #expect(scenario.photos.savedURLs.isEmpty)
        #expect(scenario.viewModel.exportNotice == "Free exports used — 7 days free to keep exporting")
    }

    @Test func subscriberExportsAreUncounted() async {
        let scenario = makeScenario(tier: .subscriber, usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 1)
        #expect(scenario.toast.message == "Saved to Photos")
        #expect(scenario.viewModel.exportNotice == nil)
        #expect(scenario.quota.exportsUsed == 5)
    }

    @Test func startingTheTrialFinishesTheExport() async {
        let plan = Plan(.free)
        let scenario = makeScenario(plan: plan, usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.viewModel.paywall == .export)
        plan.tier = .subscriber
        await scenario.viewModel.continueAfterPurchase()
        #expect(scenario.exporter.exports == [ExportOptions(aspect: .portrait)])
        #expect(scenario.photos.savedURLs.count == 1)
    }

    @Test func closingThePaywallExportsNothing() async {
        let scenario = makeScenario(usedExports: 5)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        scenario.viewModel.paywall = nil
        await scenario.viewModel.continueAfterPurchase()
        #expect(scenario.exporter.exports.isEmpty)
        #expect(scenario.viewModel.paywall == .export)
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
        #expect(scenario.toast.message == "Ready to post on Reels · 4 of 5 free exports left")
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
        #expect(scenario.exporter.exports.isEmpty)
    }

    @Test func burnInCaptionsUsesTheVoiceAndCachesItWithoutMarkingAnEdit() async {
        let scenario = makeScenario(tier: .subscriber)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.burnsInCaptions = true
        await scenario.viewModel.share(to: .tiktok)
        let options = scenario.exporter.exports.first
        #expect(options?.burnsInCaptions == true)
        #expect(options?.edit?.showsCaptions == true)
        #expect(options?.edit?.voiceProcessing.isNeeded == false)
        #expect(options?.edit?.captions == scenario.editor.captions)
        #expect(scenario.editor.captionScript == "Okay, real talk.")
        #expect(scenario.viewModel.take?.edit?.captions == scenario.editor.captions)
        #expect(scenario.viewModel.take?.edit?.captionTranscript != nil)
        #expect(scenario.viewModel.take?.isEdited == false)
        await scenario.viewModel.share(to: .tiktok)
        #expect(scenario.editor.captionRequests == 1)
    }

    @Test func exportDefaultsFollowSavedCaptionVisibility() {
        var take = TestData.take(scriptID: nil)
        var edit = TakeEdit(sourceDuration: take.duration, aspect: .portrait)
        edit.showsCaptions = true
        take.edit = edit
        let shown = makeScenario(tier: .subscriber, take: take)
        defer { shown.defaults.tearDown() }
        #expect(shown.viewModel.burnsInCaptions)
        edit.showsCaptions = false
        take.edit = edit
        let hidden = makeScenario(tier: .subscriber, take: take)
        defer { hidden.defaults.tearDown() }
        #expect(!hidden.viewModel.burnsInCaptions)
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

    @Test func fourKIsFreeToo() {
        let free = makeScenario()
        defer { free.defaults.tearDown() }
        free.viewModel.setQuality(.uhd4K)
        #expect(free.viewModel.quality == .uhd4K)
        #expect(free.viewModel.paywall == nil)
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
            takeID: all[0].id, takes: takes, quota: UsageQuotaService(counter: FakeExportCountStore(), defaults: defaults.defaults), tier: { tier },
            exporter: FakeVideoExporter(), photos: FakePhotoSaver(), apps: FakeAppOpener(), editing: FakeTakeEditor(),
            library: library, rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: PreferencesService(defaults: defaults.defaults), drafts: FakeDraftStore(), toast: toast
        )
        return (viewModel, all, toast, defaults)
    }

    @Test func suggestsTheCompleteTakeClosestToTheScript() {
        let scenario = makeBestTakeScenario(tier: .free)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.offersBestSuggestion)
        let proposal = scenario.viewModel.bestProposal()
        #expect(proposal?.best.id == scenario.takes[1].id)
        #expect(proposal?.takes.count == scenario.takes.count)
        // A suggestion, not a pick: the creator decides with "Use take 2".
        #expect(scenario.viewModel.siblings.allSatisfy { !$0.isBest })
        scenario.viewModel.markBest(scenario.takes[1])
        #expect(scenario.viewModel.siblings.filter(\.isBest).map(\.id) == [scenario.takes[1].id])
        #expect(scenario.toast.message == "Take 2 marked as best")
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
            takeID: second.id, takes: takes, quota: UsageQuotaService(counter: FakeExportCountStore(), defaults: defaults.defaults), tier: { .free },
            exporter: FakeVideoExporter(), photos: FakePhotoSaver(), apps: FakeAppOpener(), editing: FakeTakeEditor(),
            library: ScriptLibraryService(repository: FakeScriptRepository()), rules: TestData.rulesService(),
            profile: CreatorProfileService(defaults: defaults.defaults), preferences: PreferencesService(defaults: defaults.defaults), drafts: FakeDraftStore(),
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

    @Test func deleteIsUndoneWithinTheToastAndTheVideoGoesAfterwards() throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        _ = scenario.viewModel.delete()
        #expect(scenario.takes.takes.isEmpty)
        let action = try #require(scenario.toast.action)
        action.perform()
        #expect(scenario.takes.takes.count == 1)
    }

    @Test func aRefusedPhotosPermissionShowsTheCardAndNoToast() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.error = PhotoLibraryError.notAuthorized
        await scenario.viewModel.save()
        #expect(scenario.viewModel.photosDenied)
        #expect(scenario.toast.message == nil)
    }

    @Test func aFailedExportDoesNotCountAndSaysSo() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.exporter.error = URLError(.unknown)
        await scenario.viewModel.save()
        #expect(scenario.toast.message == "Couldn't export · Try again")
        #expect(scenario.quota.exportsLeft(for: .free) == 5)
        #expect(!scenario.viewModel.photosDenied)
    }

    @Test func aRefusedPhotosSaveDoesNotCountTheExportEither() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.error = PhotoLibraryError.notAuthorized
        await scenario.viewModel.save()
        #expect(scenario.quota.exportsLeft(for: .free) == 5)
    }

    @Test func aSponsoredVideoCarriesHashtagAdAndOthersDoNot() async {
        let ad = makeScenario(type: .ad)
        defer { ad.defaults.tearDown() }
        var copied: [String] = []
        ad.viewModel.copiesCaption = { copied.append($0) }
        #expect(ad.viewModel.isSponsored)
        await ad.viewModel.save()
        #expect(copied == ["#ad"])
        let plain = makeScenario()
        defer { plain.defaults.tearDown() }
        plain.viewModel.copiesCaption = { copied.append($0) }
        #expect(!plain.viewModel.isSponsored)
        await plain.viewModel.save()
        #expect(copied == ["#ad"])
    }

    @Test func metaLineShowsWhenPlatformFrameAndQuality() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.metaLine.hasSuffix("· TikTok · 9:16 · 1080p"))
    }

    // MARK: - The v26 review: stage, compare, length

    private func makeVideoScenario(
        numbers: [Int] = [1, 2, 3], current: Int = 2, best: Int? = nil, drafts: FakeDraftStore = FakeDraftStore()
    ) -> (viewModel: TakeReviewViewModel, takes: [Take], defaults: TestDefaults, drafts: FakeDraftStore) {
        let defaults = TestDefaults()
        let script = UUID()
        let all = numbers.map { TestData.take(scriptID: script, number: $0, isBest: $0 == best) }
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: all))
        takes.load()
        let id = all.first { $0.number == current }!.id
        let viewModel = TakeReviewViewModel(
            takeID: id, takes: takes, quota: UsageQuotaService(counter: FakeExportCountStore(), defaults: defaults.defaults), tier: { .free },
            exporter: FakeVideoExporter(), photos: FakePhotoSaver(), apps: FakeAppOpener(), editing: FakeTakeEditor(),
            library: ScriptLibraryService(repository: FakeScriptRepository()), rules: TestData.rulesService(),
            profile: CreatorProfileService(defaults: defaults.defaults), preferences: PreferencesService(defaults: defaults.defaults),
            drafts: drafts, toast: ToastService()
        )
        return (viewModel, all, defaults, drafts)
    }

    @Test func theChipSaysWhereTheTakeIsAndTheNeighborsAreTheOthersByNumber() {
        let scenario = makeVideoScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.placeLabel == "2 / 3")
        #expect(scenario.viewModel.neighbor(-1)?.number == 1)
        #expect(scenario.viewModel.neighbor(1)?.number == 3)
    }

    @Test func thereIsNoNeighborPastTheEnds() {
        let first = makeVideoScenario(current: 1)
        defer { first.defaults.tearDown() }
        #expect(first.viewModel.neighbor(-1) == nil)
        let last = makeVideoScenario(current: 3)
        defer { last.defaults.tearDown() }
        #expect(last.viewModel.neighbor(1) == nil)
    }

    @Test func aSingleTakeHasNoChip() {
        let scenario = makeVideoScenario(numbers: [1], current: 1)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.placeLabel == nil)
        #expect(scenario.viewModel.neighbor(1) == nil)
    }

    @Test func theStageFollowsTheVideoNotJustTheTake() {
        let scenario = makeVideoScenario()
        defer { scenario.defaults.tearDown() }
        // Three takes and none starred: pick the best.
        #expect(scenario.viewModel.stage == .pick)
        scenario.viewModel.toggleBest()
        #expect(scenario.viewModel.stage == .ready)
        // An edit left open on any take of the video puts it in edit and the main action reads "Continue".
        #expect(!scenario.viewModel.hasOpenEdit)
        let other = scenario.takes.first { $0.number == 3 }!
        scenario.drafts.drafts[other.id] = QuickEditDraft(
            takeID: other.id, edit: TakeEdit(sourceDuration: 30, aspect: .portrait), playhead: 0,
            history: EditHistory<EditSnapshot>(), savedAt: TestData.now
        )
        #expect(scenario.viewModel.stage == .edit)
        #expect(scenario.viewModel.hasOpenEdit)
    }

    @Test func theLengthIsMeasuredAgainstThePlatformsIdealRange() {
        let scenario = makeVideoScenario(numbers: [1], current: 1)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.scriptVersionLabel == "v1")
        let fit = scenario.viewModel.lengthFit
        #expect(fit?.seconds == 30)
        let preset = TestData.rulesService().preset(for: .tiktok, monetizationGoals: CreatorProfile().monetizationGoals)
        #expect(fit?.ideal == preset.idealRange)
    }
}
