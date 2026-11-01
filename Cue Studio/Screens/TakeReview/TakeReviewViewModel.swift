//
//  TakeReviewViewModel.swift
//  Cue Studio
//

import Foundation
import UIKit

/// Save a take, or share it to a platform ("Share to"). Every feature is free; the free plan
/// includes `UsagePolicy.freeExports` exports, then exporting asks for Cue Pro. Takes are never locked.
///
/// An export counts when the video provably leaves Cue (`DeliveryEvidence`), once per operation (`ExportLedgerService`):
/// saved to Photos, accepted by a share-sheet activity, received by TikTok. Preparing the file, opening an app,
/// cancelling and failing never count. No platform tells Cue that a video was published, so nothing here says so.
@MainActor
@Observable
final class TakeReviewViewModel {
    enum ExportAction: Equatable {
        case save
        /// A platform, or nil for "More" (the system share sheet).
        case share(ShareDestination?)
        /// Only the file: "Ready to travel" shows it, and nothing is delivered or counted until the creator picks where it goes.
        case render
        /// The file for a "Share to universe" queue, saved to Photos first when asked (`prepared` is set).
        case prepare(alsoSavesToPhotos: Bool)
    }

    let takeID: UUID
    private(set) var runningAction: ExportAction?
    /// The running export's file is on its way (Photos, the share sheet, another app): from here it can't be called back, and it ends as it
    /// would have.
    private(set) var isDelivering = false
    /// A way out of the review asks "Cancel export?" first; past the render (`isDelivering`) nothing is asked: it ends in a moment.
    var canCancelExport: Bool { runningAction != nil && !isDelivering }
    /// The running export (`export`), so "Cancel export" can stop it.
    @ObservationIgnored private var exportJob: Task<Bool, Error>?
    /// The file the running export made or reused: one stopped before it left Cue leaves no copy behind.
    @ObservationIgnored private var preparedOperation: UUID?
    /// Where the export is, told apart: preparing, saving, handed over, cancelled, failed, delivered.
    private(set) var phase: ExportPhase = .idle
    /// Set when an export is ready for the system share sheet.
    var activity: ActivityShare?
    var paywall: PaywallContext?
    /// The free exports are used up and the creator tapped something that exports: "Your video is ready" asks before anything else.
    var showsExportReady = false
    /// "Not now" was answered: the take stays ready, and its line says "READY · EXPORT WITH PRO" until the next export attempt.
    private(set) var exportDeclined = false
    /// "Ready to travel" after a save, "On its way" once a platform's app has the video.
    var celebration: ExportCelebration?
    /// The file `.prepare` made, for the queue.
    private(set) var prepared: ExportedVideo?
    /// Operations saved to Photos in this review ("Save video" turns into "Saved to Photos").
    private(set) var savedOperations: Set<UUID> = []
    /// Counts Save's trips to Photos that arrived, for its ✓ on the screen.
    private(set) var savesToPhotos = 0
    /// "Share to universe" hears how a share sheet ended for a network it sent (true: handled, so no send-off is played here).
    @ObservationIgnored var queueInterceptor: ((ShareDestination, ActivityResult) -> Bool)?
    /// The queue that edits are made for: re-exporting inside it costs no second export.
    @ObservationIgnored var queueOperation: () -> UUID? = { nil }
    /// "Share to universe" starts its queue again, once a purchase gave back the export it waited for.
    @ObservationIgnored var queueResumes: (() async -> Void)?
    /// An export finished (the take, and whether it went to Photos): a notification tells a creator who left Cue meanwhile.
    @ObservationIgnored var onExported: (UUID, Bool) -> Void = { _, _ in }
    /// "Share to".
    var showsShareSheet = false
    /// Photos refused the save (Save, or the "Share to universe" queue's copy): the review and the queue show a card with Open Settings
    /// instead of a toast.
    var photosDenied = false
    /// The last export failed: the review keeps a card with why and **Try again** (`ExportFailure`) until it is closed or an export starts.
    private(set) var exportFailure: ExportFailure?
    /// Operations whose cover was saved to Photos with the video ("Video and cover saved" on Ready to travel).
    private(set) var coversSaved: Set<UUID> = []
    /// **Try again** on a cover that couldn't be saved (tests wait on it).
    @ObservationIgnored private(set) var coverRetry: Task<Void, Never>?
    /// Where "#ad" goes for a sponsored video (the system pasteboard; a test swaps it).
    @ObservationIgnored var copiesCaption: (String) -> Void = { UIPasteboard.general.string = $0 }
    var burnsInCaptions = false
    /// Which captions this export burns in: the original, a translation or both (one export per
    /// language).
    var exportCaptionDisplay: CaptionDisplay = .original
    /// Why the video being exported has no captions although they were asked for.
    @ObservationIgnored private var captionNotice: String?
    private(set) var quality: ExportQuality = .hd1080
    /// How far the running export is, 0 to 1 (nil when none runs).
    private(set) var exportProgress: Double?
    /// Whether the running export goes on if the creator leaves Cue (nil when none runs).
    private(set) var exportMode: BackgroundExportMode?
    /// The last export of this take stopped with Cue (closed from the app switcher, or ended by iOS) before it finished.
    private(set) var exportStopped = false

