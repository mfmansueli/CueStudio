//
//  TakeReviewViewModel.swift
//  Cue Studio
//

import Foundation
import UIKit

/// Save a take, or share it to a platform ("Share to"). Every feature is free; the free plan
/// includes five exports, then exporting asks for Cue Pro (7 days free). Takes are never locked.
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
    /// "Share to universe" hears how a share sheet ended for a network it sent (true: handled, so no send-off is played here).
    @ObservationIgnored var queueInterceptor: ((ShareDestination, ActivityResult) -> Bool)?
    /// The queue that edits are made for: re-exporting inside it costs no second export.
    @ObservationIgnored var queueOperation: () -> UUID? = { nil }
    /// "Share to".
    var showsShareSheet = false
    /// Photos refused the save: the review shows a card with Open Settings instead of a toast.
    var photosDenied = false
    /// Where "#ad" goes for a sponsored video (the system pasteboard; a test swaps it).
    @ObservationIgnored var copiesCaption: (String) -> Void = { UIPasteboard.general.string = $0 }
    var burnsInCaptions = false
    /// Which captions this export burns in: the original, a translation or both (one export per
    /// language).
    var exportCaptionDisplay: CaptionDisplay = .original
    /// Why the video being exported has no captions although they were asked for.
    @ObservationIgnored private var captionNotice: String?
    private(set) var quality: ExportQuality = .hd1080

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
    /// What a script is heard in for captions (`LanguageService.captionRequest(for:)`).
    private let speechLanguageFor: (Script?) -> SpeechLanguageRequest

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
        speechLanguage: @escaping (Script?) -> SpeechLanguageRequest = SpeechLanguageRequest.script
    ) {
        speechLanguageFor = speechLanguage
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
        burnsInCaptions = takes.take(id: takeID)?.edit?.showsCaptions ?? false
    }

    // MARK: - Reading

    var take: Take? { takes.take(id: takeID) }

    /// This take and the others of the same script, by number ("Your takes · 3").
    var siblings: [Take] { take.map(takes.siblings(of:)) ?? [] }

    /// "Today · 9:25 AM · TikTok · 9:16 · 1080p"
    var metaLine: String {
        guard let take else { return "" }
        let when = take.recordedAt.formatted(.relative(presentation: .named).locale(.interface))
        let platform = take.platform?.label ?? String(localized: "Freestyle")
        return "\(when) · \(platform) · \(take.aspect.label) · \(take.resolution.label)"
    }

    var videoURL: URL? { take.map(takes.videoURL(for:)) }

    /// Where this video is on its way out (the takes of its script): derived, never set by hand.
    var stage: TakeStage {
        TakeStage(takes: siblings, hasDraft: { [drafts] in drafts.hasDraft(for: $0) })
    }

    /// An edit is open on one of its takes: the main action reads "Continue".
    var hasOpenEdit: Bool { siblings.contains { drafts.hasDraft(for: $0.id) } }

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

    /// The sibling `offset` takes away (by number), for the swipe and the "2 / 3" chip; nil at the ends.
    func neighbor(_ offset: Int) -> Take? {
        guard let take, let index = siblings.firstIndex(where: { $0.id == take.id }) else { return nil }
        let target = index + offset
        return siblings.indices.contains(target) ? siblings[target] : nil
    }

    /// "2 / 3": this take's place among the video's takes.
    var placeLabel: String? {
        guard siblings.count > 1, let take, let index = siblings.firstIndex(where: { $0.id == take.id }) else { return nil }
        return "\(index + 1) / \(siblings.count)"
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

    /// "Start free trial · export now" and "See what's in Pro": the calm Pro, with the video waiting.
    func openProFromExportReady() async {
        showsExportReady = false
        // The sheet has to be gone before the full-screen cover can come up.
        try? await Task.sleep(for: proDelay)
        paywall = .export
    }

    /// How long the sheet takes to leave before the calm Pro comes up (a test sets it to zero).
    @ObservationIgnored var proDelay: Duration = .milliseconds(450)

    var exportsExhausted: Bool { exportsLeft == 0 }

    /// "0:44 · 9:16 · 1080p"
    var shareMeta: String {
        guard let take else { return "" }
        return "\(DurationText.clock(take.edit?.editedDuration ?? take.duration)) · \(take.outputAspect.label) · \(outputResolutionLabel(for: take))"
    }

    /// 4K keeps the recording's resolution (a 1080p take isn't upscaled); 1080p scales 4K down.
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
        let expected = ReadTime.seconds(for: script.text, speed: preferences.prompter.speed)
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
        // Gone at once, with 4 s to take it back; its video is deleted for good after that.
        let library = takes
        toast.show(String(localized: "\(take.label) deleted"), action: ToastAction(title: String(localized: "Undo")) {
            library.restore(removed)
        })
        Task { @MainActor in
            try? await Task.sleep(for: ToastService.actionDuration + .milliseconds(600))
            library.purge(removed)
        }
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
    func isCounted(_ video: ExportedVideo) -> Bool { ledger.operation(id: video.operationID)?.isCounted ?? false }

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

    /// A refused Photos permission is a card with the way out; anything else is "Couldn't export · Try again" and the export
    /// count stays where it was (04 · F6).
    private func report(_ error: Error) {
        if case PhotoLibraryError.notAuthorized = error {
            photosDenied = true
        } else {
            toast.show(String(localized: "Couldn't export · Try again"))
        }
    }

    /// A sponsored script (8.1): the share sheet warns, and "#ad" travels in the caption.
    var isSponsored: Bool { library.script(id: take?.scriptID)?.type == .ad }

    static let adCaption = "#ad"

    /// A platform's tile. How the video gets there depends on what the platform allows (`ShareRoute`): TikTok's Share Kit,
    /// Instagram's hand-off, the system share sheet, or saving to Photos and opening the app. Nil is "More": the system
    /// share sheet.
    func share(to destination: ShareDestination?) async {
        await export(.share(destination))
    }

    /// Continues the export that opened the paywall, now that Pro (or its trial) is on.
    func continueAfterPurchase() async {
        guard let action = pendingAction else { return }
        pendingAction = nil
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
        defer { runningAction = nil }
        do {
            guard let operation = try await prepareOperation(for: take, action: action, continuing: operationID) else {
                phase = .idle
                return
            }
            try await deliver(action, operation: operation, take: take)
        } catch {
            phase = .failed
            report(error)
        }
    }

    /// The file for this export: the one already made for the same edit and settings, else a new render. Nil when the
    /// free exports are used up (the paywall is open). An operation that was already counted never needs the quota again.
    private func prepareOperation(for take: Take, action: ExportAction, continuing operationID: UUID?) async throws -> ExportOperation? {
        let options = ExportOptions(
            aspect: take.outputAspect, edit: await editForExport(take),
            burnsInCaptions: burnsInCaptions, shortSide: outputShortSide(for: take)
        )
        let source = takes.videoURL(for: take)
        let fingerprint = ExportFingerprint.make(takeID: take.id, source: source, options: options)
        let reusable = ledger.reusableOperation(fingerprint: fingerprint)
        let continued = operationID.flatMap { ledger.operation(id: $0) }.flatMap { $0.fingerprint == fingerprint ? $0 : nil }
        if action != .render, !(reusable?.isCounted ?? false), !(continued?.isCounted ?? false), !quota.canExport(tier: tier()) {
            pendingAction = action
            exportDeclined = false
            showsExportReady = true
            return nil
        }
        if let reusable { return reusable }
        let url = try await exporter.export(videoAt: source, options: options)
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
                    _ = try? await saveCoverIfChosen()
                } catch PhotoLibraryError.notAuthorized {
                    // The networks can take the file without Photos: the queue goes on, and the first network that gets it counts the export.
                    toast.show(String(localized: "Photos is off · the video wasn't saved there"))
                }
            }
            phase = .idle
            prepared = exported(take, operation: operation)
        case .save:
            phase = .savingToPhotos
            let assetID = try await photos.saveVideo(at: ledger.fileURL(of: operation))
            savedOperations.insert(operation.id)
            recordDelivery(.photoLibrary(assetID: assetID), operation: operation, take: take)
            let withCover = (try? await saveCoverIfChosen()) ?? false
            showsShareSheet = false
            announce(savedMessage(tier: tier(), withCover: withCover))
            celebration = .readyToTravel(exported(take, operation: operation))
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
            _ = try? await saveCoverIfChosen()
            // Share Kit takes the library's identifier; without one, the app opens and the creator picks the video.
            if route == .shareKit && assetID == nil { route = .saveAndOpen }
        }
        if route == .saveOnly {
            // Nothing takes the video directly: it is in Photos, and the creator is told to post it from the app.
            showsShareSheet = false
            announce(savedForPostingMessage(for: destination, tier: tier()))
            celebration = .readyToTravel(exported(take, operation: operation))
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
            announce(sharedMessage(with: label))
            celebration = .sentOff(exported(take, operation: operation), [destination])
        case .pending:
            showsShareSheet = false
        case .opened:
            showsShareSheet = false
            if route.needsPhotosCopy {
                // Saved, and the app is open for the creator to pick it.
                announce(readyMessage(for: destination, tier: tier()))
                celebration = .readyToTravel(exported(take, operation: operation))
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
            toast.show(String(localized: "\(label) isn’t on this iPhone · Pick another app"))
            presentActivity(for: operation, destination: destination)
        case .failed:
            phase = .failed
            toast.show(String(localized: "\(label) didn’t take the video"))
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
                announce(sharedMessage(with: destination.platform.label))
                celebration = .sentOff(exported(take, operation: operation), [destination])
            } else {
                announce(sharedMessage(with: nil))
            }
        case .cancelled:
            phase = .cancelled
        case .failed:
            phase = .failed
            toast.show(String(localized: "Couldn’t share · Try again"))
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
            hasCaptions: burnsInCaptions && captionNotice == nil, exportsLeft: quota.exportsLeft(for: currentTier), platform: take.platform
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
            let outcome = try? await editing.captions(
                forVideoAt: takes.videoURL(for: take), script: script?.text ?? "", language: language, progress: { _ in }
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

    /// A finished export's message, with why captions are missing when they were asked for.
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

    private func savedMessage(tier: MembershipTier, withCover: Bool) -> String {
        let saved = withCover ? String(localized: "Video and cover saved to Photos") : String(localized: "Saved to Photos")
        if let left = quota.exportsLeft(for: tier) {
            return withCover
                ? saved + " · " + String(localized: "\(left) of \(UsagePolicy.freeExports) free exports left")
                : String(localized: "Saved to Photos · \(left) of \(UsagePolicy.freeExports) free exports left")
        }
        return saved
    }

    /// Draws the take's cover and saves it to Photos. False when no cover was chosen.
    private func saveCoverIfChosen() async throws -> Bool {
        guard let take, let edit = take.edit, let cover = edit.cover else { return false }
        guard let data = await editing.coverImage(cover, forVideoAt: takes.videoURL(for: take), edit: edit) else {
            throw CoverError.unreadable
        }
        let url = URL.temporaryDirectory.appending(path: "Cue-cover-\(UUID().uuidString.prefix(8)).jpg")
        try data.write(to: url, options: .atomic)
        try await photos.saveImage(at: url)
        return true
    }
}
