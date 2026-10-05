//
//  ExportAccountingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// When a free export is deducted: when the video provably leaves Cue (saved to Photos, accepted by a share-sheet activity,
/// received by TikTok), once per exported file, and never for preparing, opening an app, cancelling or failing.
@MainActor
@Suite("Export accounting")
struct ExportAccountingTests {
    @MainActor
    private struct Scenario {
        let viewModel: TakeReviewViewModel
        let exporter: FakeVideoExporter
        let photos: FakePhotoSaver
        let sharing: FakeVideoSharing
        let quota: UsageQuotaService
        let ledger: ExportLedgerService
        let store: FakeExportLedgerStore
        let counter: FakeExportCountStore
        let takes: TakeLibraryService
        let toast: ToastService
        let defaults: TestDefaults
        let take: Take
        let tier: Plan

        var used: Int { quota.exportsUsed }
    }

    private final class Plan {
        var tier: MembershipTier
        init(_ tier: MembershipTier) { self.tier = tier }
    }

    /// `restarting` builds the app again on the same disk: the export count, the ledger and the take library.
    private func makeScenario(
        tier: MembershipTier = .free, used: Int = 0, restarting previous: Scenario? = nil, type: ScriptType? = nil
    ) -> Scenario {
        let defaults = previous?.defaults ?? TestDefaults()
        let script = TestData.script(text: "Okay, real talk.", type: type)
        let take = previous?.take ?? TestData.take(scriptID: script.id)
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let takes = previous?.takes ?? {
            let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
            takes.load()
            return takes
        }()
        let counter = previous?.counter ?? FakeExportCountStore(count: used)
        let store = previous?.store ?? FakeExportLedgerStore()
        let quota = UsageQuotaService(counter: counter, defaults: defaults.defaults)
        let ledger = ExportLedgerService(store: store, quota: quota)
        let exporter = FakeVideoExporter()
        let photos = FakePhotoSaver()
        let sharing = FakeVideoSharing()
        let toast = ToastService()
        let plan = previous?.tier ?? Plan(tier)
        let viewModel = TakeReviewViewModel(
            takeID: take.id, takes: takes, quota: quota, tier: { plan.tier },
            exporter: exporter, photos: photos, sharing: sharing, ledger: ledger, editing: FakeTakeEditor(), library: library,
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            preferences: PreferencesService(defaults: defaults.defaults), drafts: FakeDraftStore(), toast: toast
        )
        return Scenario(
            viewModel: viewModel, exporter: exporter, photos: photos, sharing: sharing, quota: quota, ledger: ledger, store: store,
            counter: counter, takes: takes, toast: toast, defaults: defaults, take: take, tier: plan
        )
    }

    private let airDrop = "com.apple.UIKit.activity.AirDrop"

    // MARK: - Saving to Photos