    private var pendingAction: ExportAction?
    /// Share sheets already acted on: a completion heard twice counts and tells once.
    private var handledActivities: Set<UUID> = []

    private let takes: TakeLibraryService
    private let quota: UsageQuotaService
    private let tier: () -> MembershipTier
    private let exporter: VideoExporting
    private let photos: PhotoSaving
    private let sharing: VideoSharing
    private let ledger: ExportLedgerService
    private let editing: TakeEditing
    private let library: ScriptLibraryService
    private let rules: PlatformRulesService
    private let profile: CreatorProfileService
    private let preferences: PreferencesService
    private let drafts: QuickEditDraftStoring
    private let toast: ToastService
    private let background: BackgroundExportRunning
    /// Bytes free on the iPhone (`StorageSpace.available`); a test gives its own.
    private let freeSpace: () -> Int64?
    /// Where an export failure the creator saw is written down (Console and Crashlytics, `EditorFailureReport`); tests read it.
    @ObservationIgnored var reportFailure: (EditorFailureReport) -> Void = { $0.send() }
    /// What a script is heard in for captions (`LanguageService.captionRequest(for:)`).
    private let speechLanguageFor: (Script?) -> SpeechLanguageRequest
    /// The languages a take without a script is likely spoken in (`LanguageService.likelySpokenLanguages(for:)`).
    private let likelySpokenLanguagesFor: (Script?) -> [CueLanguage]

    init(
        takeID: UUID,
        takes: TakeLibraryService,
        quota: UsageQuotaService,
        tier: @escaping () -> MembershipTier,
        exporter: VideoExporting,
        photos: PhotoSaving,
        sharing: VideoSharing,
        ledger: ExportLedgerService,
        editing: TakeEditing,
        library: ScriptLibraryService,
        rules: PlatformRulesService,
        profile: CreatorProfileService,
        preferences: PreferencesService,
        drafts: QuickEditDraftStoring,
        toast: ToastService,
        background: BackgroundExportRunning? = nil,
        freeSpace: @escaping () -> Int64? = { StorageSpace.available() },
        speechLanguage: @escaping (Script?) -> SpeechLanguageRequest = SpeechLanguageRequest.script,
        likelySpokenLanguages: @escaping (Script?) -> [CueLanguage] = { _ in [] }
    ) {
        speechLanguageFor = speechLanguage
        likelySpokenLanguagesFor = likelySpokenLanguages
        self.takeID = takeID
        self.takes = takes
        self.quota = quota
        self.tier = tier
        self.exporter = exporter
        self.photos = photos
        self.sharing = sharing
        self.ledger = ledger
        self.editing = editing
        self.library = library
        self.rules = rules
        self.profile = profile
        self.preferences = preferences
        self.drafts = drafts
        self.toast = toast
        self.background = background ?? BackgroundExportRunner(scheduler: nil)
        self.freeSpace = freeSpace
        burnsInCaptions = takes.take(id: takeID)?.edit?.showsCaptions ?? false
        exportStopped = preferences.stoppedExports.contains(takeID)
    }

    /// The stopped export was seen (its notice closed, or the take exported again).
    func dismissStoppedExport() {
        exportStopped = false
        preferences.stoppedExports.remove(takeID)
    }

    // MARK: - Reading

    var take: Take? { takes.take(id: takeID) }

    /// This take and the others of the same script, by number ("Your takes · 3").
    var siblings: [Take] { take.map(takes.siblings(of:)) ?? [] }

    var videoURL: URL? { take.map(takes.videoURL(for:)) }

    /// Where this video is on its way out (the takes of its script): derived, never set by hand.
    var stage: TakeStage {
        TakeStage(takes: siblings, hasDraft: { [drafts] in drafts.hasDraft(for: $0) })
    }

    /// An edit left open on this take would change its video: Save and Share ask first, since they export the finished one (B4).
    var hasUnfinishedEdit: Bool { take.map { drafts.unfinishedEdit(of: $0) != nil } ?? false }

    /// The take has a finished edit: without one, an export is the recording as it was ("Export original").
    var hasFinishedEdit: Bool { take?.edit != nil }

    /// An edit is open on this take: the main action reads "Continue" and goes on with it. On another take of the video, Edit starts its own
    /// (Takes, "In edit" and the reminder open the take whose edit is open: `QuickEditDraftStoring.takeInEdit`).
    var hasOpenEdit: Bool { take.map { drafts.hasDraft(for: $0.id) } ?? false }

    /// The take's length against its platform's ideal range: "✓ FITS 1:00–1:30", or how far off.
    var lengthFit: LengthFit? {
        guard let take else { return nil }
        let platform = take.platform ?? library.script(id: take.scriptID)?.platform
        guard let platform else { return nil }
        let preset = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals)
        return LengthFit(seconds: take.edit?.editedDuration ?? take.duration, ideal: preset.idealRange)
    }

    /// The script this take was read from, and its version ("v1"); nil for a freestyle take.
    var scriptVersionLabel: String? {
        guard let take, let version = take.scriptVersion, !take.isFreestyle else { return nil }
        return "v\(version)"
    }

    /// The sibling `offset` takes away (by number), for the swipe; nil at the ends.
    func neighbor(_ offset: Int) -> Take? {
        guard let take, let index = siblings.firstIndex(where: { $0.id == take.id }) else { return nil }
        let target = index + offset
        return siblings.indices.contains(target) ? siblings[target] : nil
    }

    /// Nil when unlimited.
    var exportsLeft: Int? { quota.exportsLeft(for: tier()) }

    /// The line under Share (6.3): the free exports left, the last one, none, or Pro.
    var exportLabel: FreeExportLabels.Label { FreeExportLabels.take(left: exportsLeft, declined: exportDeclined) }

    /// "Not now", the close button or a swipe down: nothing is exported, nothing is lost.
    func declineExport() {
        guard showsExportReady else { return }
        showsExportReady = false
        pendingAction = nil
        exportDeclined = true
        toast.show(String(localized: "Saved in Takes · export with Pro anytime"))
    }

    /// "Export with Cue Pro": the calm Pro, with the video waiting.
    func openProFromExportReady() async {
        showsExportReady = false
        // The sheet has to be gone before the full-screen cover can come up.
        try? await Task.sleep(for: proDelay)
        paywall = .export
    }

    /// How long the sheet takes to leave before the calm Pro comes up (a test sets it to zero).
    @ObservationIgnored var proDelay: Duration = .milliseconds(450)

    var exportsExhausted: Bool { exportsLeft == 0 }

    /// 4K keeps the recording's resolution (a 1080p take isn't upscaled); 1080p scales 4K down.
    /// About 2.2 MB a second at 1080p and 6.5 at 4K (the export's HEVC), for the space check.
    private func estimatedMegabytes(of take: Take) -> Double {
        let perSecond = quality == .uhd4K && take.resolution == .uhd4K ? 6.5 : 2.2
        return max(1, ((take.edit?.editedDuration ?? take.duration) * perSecond).rounded())
    }

    private func outputShortSide(for take: Take) -> CGFloat? {
        take.resolution == .uhd4K && quality == .hd1080 ? quality.shortSide : nil
    }

    private func outputResolutionLabel(for take: Take) -> String {
        quality == .uhd4K ? take.resolution.label : quality.label
    }

    func setQuality(_ quality: ExportQuality) {
        self.quality = quality
    }

    // MARK: - Actions

    // MARK: - Best take

    /// "Suggest best" sits after a script's takes once there are two or more.
    var offersBestSuggestion: Bool { take?.isFreestyle == false && siblings.count > 1 }

    /// The complete take closest to the script's timing, preferring the platform's ideal range, with why. The
    /// "Pick your best take" screen shows it; the creator still decides.
    func bestProposal() -> BestTakeProposal? {
        guard let take, let script = library.script(id: take.scriptID) else { return nil }
        let platform = take.platform ?? script.platform
        let preset = rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals)
        let expected = script.readSeconds
        guard let best = BestTakeSuggester.suggestion(among: siblings, expectedDuration: expected, idealRange: preset.idealRange) else {
            return nil
        }
        return BestTakeProposal(
            takes: siblings, best: best,
            reasons: BestTakeReason.reasons(for: best, among: siblings, expectedDuration: expected, idealRange: preset.idealRange),
            platformLabel: platform.label, ideal: preset.idealRange
        )
    }

    /// "Use take 2": it becomes the video's best take.
    func markBest(_ chosen: Take) {
        takes.setBest(chosen.id, isBest: true)
        toast.show(String(localized: "\(chosen.label) marked as best"))
    }

    func toggleBest() {
        guard let take else { return }
        takes.setBest(takeID, isBest: !take.isBest)
        if !take.isBest {
            toast.show(String(localized: "\(take.label) marked as best"))
        }
    }

    /// Deletes this take and returns the one to show next (the newest sibling left), or nil to
    /// leave the review.
    func delete() -> Take? {
        guard let take else { return nil }
        let rest = siblings.filter { $0.id != take.id }
        guard let removed = takes.remove(take.id) else { return nil }
        // Gone at once, with its Undo; its video is deleted for good only once the Undo is out of reach: when the toast leaves (its time,
        // another toast in its place) or Cue goes to the background (`TakeLibraryService.purgeAwaiting`), never on a clock of its own.
        let library = takes
        library.awaitPurge(removed)
        toast.show(String(localized: "\(take.label) deleted"), action: ToastAction(title: String(localized: "Undo")) {
            library.restore(removed)
        })
        toast.onLeave(of: toast.pill) { library.purgeAwaiting(removed.take.id) }
        return rest.last
    }

    func save() async {
        await export(.save)
    }

    /// "Share to universe": the file for the video, rendered without delivering or counting anything ("Ready to travel" shows it). `operationID`
    /// carries on a queue whose file the system cleared.
    func render(continuing operationID: UUID? = nil) async {
        await export(.render, continuing: operationID)
    }

    /// The file the queue shares, saved to Photos first when asked. Counts the export (once) when it is saved; the free exports run out here.
    /// Nil when nothing was made (the free exports are used up, or it failed).
    func prepare(alsoSavingToPhotos: Bool, continuing operationID: UUID? = nil) async -> ExportedVideo? {
        prepared = nil
        await export(.prepare(alsoSavesToPhotos: alsoSavingToPhotos), continuing: operationID)
        defer { prepared = nil }
        return prepared
    }

    /// The export of this file is already counted (saved, or sent before): sharing it again costs nothing.
    func isCounted(_ video: ExportedVideo) -> Bool { ledger.isCounted(operationID: video.operationID) }

    func isSaved(_ video: ExportedVideo) -> Bool { savedOperations.contains(video.operationID) }

    /// The length that suits a network, for "FITS" under it in the picker.
    func idealRange(for platform: Platform) -> ClosedRange<TimeInterval> {
        rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals).idealRange
    }

    /// The text copied for a network's caption: the script's title, and "#ad" for a sponsored video.
    var postCaption: String {
        guard let take else { return "" }
        let title = take.isFreestyle ? "" : take.scriptTitle
        return [title, isSponsored ? Self.adCaption : nil].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// A refused Photos permission is a card with the way out; anything else is the export's card, with why and **Try again**, which stays
    /// (after a purchase too, when the paywall that was in front has gone): the export count stays where it was (04 · F6).
    private func report(_ error: Error, action: ExportAction) {
        if !(error is PhotoLibraryError), let failure = EditorFailureReport.make(error, operation: "export", edit: take?.edit) {
            reportFailure(failure)
        }
        if case PhotoLibraryError.notAuthorized = error {
            photosDenied = true
            return
        }
        exportFailure = ExportFailure(error: error, action: action)
    }

    /// **Try again** on the export's card: the same export, from the start.
    func retryFailedExport() async {
        guard let failure = exportFailure else { return }
        exportFailure = nil
        await export(failure.action)
    }

    /// ✕ on the export's card.
    func dismissExportFailure() {
        exportFailure = nil
    }

    /// The cover was saved to Photos with this video.
    func savedCover(_ video: ExportedVideo) -> Bool { coversSaved.contains(video.operationID) }

    /// A sponsored script (8.1): the share sheet warns, and "#ad" travels in the caption.
    var isSponsored: Bool { library.script(id: take?.scriptID)?.type == .ad }

    static let adCaption = "#ad"

    /// A platform's tile. How the video gets there depends on what the platform allows (`ShareRoute`): TikTok's Share Kit,
    /// Instagram's hand-off, the system share sheet, or saving to Photos and opening the app. Nil is "More": the system
    /// share sheet.
    func share(to destination: ShareDestination?) async {
        await export(.share(destination))
    }

    /// Continues the export that opened the paywall, now that Pro is on. A queue's export goes on as the queue (`ShareFlow.start`): the
    /// export alone would save to Photos and stop, with the networks still waiting, and the next "Share" would save it again.
    func continueAfterPurchase() async {
        guard let action = pendingAction else { return }
        pendingAction = nil
        if case .prepare = action, let queueResumes {
            await queueResumes()
            return
        }
        await export(action)
    }

    /// "Other apps" / "Share again": the system share sheet for a file that was already exported (the same operation, so
    /// it never counts twice). If the system cleared the file, it is rendered again for the same operation.
    func share(_ video: ExportedVideo) {
        // The icon is a way out like any other: with the free exports gone, "Your video is ready" asks first.
        guard isCounted(video) || quota.canExport(tier: tier()) else {
            pendingAction = .share(nil)
            exportDeclined = false
            showsExportReady = true
            return
        }
        guard let operation = ledger.operation(id: video.operationID), ledger.fileExists(for: operation) else {
            Task { await export(.share(nil), continuing: video.operationID) }
            return
        }
        presentActivity(for: operation, destination: nil)
    }

    /// The review is closing with nothing in flight: the exported files go. (A file is kept while the share sheet, a
    /// celebration or an export needs it, and for the next retry of the same edit.)
    func leave() {
        guard runningAction == nil, activity == nil, celebration == nil, !showsShareSheet else { return }
        ledger.releaseFiles(forTake: takeID)
    }

    private func export(_ action: ExportAction, continuing operationID: UUID? = nil) async {
        guard let take, runningAction == nil else { return }
        // Used up, and nothing of this take already out: "Your video is ready" before any work. Making the file is free; delivering it is not.
        guard action == .render || quota.canExport(tier: tier()) || ledger.hasCountedOperation(forTake: take.id) else {
            pendingAction = action
            exportDeclined = false
            showsExportReady = true
            return
        }
        runningAction = action
        phase = .preparing
        exportProgress = 0
        exportFailure = nil
        dismissStoppedExport()
        // Marked while it runs: still marked when Cue opens again means it stopped with Cue.
        preferences.exportsInFlight.insert(take.id)
        // The file and where it goes, as one piece of work iOS can let run outside Cue (leaving Cue is not cancelling).
        let job = Task { @MainActor in
            try await background.run(
                title: String(localized: "Exporting your video"), subtitle: take.label, started: { self.exportMode = $0 }, work: { report in
                guard let operation = try await self.prepareOperation(for: take, action: action, continuing: operationID, progress: { fraction in
                    self.exportProgress = fraction
                    report(fraction)
                }) else {
                    return false
                }
                self.preparedOperation = operation.id
                // "Cancel export" before this line: nothing leaves Cue, nothing is counted. Checked and marked with no wait between them, on
                // the main actor, so a cancel can't land halfway (`cancelExport` refuses once delivering).
                try Task.checkCancellation()
                self.isDelivering = true
                try await self.deliver(action, operation: operation, take: take)
                self.onExported(take.id, self.savedOperations.contains(operation.id))
                return true
            })
        }
        exportJob = job
        defer {
            runningAction = nil
            exportProgress = nil
            exportMode = nil
            exportJob = nil
            isDelivering = false
            preparedOperation = nil
            preferences.exportsInFlight.remove(take.id)
        }
        do {
            let delivered = try await job.value
            if !delivered { phase = .idle }
        } catch where job.isCancelled {
            // Cancelled on the way out of the review: the file it made goes (the record stays, uncounted).
            phase = .idle
            if let preparedOperation { ledger.releaseFile(of: preparedOperation) }
        } catch {
            phase = .failed
            report(error, action: action)
        }
    }

    /// "Cancel export" (leaving the review while it exports): the render stops and nothing is saved, shared or counted, not even by a
    /// render that ends late. False once the file is on its way (`isDelivering`): that delivery ends as it would have, and says so.
    @discardableResult
    func cancelExport() -> Bool {
        guard let exportJob, !isDelivering else { return false }
        exportJob.cancel()
        return true
    }

    /// The file for this export: the one already made for the same edit and settings, else a new render. Nil when the
    /// free exports are used up (the paywall is open). A video already counted never needs the quota again, its file there or made again.
    private func prepareOperation(
        for take: Take, action: ExportAction, continuing operationID: UUID?, progress: @escaping @MainActor (Double) -> Void
    ) async throws -> ExportOperation? {
        let options = ExportOptions(
            aspect: take.outputAspect, edit: await editForExport(take),
            burnsInCaptions: burnsInCaptions, shortSide: outputShortSide(for: take)
        )
        let source = takes.videoURL(for: take)
        let fingerprint = ExportFingerprint.make(takeID: take.id, source: source, options: options)
        let reusable = ledger.reusableOperation(fingerprint: fingerprint)
        let continued = operationID.flatMap { ledger.operation(id: $0) }.flatMap { $0.fingerprint == fingerprint ? $0 : nil }
        if action != .render, !ledger.isCounted(fingerprint: fingerprint), !quota.canExport(tier: tier()) {
            pendingAction = action
            exportDeclined = false
            showsExportReady = true
            return nil
        }
        if let reusable { return reusable }
        // A full iPhone is told now, with how much to free, never after minutes of work.
        if let missing = StorageSpace.shortfall(forExportOf: estimatedMegabytes(of: take), available: freeSpace()) {
            throw ExportPreflightError.notEnoughSpace(megabytes: missing)
        }
        let url = try await exporter.export(videoAt: source, options: options, progress: progress)
        if let continued {
            // The same export, its file made again after the system cleared the first: not a second export.
            ledger.replaceFile(of: continued.id, with: url)
            return ledger.operation(id: continued.id)
        }
        // An edit made inside a queue that already counted its export is the same export: it costs nothing more.
        let inherited = queueOperation().flatMap { ledger.operation(id: $0) }.flatMap { $0.takeID == take.id && $0.isCounted ? $0.id : nil }
        return ledger.begin(takeID: take.id, fingerprint: fingerprint, file: url, inheritingCountFrom: inherited)
    }

    private func deliver(_ action: ExportAction, operation: ExportOperation, take: Take) async throws {
        switch action {
        case .render:
            phase = .idle
            celebration = .readyToTravel(exported(take, operation: operation))
        case .prepare(let alsoSaves):
            if alsoSaves {
                phase = .savingToPhotos
                do {
                    let assetID = try await photos.saveVideo(at: ledger.fileURL(of: operation))
                    recordDelivery(.photoLibrary(assetID: assetID), operation: operation, take: take)
                    savedOperations.insert(operation.id)
                    await saveCover(after: operation)
                } catch PhotoLibraryError.notAuthorized {
                    // The networks can take the file without Photos: the queue goes on, and the first network that gets it counts the export.
                    // The queue's step shows the Photos card (with Open Settings), as Save does.
                    photosDenied = true
                }
            }
            phase = .idle
            prepared = exported(take, operation: operation)
        case .save:
            phase = .savingToPhotos
            let assetID = try await photos.saveVideo(at: ledger.fileURL(of: operation))
            savedOperations.insert(operation.id)
            savesToPhotos += 1
            recordDelivery(.photoLibrary(assetID: assetID), operation: operation, take: take)
            let withCover = await saveCover(after: operation)
            photosDenied = false
            showsShareSheet = false
            // No toast: "Ready to travel" says it all, its button turned into "✓ Saved to Photos", the free exports on its meter, and
            // missing captions on the cover itself.
            celebration = .readyToTravel(exported(take, operation: operation))
            let saved = withCover ? String(localized: "Video and cover saved to Photos") : String(localized: "Saved to Photos")
            AccessibilityNotification.Announcement(saved).post()
        case .share(nil):
            presentActivity(for: operation, destination: nil)
        case .share(let destination?):
            try await share(operation, of: take, to: destination)
        }
    }

    private func share(_ operation: ExportOperation, of take: Take, to destination: ShareDestination) async throws {
        var route = sharing.route(for: destination, duration: take.edit?.editedDuration ?? take.duration)
        guard route != .activitySheet else {
            presentActivity(for: operation, destination: destination)
            return
        }
        var assetID = operation.photosAssetID
        if route.needsPhotosCopy {
            phase = .savingToPhotos
            do {
                assetID = try await photos.saveVideo(at: ledger.fileURL(of: operation))
            } catch PhotoLibraryError.notAuthorized {
                // The share sheet can take the file without Photos.
                presentActivity(for: operation, destination: destination)
                return
            }
            recordDelivery(.photoLibrary(assetID: assetID), operation: operation, take: take)
            await saveCover(after: operation)
            // Share Kit takes the library's identifier; without one, the app opens and the creator picks the video.
            if route == .shareKit && assetID == nil { route = .saveAndOpen }
        }
        if route == .saveOnly {
            // Nothing takes the video directly: it is in Photos, and the creator is told to post it from the app.
            showsShareSheet = false
            // What the video holds is read before the message says it (the message forgets why captions are missing).
            celebration = .readyToTravel(exported(take, operation: operation))
            announce(savedForPostingMessage(for: destination, tier: tier()))
            return
        }
        let video = SharedVideo(
            operationID: operation.id, url: ledger.fileURL(of: operation), photosAssetID: assetID,
            duration: take.edit?.editedDuration ?? take.duration
        )
        phase = .delivering(destination)
        let outcome = await sharing.send(video, to: destination, via: route) { [weak self] late in
            self?.finishHandoff(late, destination: destination, route: route, operationID: operation.id)
        }
        finishHandoff(outcome, destination: destination, route: route, operationID: operation.id)
    }

    /// What the hand-off came to, now or when the platform called back. Only `.delivered` counts and celebrates; `.opened`
    /// is told as exactly that.
    private func finishHandoff(_ outcome: ShareOutcome, destination: ShareDestination, route: ShareRoute, operationID: UUID) {
        guard let take = takes.take(id: takeID), let operation = ledger.operation(id: operationID) else { return }
        let label = destination.platform.label
        switch outcome {
        case .delivered(let evidence):
            recordDelivery(evidence, operation: operation, take: take)
            showsShareSheet = false
            celebration = .sentOff(exported(take, operation: operation), [destination])
            announce(sharedMessage(with: label))
        case .pending:
            showsShareSheet = false
        case .opened:
            showsShareSheet = false
            if route.needsPhotosCopy {
                // Saved, and the app is open for the creator to pick it.
                celebration = .readyToTravel(exported(take, operation: operation))
                announce(readyMessage(for: destination, tier: tier()))
            } else {
                // Instagram: the video left Cue (on the pasteboard, with the composer open), which counts. Whether it read it, or
                // the creator posts it, Instagram doesn't say.
                recordDelivery(.pasteboardHandoff, operation: operation, take: take)
                phase = .delivering(destination)
                toast.show(openedMessage(with: label))
            }
        case .cancelled:
            phase = .cancelled
            toast.show(String(localized: "Sharing cancelled"))
        case .unavailable:
            // Not there after all (or it wouldn't open): the share sheet takes the file.
            toast.show(String(localized: "\(label) isn’t on this iPhone · Pick another app"), kind: .problem)
            presentActivity(for: operation, destination: destination)
        case .failed:
            phase = .failed
            toast.show(String(localized: "\(label) didn’t take the video"), kind: .problem)
        }
    }

    private func presentActivity(for operation: ExportOperation, destination: ShareDestination?) {
        phase = .delivering(destination)
        activity = ActivityShare(operationID: operation.id, url: ledger.fileURL(of: operation), destination: destination)
    }

    /// How the system share sheet ended. A finished activity is a delivery (the file reached an app); a cancelled one
    /// isn't, and the Photos copy, if the video was saved first, already counted.
    func activityFinished(_ result: ActivityResult, for share: ActivityShare) {
        self.activity = nil
        guard handledActivities.insert(share.id).inserted,
              let operation = ledger.operation(id: share.operationID), let take = takes.take(id: operation.takeID) else { return }
        // A network of a "Share to universe" queue: a finished sheet is a delivery, and the queue asks whether it went live.
        if case .completed(let type) = result { recordDelivery(.activity(type: type), operation: operation, take: take) }
        if let destination = share.destination, queueInterceptor?(destination, result) == true { return }
        switch result {
        case .completed(let type):
            showsShareSheet = false
            if let destination = share.destination, destination.matches(activityType: type) {
                celebration = .sentOff(exported(take, operation: operation), [destination])
                announce(sharedMessage(with: destination.platform.label))
            } else {
                announce(sharedMessage(with: nil))
            }
        case .cancelled:
            phase = .cancelled
        case .failed:
            phase = .failed
            toast.show(String(localized: "Couldn’t share · Try again"), kind: .problem)
        }
    }

    /// The video provably left Cue: the ledger counts the operation (once), the take is "shared", and a sponsored video
    /// puts "#ad" on the pasteboard.
    private func recordDelivery(_ evidence: DeliveryEvidence, operation: ExportOperation, take: Take) {
        ledger.recordDelivery(evidence, for: operation.id, tier: tier())
        takes.markExported(take.id)
        phase = .delivered(evidence)
        if isSponsored { copiesCaption(Self.adCaption) }
    }

    private func exported(_ take: Take, operation: ExportOperation) -> ExportedVideo {
        let currentTier = tier()
        return ExportedVideo(
            operationID: operation.id, take: take, url: ledger.fileURL(of: operation),
            formatLabel: "\(outputResolutionLabel(for: take).uppercased()) · \(take.outputAspect.label)",
            hasCaptions: burnsInCaptions && captionNotice == nil, missingCaptions: burnsInCaptions ? captionNotice : nil,
            exportsLeft: quota.exportsLeft(for: currentTier), platform: take.platform
        )
    }

    /// "Ready to travel" → "Share to TikTok": the same exported file, so a video that was saved is not counted again.
    func send(_ video: ExportedVideo, to destination: ShareDestination) async {
        await export(.share(destination), continuing: video.operationID)
    }

    /// The take's caption translations, for the export's caption language.
    var captionTranslations: [CaptionTranslation] {
        take?.edit?.captionTranslations ?? []
    }

    /// Captions to burn in come from the edit; a take never captioned gets them now from its voice
    /// (cached as source data). When none can be made, the video exports without them and `captionNotice` says
    /// why: nothing is ever spread over the take in their place.
    private func editForExport(_ take: Take) async -> TakeEdit? {
        captionNotice = nil
        guard burnsInCaptions else { return take.edit }
        var edit = take.edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        if take.edit == nil {
            edit.captionCollection?.safeMargins = CaptionSafeArea.margins(for: take, aspect: edit.aspect)
            // Captions on a never-edited take don't opt it into the editor's default voice effect.
            edit.voiceEnhancement = .off
            edit.enhancesVoice = false
        }
        edit.showsCaptions = true
        edit.captionDisplay = edit.captionTranslations.contains { $0.language == exportCaptionDisplay.language } ? exportCaptionDisplay : .original
        if edit.captions.isEmpty {
            let script = take.captionScript(current: library.script(id: take.scriptID))
            let language = edit.captionLanguage.map(SpeechLanguageRequest.language) ?? speechLanguageFor(script)
            // On Auto, a take without a script is heard in the language it's spoken in.
            let candidates = edit.captionLanguage == nil ? likelySpokenLanguagesFor(script) : []
            let outcome = try? await editing.captions(
                forVideoAt: takes.videoURL(for: take), script: script?.text ?? "", language: language, spokenAmong: candidates,
                progress: { _ in }
            )
            switch outcome {
            case .captions(let lines, let transcript)?:
                edit.captions = lines
                edit.captionTranscript = transcript
                takes.cacheCaptions(lines, transcript: transcript, for: take.id)
            case .unavailable(let reason)?: captionNotice = reason.captionMessage
            case .noSpeech?, .noAudio?: captionNotice = String(localized: "No speech to caption, so the video has none.")
            case nil: captionNotice = String(localized: "Couldn’t listen to this take, so the video has no captions.")
            }
        }
        return edit
    }

    /// A finished export's message, with why captions are missing when they were asked for. Read after the celebration took what the
    /// video holds (`exported`): before, "Ready to travel" said CAPTIONS ON for a video without them.
    private func announce(_ message: String) {
        toast.show(captionNotice.map { message + " · " + $0 } ?? message)
        captionNotice = nil
    }

    private func readyMessage(for destination: ShareDestination, tier: MembershipTier) -> String {
        let ready = String(localized: "Ready to post on \(destination.platform.label)")
        guard let left = quota.exportsLeft(for: tier) else { return ready }
        return ready + " · " + String(localized: "\(left) of \(UsagePolicy.freeExports) free exports left")
    }

    /// "Opened Reels with your video · Cue can't see if you post it", with the free exports left.
    private func openedMessage(with label: String) -> String {
        let opened = String(localized: "Opened \(label) with your video · Cue can’t see if you post it")
        guard let left = quota.exportsLeft(for: tier()) else { return opened }
        return opened + " · " + String(localized: "\(left) of \(UsagePolicy.freeExports) free exports left")
    }

    /// "Saved to Photos · Open LinkedIn to post it", with the free exports left.
    private func savedForPostingMessage(for destination: ShareDestination, tier: MembershipTier) -> String {
        let saved = String(localized: "Saved to Photos · Open \(destination.platform.label) to post it")
        guard let left = quota.exportsLeft(for: tier) else { return saved }
        return saved + " · " + String(localized: "\(left) of \(UsagePolicy.freeExports) free exports left")
    }

    /// "Shared with TikTok" (or "Shared" when the creator picked another app), with the free exports left.
    private func sharedMessage(with label: String?) -> String {
        let shared = label.map { String(localized: "Shared with \($0)") } ?? String(localized: "Shared")
        guard let left = quota.exportsLeft(for: tier()) else { return shared }
        return shared + " · " + String(localized: "\(left) of \(UsagePolicy.freeExports) free exports left")
    }

    /// The chosen cover, saved to Photos after its video: true when one was. One that couldn't be saved says so, the video being there, with
    /// **Try again**, which saves the cover alone (`retryCover`).
    @discardableResult
    private func saveCover(after operation: ExportOperation) async -> Bool {
        do {
            let saved = try await saveCoverIfChosen()
            if saved { coversSaved.insert(operation.id) }
            return saved
        } catch {
            if !(error is PhotoLibraryError), let failure = EditorFailureReport.make(error, operation: "cover", edit: take?.edit) {
                reportFailure(failure)
            }
            offerCoverAgain(for: operation.id)
            return false
        }
    }

    private func offerCoverAgain(for operationID: UUID) {
        toast.showResult(
            String(localized: "Video saved. Couldn't save the cover image."), kind: .problem,
            action: ToastAction(title: String(localized: "Try again")) { [weak self] in self?.retryCover(for: operationID) }
        )
    }

    /// The cover alone, drawn and saved again: no new video, nothing counted.
    func retryCover(for operationID: UUID) {
        coverRetry?.cancel()
        coverRetry = Task {
            do {
                guard try await saveCoverIfChosen() else { return }
                coversSaved.insert(operationID)
                toast.show(String(localized: "Cover saved to Photos"))
            } catch {
                offerCoverAgain(for: operationID)
            }
        }
    }

    /// Draws the take's cover and saves it to Photos. False when no cover was chosen.
    private func saveCoverIfChosen() async throws -> Bool {
        guard let take, let edit = take.edit, let cover = edit.cover else { return false }
        guard let data = await editing.coverImage(cover, forVideoAt: takes.videoURL(for: take), edit: edit) else {
            throw CoverError.unreadable
        }
        let url = URL.temporaryDirectory.appending(path: "Cue-cover-\(UUID().uuidString.prefix(8)).jpg")
        try data.write(to: url, options: .atomic)
        // Photos keeps its own copy.
        defer { try? FileManager.default.removeItem(at: url) }
        try await photos.saveImage(at: url)
        return true
    }
}