    @Test func aSuccessfulSaveDeductsOneExport() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.used == 1)
        #expect(scenario.ledger.operations.count == 1)
        #expect(scenario.ledger.operations.first?.isCounted == true)
        #expect(scenario.ledger.operations.first?.photosAssetID == "asset-1")
        #expect(scenario.viewModel.phase == .delivered(.photoLibrary(assetID: "asset-1")))
    }

    @Test func aDeniedSaveDeductsNothing() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.error = PhotoLibraryError.notAuthorized
        await scenario.viewModel.save()
        #expect(scenario.used == 0)
        #expect(scenario.viewModel.photosDenied)
        #expect(scenario.viewModel.phase == .failed)
        #expect(scenario.ledger.operations.allSatisfy { !$0.isCounted })
        #expect(scenario.viewModel.take?.isExported == false)
    }

    @Test func aFailedSaveDeductsNothing() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.error = CocoaError(.fileWriteUnknown)
        await scenario.viewModel.save()
        #expect(scenario.used == 0)
        #expect(scenario.toast.message == "Couldn't export · Try again")
        #expect(scenario.viewModel.phase == .failed)
    }

    @Test func aFailedRenderDeductsNothing() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.exporter.error = VideoExportError.exportUnavailable
        await scenario.viewModel.save()
        #expect(scenario.used == 0)
        #expect(scenario.ledger.operations.isEmpty)
    }

    @Test func aSubscriberSaveIsNotDeductedButIsRecorded() async {
        let scenario = makeScenario(tier: .subscriber, used: 3)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.used == 3)
        #expect(scenario.ledger.operations.first?.isCounted == true)
    }

    // MARK: - The share sheet

    @Test func preparingTheFileForMoreDeductsNothing() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        #expect(scenario.viewModel.activity != nil)
        #expect(scenario.used == 0)
        #expect(scenario.viewModel.phase == .delivering(nil))
        #expect(scenario.photos.savedURLs.isEmpty)
    }

    @Test func aSheetClosedBeforeDeliveryDeductsNothing() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.cancelled, for: share)
        #expect(scenario.used == 0)
        #expect(scenario.viewModel.phase == .cancelled)
        #expect(scenario.viewModel.activity == nil)
        #expect(scenario.viewModel.take?.isExported == false)
    }

    @Test func aSheetThatFailedDeductsNothing() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.failed, for: share)
        #expect(scenario.used == 0)
        #expect(scenario.viewModel.phase == .failed)
        #expect(scenario.toast.message == "Couldn’t share · Try again")
    }

    @Test func aCompletedActivityDeductsOneExport() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.completed(activityType: airDrop), for: share)
        #expect(scenario.used == 1)
        #expect(scenario.viewModel.phase == .delivered(.activity(type: airDrop)))
        #expect(scenario.viewModel.take?.isExported == true)
        #expect(scenario.toast.message == "Shared · 4 of 5 free exports left")
        // Another app than the tile's: no send-off.
        #expect(scenario.viewModel.celebration == nil)
    }

    @Test func aDestinationSheetFinishedInThatAppIsASendOff() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.youtube] = .activitySheet
        await scenario.viewModel.share(to: .youtube)
        let share = try #require(scenario.viewModel.activity)
        #expect(share.destination == .youtube)
        scenario.viewModel.activityFinished(.completed(activityType: "com.google.ios.youtube.ShareExtension"), for: share)
        #expect(scenario.used == 1)
        guard case .sentOff(_, .youtube)? = scenario.viewModel.celebration else {
            Issue.record("Expected the send-off, got \(String(describing: scenario.viewModel.celebration))")
            return
        }
        #expect(scenario.toast.message == "Shared with YouTube · 4 of 5 free exports left")
    }

    @Test func theShareSheetDoesNotNeedPhotos() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.error = PhotoLibraryError.notAuthorized
        await scenario.viewModel.share(to: nil)
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.completed(activityType: airDrop), for: share)
        #expect(scenario.used == 1)
        #expect(!scenario.viewModel.photosDenied)
    }

    // MARK: - Opening an app

    @Test func instagramOpenedWithTheVideoOnThePasteboardDeductsOnce() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.reels] = .instagramHandoff(.reels)
        scenario.sharing.outcome = .opened
        await scenario.viewModel.share(to: .reels)
        #expect(scenario.sharing.sent.first?.route == .instagramHandoff(.reels))
        // The video left Cue (pasteboard, composer open): counted. No Photos copy was needed.
        #expect(scenario.photos.savedURLs.isEmpty)
        #expect(scenario.used == 1)
        #expect(scenario.ledger.operations.first?.deliveries == [.pasteboardHandoff])
        #expect(scenario.viewModel.take?.isExported == true)
        // Instagram says nothing: no send-off, and the message says only that it opened.
        #expect(scenario.viewModel.celebration == nil)
        #expect(scenario.toast.message == "Opened Reels with your video · Cue can’t see if you post it · 4 of 5 free exports left")
        // Doing it again with the same file is not a second export.
        await scenario.viewModel.share(to: .reels)
        #expect(scenario.used == 1)
        #expect(scenario.exporter.exports.count == 1)
    }

    @Test func instagramThatNeverOpenedDeductsNothing() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.stories] = .instagramHandoff(.stories)
        scenario.sharing.outcome = .unavailable(.appNotInstalled)
        await scenario.viewModel.share(to: .stories)
        #expect(scenario.used == 0)
        #expect(scenario.viewModel.activity?.destination == .stories)
        #expect(scenario.viewModel.take?.isExported == false)
    }

    @Test func linkedInSavesToPhotosAndRecommendsPostingFromTheApp() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.linkedin] = .saveOnly
        await scenario.viewModel.share(to: .linkedin)
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.sharing.sent.isEmpty)
        #expect(scenario.used == 1)
        #expect(scenario.toast.message == "Saved to Photos · Open LinkedIn to post it · 4 of 5 free exports left")
        guard case .readyToTravel? = scenario.viewModel.celebration else {
            Issue.record("Expected Ready to travel, got \(String(describing: scenario.viewModel.celebration))")
            return
        }
    }

    @Test func linkedInWithoutPhotosAccessUsesTheShareSheetAndCountsNothingUntilItCompletes() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.error = PhotoLibraryError.notAuthorized
        scenario.sharing.routes[.linkedin] = .saveOnly
        await scenario.viewModel.share(to: .linkedin)
        #expect(scenario.viewModel.activity?.destination == .linkedin)
        #expect(scenario.used == 0)
    }

    @Test func aHandOffThatFailsDeductsNothing() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.stories] = .instagramHandoff(.stories)
        scenario.sharing.outcome = .failed(.rejected)
        await scenario.viewModel.share(to: .stories)
        #expect(scenario.used == 0)
        #expect(scenario.viewModel.phase == .failed)
        #expect(scenario.toast.message == "Stories didn’t take the video")
    }

    @Test func anAppThatWontOpenFallsBackToTheShareSheetWithNothingDeducted() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.reels] = .instagramHandoff(.reels)
        scenario.sharing.outcome = .unavailable(.couldNotOpen)
        await scenario.viewModel.share(to: .reels)
        #expect(scenario.used == 0)
        #expect(scenario.viewModel.activity?.destination == .reels)
        #expect(scenario.toast.message == "Reels isn’t on this iPhone · Pick another app")
    }

    @Test func saveAndOpenWithoutTheAppKeepsTheSaveAndOffersTheShareSheet() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.linkedin] = .saveAndOpen
        scenario.sharing.outcome = .unavailable(.appNotInstalled)
        await scenario.viewModel.share(to: .linkedin)
        // The video was saved (that counts); the app isn't there, so the sheet takes it from here.
        #expect(scenario.used == 1)
        #expect(scenario.viewModel.activity?.destination == .linkedin)
        #expect(scenario.toast.message == "LinkedIn isn’t on this iPhone · Pick another app")
        #expect(scenario.viewModel.celebration == nil)
    }

    @Test func saveAndOpenCountsBecauseOfThePhotosCopyNotBecauseOfTheOpening() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.linkedin] = .saveAndOpen
        await scenario.viewModel.share(to: .linkedin)
        #expect(scenario.photos.savedURLs.count == 1)
        #expect(scenario.used == 1)
        #expect(scenario.ledger.operations.first?.deliveries == [.photoLibrary(assetID: "asset-1")])
    }

    @Test func withoutPhotosAccessADestinationUsesTheShareSheet() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.error = PhotoLibraryError.notAuthorized
        scenario.sharing.routes[.linkedin] = .saveAndOpen
        await scenario.viewModel.share(to: .linkedin)
        #expect(scenario.viewModel.activity?.destination == .linkedin)
        #expect(!scenario.viewModel.photosDenied)
        #expect(scenario.used == 0)
        #expect(scenario.sharing.sent.isEmpty)
    }

    // MARK: - TikTok Share Kit

    @Test func shareKitSendsTheSavedAssetAndCountsOnTheSave() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.tiktok] = .shareKit
        scenario.sharing.outcome = .pending
        await scenario.viewModel.share(to: .tiktok)
        #expect(scenario.sharing.sent.first?.video.photosAssetID == "asset-1")
        #expect(scenario.sharing.sent.first?.route == .shareKit)
        // Counted for the Photos copy; TikTok hasn't answered.
        #expect(scenario.used == 1)
        #expect(scenario.viewModel.celebration == nil)
        #expect(scenario.viewModel.phase == .delivering(.tiktok))
    }

    @Test func shareKitSuccessIsASendOffAndNeverCountsAgain() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.tiktok] = .shareKit
        scenario.sharing.outcome = .pending
        await scenario.viewModel.share(to: .tiktok)
        scenario.sharing.finish?(.delivered(.tikTokShareKit))
        scenario.sharing.finish?(.delivered(.tikTokShareKit))
        #expect(scenario.used == 1)
        guard case .sentOff(_, .tiktok)? = scenario.viewModel.celebration else {
            Issue.record("Expected the send-off, got \(String(describing: scenario.viewModel.celebration))")
            return
        }
        #expect(scenario.ledger.operations.first?.deliveries.contains(.tikTokShareKit) == true)
    }

    @Test func shareKitCancelledKeepsTheSaveCountedAndSaysSo() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.tiktok] = .shareKit
        scenario.sharing.outcome = .pending
        await scenario.viewModel.share(to: .tiktok)
        scenario.sharing.finish?(.cancelled)
        #expect(scenario.used == 1)
        #expect(scenario.viewModel.phase == .cancelled)
        #expect(scenario.viewModel.celebration == nil)
        #expect(scenario.toast.message == "Sharing cancelled")
    }

    @Test func shareKitWithoutAnAssetIdentifierFallsBackToSaveAndOpen() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.givesIdentifiers = false
        scenario.sharing.routes[.tiktok] = .shareKit
        await scenario.viewModel.share(to: .tiktok)
        #expect(scenario.sharing.sent.first?.route == .saveAndOpen)
        #expect(scenario.used == 1)
    }

    // MARK: - Once per operation

    @Test func savingThenSharingTheSameFileDeductsOnce() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        guard case .readyToTravel(let video)? = scenario.viewModel.celebration else {
            Issue.record("Expected Ready to travel")
            return
        }
        scenario.viewModel.celebration = nil
        scenario.viewModel.share(video)
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.completed(activityType: airDrop), for: share)
        #expect(scenario.used == 1)
        #expect(scenario.exporter.exports.count == 1)
        #expect(scenario.ledger.operations.count == 1)
        #expect(scenario.ledger.operations.first?.deliveries.count == 2)
    }

    @Test func sharingToAPlatformAfterSavingDeductsOnce() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.sharing.routes[.tiktok] = .shareKit
        scenario.sharing.outcome = .pending
        await scenario.viewModel.save()
        guard case .readyToTravel(let video)? = scenario.viewModel.celebration else {
            Issue.record("Expected Ready to travel")
            return
        }
        await scenario.viewModel.send(video, to: .tiktok)
        scenario.sharing.finish?(.delivered(.tikTokShareKit))
        #expect(scenario.used == 1)
        #expect(scenario.exporter.exports.count == 1)
    }

    @Test func aDuplicateActivityCallbackDeductsOnceAndTellsOnce() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.completed(activityType: airDrop), for: share)
        scenario.toast.dismiss()
        scenario.viewModel.activityFinished(.completed(activityType: airDrop), for: share)
        #expect(scenario.used == 1)
        #expect(scenario.toast.message == nil)
    }

    @Test func aRepeatedSaveReusesTheFileAndDeductsOnce() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 1)
        #expect(scenario.used == 1)
    }

    @Test func aRetryAfterAFailedSaveReusesTheRenderedFile() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.photos.error = CocoaError(.fileWriteUnknown)
        await scenario.viewModel.save()
        scenario.photos.error = nil
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 1)
        #expect(scenario.used == 1)
    }

    @Test func aSheetClosedThenReopenedReusesTheFileAndDeductsOnceWhenItCompletes() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        scenario.viewModel.activityFinished(.cancelled, for: try #require(scenario.viewModel.activity))
        await scenario.viewModel.share(to: nil)
        let second = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.completed(activityType: airDrop), for: second)
        #expect(scenario.exporter.exports.count == 1)
        #expect(scenario.used == 1)
    }

    @Test func aRestoredAppDoesNotCountTheSameExportAgain() async throws {
        let first = makeScenario()
        defer { first.defaults.tearDown() }
        await first.viewModel.save()
        #expect(first.used == 1)

        let restored = makeScenario(restarting: first)
        #expect(restored.used == 1)
        await restored.viewModel.share(to: nil)
        let share = try #require(restored.viewModel.activity)
        restored.viewModel.activityFinished(.completed(activityType: airDrop), for: share)
        // The file made before the restart served the share, and nothing was deducted again.
        #expect(restored.exporter.exports.isEmpty)
        #expect(restored.used == 1)
        #expect(restored.counter.count == 1)
    }

    @Test func aCallbackAfterARestartDoesNotCountAgain() async {
        let first = makeScenario()
        defer { first.defaults.tearDown() }
        first.sharing.routes[.tiktok] = .shareKit
        first.sharing.outcome = .pending
        await first.viewModel.share(to: .tiktok)
        let operationID = first.ledger.operations.first?.id
        #expect(first.used == 1)

        let restored = makeScenario(restarting: first)
        let counted = restored.ledger.recordDelivery(.tikTokShareKit, for: operationID ?? UUID(), tier: .free)
        #expect(!counted)
        #expect(restored.used == 1)
    }

    // MARK: - A separate export, and the quota

    @Test func aNewEditIsANewExportThatFollowsTheQuota() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        scenario.viewModel.burnsInCaptions = true
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 2)
        #expect(scenario.ledger.operations.count == 2)
        #expect(scenario.used == 2)
    }

    @Test func changedSettingsNeverReuseStaleOutput() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        scenario.viewModel.burnsInCaptions = true
        await scenario.viewModel.share(to: nil)
        #expect(scenario.exporter.exports.count == 2)
        #expect(scenario.ledger.operations.count == 2)
        #expect(scenario.ledger.operations[0].fileName != scenario.ledger.operations[1].fileName)
    }

    @Test func anExhaustedQuotaAsksForProBeforeANewExport() async {
        let scenario = makeScenario(used: UsagePolicy.freeExports)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.viewModel.paywall == .export)
        #expect(scenario.exporter.exports.isEmpty)
        #expect(scenario.used == UsagePolicy.freeExports)
    }

    @Test func theLastFreeExportCanStillBeSharedAfterBeingSaved() async throws {
        let scenario = makeScenario(used: UsagePolicy.freeExports - 1)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        #expect(scenario.used == UsagePolicy.freeExports)
        // Used up, but this video is already out: sharing it again is not a new export.
        await scenario.viewModel.share(to: nil)
        #expect(scenario.viewModel.paywall == nil)
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.completed(activityType: airDrop), for: share)
        #expect(scenario.used == UsagePolicy.freeExports)
        // A different edit is a new export and the quota says no.
        scenario.viewModel.burnsInCaptions = true
        await scenario.viewModel.save()
        #expect(scenario.viewModel.paywall == .export)
        #expect(scenario.used == UsagePolicy.freeExports)
    }

    @Test func existingUsageIsKeptAcrossTheNewAccounting() async {
        let scenario = makeScenario(used: 3)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.quota.exportsLeft(for: .free) == 2)
        await scenario.viewModel.save()
        #expect(scenario.used == 4)
    }

    // MARK: - Files

    @Test func leavingTheReviewRemovesTheFileButKeepsTheRecord() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        scenario.viewModel.celebration = nil
        let operation = try #require(scenario.ledger.operations.first)
        #expect(scenario.ledger.fileExists(for: operation))
        scenario.viewModel.leave()
        #expect(!scenario.ledger.fileExists(for: operation))
        #expect(scenario.ledger.operation(id: operation.id)?.isCounted == true)
        // A new save of the same edit is a new file, hence a new export.
        await scenario.viewModel.save()
        #expect(scenario.exporter.exports.count == 2)
    }

    @Test func theFileStaysWhileTheShareSheetIsOpen() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.share(to: nil)
        let operation = try #require(scenario.ledger.operations.first)
        scenario.viewModel.leave()
        #expect(scenario.ledger.fileExists(for: operation))
    }

    @Test func aFileTheSystemClearedIsMadeAgainForTheSameExport() async throws {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.save()
        guard case .readyToTravel(let video)? = scenario.viewModel.celebration else {
            Issue.record("Expected Ready to travel")
            return
        }
        scenario.viewModel.celebration = nil
        let operation = try #require(scenario.ledger.operations.first)
        try FileManager.default.removeItem(at: scenario.ledger.fileURL(of: operation))
        scenario.viewModel.share(video)
        // Let the re-export task finish.
        for _ in 0..<50 where scenario.viewModel.activity == nil { try await Task.sleep(for: .milliseconds(20)) }
        let share = try #require(scenario.viewModel.activity)
        scenario.viewModel.activityFinished(.completed(activityType: airDrop), for: share)
        #expect(scenario.exporter.exports.count == 2)
        #expect(scenario.ledger.operations.count == 1)
        #expect(scenario.used == 1)
    }
}
