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
    /// The invites, from "Your video is ready" (§60).
    var showsInvites = false
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
    /// Written by the cover's saving (`TakeReviewViewModel+Cover`).
    var coversSaved: Set<UUID> = []
    /// **Try again** on a cover that couldn't be saved (tests wait on it).
    @ObservationIgnored var coverRetry: Task<Void, Never>?
    /// Where "#ad" goes for a sponsored video (the system pasteboard; a test swaps it).
    @ObservationIgnored var copiesCaption: (String) -> Void = { UIPasteboard.general.string = $0 }
    /// What Export options picked (D11), with the editor's captions it was picked against: while the edit shows the same captions in the same
    /// language, the pick holds for every way out (Save, Share, Done's answers); once the editor changes them, the export starts from the editor
    /// again. Nil until the creator picks. Written by `setOutput(_:for:)` (`TakeReviewViewModel+ExportOptions`).
    var pickedOutput: (editor: ExportOutputChoice, choice: ExportOutputChoice)?
    /// Whether this export burns its captions in: the editor's (`output(for:)`).
    var burnsInCaptions: Bool {
        get { output(for: take?.edit).burnsInCaptions }
        set {
            var choice = output(for: take?.edit)
            choice.burnsInCaptions = newValue
            setOutput(choice, for: take?.edit)
        }
    }
    /// Which captions this export burns in: the original, a translation or both (one export per
    /// language). Starts from what the editor shows, so a translation picked there goes out without a second pick.
    var exportCaptionDisplay: CaptionDisplay {
        get { output(for: take?.edit).captionDisplay }
        set {
            var choice = output(for: take?.edit)
            choice.captionDisplay = newValue
            setOutput(choice, for: take?.edit)
        }
    }
    /// Why the video being exported has no captions although they were asked for.
    @ObservationIgnored private var captionNotice: String?
    /// Some of the exported video's words came out in the system's face: the message after sending it says so.
    @ObservationIgnored private var fontNotice: String?
    /// What the creator picked in Export options for this video (nil until they pick); the pick is also kept for the next videos
    /// (`PreferencesService.exportQuality`). 4K is Cue Pro (owner, 06/11/2026); the export reads `exportQuality`.
    private var pickedQuality: ExportQuality? {
        didSet { if let pickedQuality { preferences.exportQuality = pickedQuality } }
    }
    /// The quality in Export options: the one picked; else the last one picked when it still fits (4K only with Pro and a 4K recording);
    /// else the recording's own with Pro (a 4K recording exports in 4K) and 1080p without.
    var quality: ExportQuality {
        let fourKFits = isPro && take?.resolution == .uhd4K
        if let pickedQuality { return pickedQuality }
        if let kept = preferences.exportQuality, kept != .uhd4K || fourKFits { return kept }
        return fourKFits ? .uhd4K : .hd1080
    }
    /// "4K export is Cue Pro" is up: 4K was picked without Pro (Go Pro, or Keep 1080p).
    var offersFourKPro = false
    /// The recording's upright frame in pixels, read from its file once the review opens (`loadRecordingFrame()`): what the export crops,
    /// so Done and Export options can say "606×1080" when that is the file. Nil until read.
    var recordingUprightSize: CGSize?
    /// Where the running export is: its stage, and how far when the stage can measure itself (nil when none runs).
    private(set) var exportProgress: ExportProgress?
    /// Whether the running export goes on if the creator leaves Cue (nil when none runs).
    private(set) var exportMode: BackgroundExportMode?
    /// The last export of this take stopped with Cue (closed from the app switcher, or ended by iOS) before it finished.
    private(set) var exportStopped = false

    private var pendingAction: ExportAction?
    /// Share sheets already acted on: a completion heard twice counts and tells once.
    private var handledActivities: Set<UUID> = []

    let takes: TakeLibraryService
    private let quota: UsageQuotaService
    private let tier: () -> MembershipTier
    private let exporter: VideoExporting
    let photos: PhotoSaving
    private let sharing: VideoSharing
    private let ledger: ExportLedgerService
    let editing: TakeEditing
    private let library: ScriptLibraryService
    private let rules: PlatformRulesService
    private let profile: CreatorProfileService
    private let preferences: PreferencesService
    private let drafts: QuickEditDraftStoring
    let toast: ToastService
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

    /// Files the take's edit names that are gone from the iPhone (a photo, a sound, a montage's clip): Save and Share ask first ("Missing
    /// media"), so a video never goes out with a black stretch or a silent gap nobody chose (owner, 01/11/2026). Read on a tap, not per frame.
    var missingMedia: Set<String> { take?.edit?.missingMedia() ?? [] }

    /// Removing what's gone fixes the edit: not when every clip plays a recording that's gone (then only the editor's Replace helps).
    var canRemoveMissingMedia: Bool { take?.edit.map { $0.canDropMedia(missingMedia) } ?? false }

    /// "Remove and export": the take's edit without what's gone, kept as its finished edit (the files can't come back). False, with the
    /// reason said, when the library couldn't be written: nothing is exported then.
    func removeMissingMedia() -> Bool {
        guard let take, let edit = take.edit else { return false }
        let missing = edit.missingMedia()
        guard edit.canDropMedia(missing) else { return false }
        do {
            try takes.applyEdit(edit.withoutMedia(missing), to: take.id)
            return true
        } catch {
            toast.show(String(localized: "Couldn't save · Try again"), kind: .problem)
            return false
        }
    }

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
    var exportLabel: FreeExportLabels.Label { FreeExportLabels.take(left: exportsLeft, declined: exportDeclined, limit: freeExportLimit) }

    /// The free exports with what invites earned.
    var freeExportLimit: Int { quota.exportLimit(for: .free) ?? UsagePolicy.freeExports }

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

    /// "Or invite friends" under Cue Pro: the sheet goes (as "Not now", the take stays ready) and the invites come up.
    func openInvitesFromExportReady() async {
        declineExport()
        try? await Task.sleep(for: proDelay)
        showsInvites = true
    }

    /// How long the sheet takes to leave before the calm Pro comes up (a test sets it to zero).
    @ObservationIgnored var proDelay: Duration = .milliseconds(450)

    var exportsExhausted: Bool { exportsLeft == 0 }

    var isPro: Bool { tier().isPro }

    /// The quality the video is made in: 4K only with Pro, on every way out (Save, Share, Try again, a queue's network, a file made again), so
    /// a plan that ended after 4K was picked exports in 1080p. The take and its edit keep the recording's resolution: only the file is smaller.
    var exportQuality: ExportQuality { quality == .uhd4K && !isPro ? .hd1080 : quality }

    /// A 4K recording without Pro: Export options say it exports in 1080p.
    var exportsFourKRecordingInHD: Bool { take?.resolution == .uhd4K && !isPro }

    /// Only a 4K recording has a quality to choose: a 1080p or 720p one is never made larger, so Export options show its own resolution
    /// and nothing about Pro (a "4K · Pro" there would offer something the file can't have).
    var choosesQuality: Bool { take?.resolution == .uhd4K }

    /// "1080p": what a recording that has no choice exports in.
    var recordedResolutionLabel: String { take?.resolution.label ?? ExportQuality.hd1080.label }

    /// 4K keeps the recording's resolution (a 1080p take isn't upscaled); 1080p scales 4K down.
    /// About 2.2 MB a second at 1080p and 6.5 at 4K (the export's HEVC), for the space check.
    private func estimatedMegabytes(of take: Take) -> Double {
        let perSecond = exportQuality == .uhd4K && take.resolution == .uhd4K ? 6.5 : 2.2
        return max(1, ((take.edit?.editedDuration ?? take.duration) * perSecond).rounded())
    }

    /// The short side the export scales down to (a 4K recording in 1080p); nil keeps the crop's own.
    func outputShortSide(for take: Take) -> CGFloat? {
        take.resolution == .uhd4K && exportQuality == .hd1080 ? ExportQuality.hd1080.shortSide : nil
    }

    func outputResolutionLabel(for take: Take) -> String {
        exportQuality == .uhd4K || take.resolution != .uhd4K ? take.resolution.label : exportQuality.label
    }

    /// The Quality picker. 4K without Pro isn't picked: "4K export is Cue Pro" asks first. Only the 4K file is Pro; the editor's creative tools
    /// never are.
    func setQuality(_ quality: ExportQuality) {
        if quality == .uhd4K && !isPro { offersFourKPro = true } else { pickedQuality = quality }
    }

    /// Pro bought from "4K export is Cue Pro": the video exports in 4K.
    func fourKProPurchased() {
        if isPro { pickedQuality = .uhd4K }
    }

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
        // Used up, and this very video (its edit and settings, not just the take) not out yet: "Your video is ready" before any work, so no
        // "Exporting your video" and no captions made for a video that waits for Pro. Making the file is free; delivering it is not.
        guard action == .render || quota.canExport(tier: tier()) || costsNothing(take, edit: take.edit, burnsInCaptions: burnsInCaptions) else {
            askForPro(action)
            return
        }
        runningAction = action
        phase = .preparing
        exportProgress = .preparing
        exportFailure = nil
        dismissStoppedExport()
        // Marked while it runs: still marked when Cue opens again means it stopped with Cue.
        preferences.exportsInFlight.insert(take.id)
        // The file and where it goes, as one piece of work iOS can let run outside Cue (leaving Cue is not cancelling).
        let job = Task { @MainActor in
            try await background.run(
                title: String(localized: "Exporting your video"), subtitle: take.label, started: { self.exportMode = $0 }, work: { report in
                guard let operation = try await self.prepareOperation(for: take, action: action, continuing: operationID, progress: { update in
                    // A stage never goes back: a late report of an earlier one (the motion analysis hops to the main actor) is dropped.
                    if let shown = self.exportProgress, update.stage < shown.stage { return }
                    self.exportProgress = update
                    // iOS's Live Activity hears the frames being written: the stage every export has, and measures.
                    if update.stage == .rendering, let fraction = update.fraction { report(fraction) }
                }) else {
                    return false
                }
                self.preparedOperation = operation.id
                // Words in the system's face (`ExportedFileRecord`): the message after sending says so, as the cover does.
                let fallback = ExportedFileRecord.read(at: self.ledger.fileURL(of: operation))?.fontFallback
                self.fontNotice = fallback.map { _ in String(localized: "Some words use the system font") }
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

    /// "Your video is ready" asks before the export goes on (the free exports are used up).
    private func askForPro(_ action: ExportAction) {
        pendingAction = action
        exportDeclined = false
        showsExportReady = true
    }

    /// The counted export of the "Share to universe" queue this take is in: an edit made inside it is the same export and costs nothing more.
    private func inheritedCount(for take: Take) -> UUID? {
        queueOperation().flatMap { ledger.operation(id: $0) }.flatMap { $0.takeID == take.id && $0.isCounted ? $0.id : nil }
    }

    /// Exporting `edit` now costs no free export, read before any work: this very video (the take, the edit, the settings) already left Cue, or
    /// it is an edit inside a queue that already counted. Not "the take": another edit of an exported take is another video (owner, 06/11/2026:
    /// correcting a video costs an export). An edit whose captions are still to be made can't have left (they would be in the take).
    private func costsNothing(_ take: Take, edit: TakeEdit?, burnsInCaptions: Bool) -> Bool {
        if inheritedCount(for: take) != nil { return true }
        let (prepared, needsCaptions) = baseEditForExport(take, edit: edit, burnsInCaptions: burnsInCaptions)
        guard !needsCaptions else { return false }
        let options = exportOptions(for: take, edit: prepared, burnsInCaptions: burnsInCaptions)
        return ledger.isCounted(fingerprint: ExportFingerprint.make(takeID: take.id, source: takes.videoURL(for: take), options: options))
    }

    private func exportOptions(for take: Take, edit: TakeEdit?, burnsInCaptions: Bool) -> ExportOptions {
        ExportOptions(aspect: take.outputAspect, edit: edit, burnsInCaptions: burnsInCaptions, shortSide: outputShortSide(for: take))
    }

    /// The line on the editor's "Is it ready to post?" (owner, 06/11/2026: the last free export told when it is useful, with no new flow):
    /// "LAST FREE EXPORT" with one left, "0 OF 3 LEFT · EXPORT WITH PRO" with none. Nothing on Pro, with more left, or when sharing `edit`
    /// costs nothing (the same video already out).
    func doneExportNote(for edit: TakeEdit) -> FreeExportLabels.Label? {
        guard let left = exportsLeft, left <= 1, let take else { return nil }
        guard !costsNothing(take, edit: edit, burnsInCaptions: edit.showsCaptions) else { return nil }
        return FreeExportLabels.meter(left: left, limit: freeExportLimit)
    }

    /// The file for this export: the one already made for the same edit and settings, else a new render. Nil when the
    /// free exports are used up (the paywall is open). A video already counted never needs the quota again, its file there or made again.
    private func prepareOperation(
        for take: Take, action: ExportAction, continuing operationID: UUID?, progress: @escaping @MainActor (ExportProgress) -> Void
    ) async throws -> ExportOperation? {
        let options = exportOptions(for: take, edit: await editForExport(take), burnsInCaptions: burnsInCaptions)
        let source = takes.videoURL(for: take)
        let fingerprint = ExportFingerprint.make(takeID: take.id, source: source, options: options)
        // The same video is reused only when it would be drawn the same now (the fonts, the media, this Cue): a file whose record says
        // otherwise, or has none, is made again (for the free exports it is still the same video).
        let stamp = ExportRenderStamp.current(edit: options.edit)
        let reusable = ledger.reusableOperation(fingerprint: fingerprint).flatMap { operation in
            ExportedFileRecord.read(at: ledger.fileURL(of: operation))?.renderStamp == stamp ? operation : nil
        }
        let continued = operationID.flatMap { ledger.operation(id: $0) }.flatMap { $0.fingerprint == fingerprint ? $0 : nil }
        // An edit made inside a queue that already counted its export is the same export: it costs nothing more.
        let inherited = inheritedCount(for: take)
        // Asked before the work too (`export`); asked again here for captions made just now, which make another video.
        if action != .render, !ledger.isCounted(fingerprint: fingerprint), inherited == nil, !quota.canExport(tier: tier()) {
            askForPro(action)
            return nil
        }
        if let reusable { return reusable }
        // A full iPhone is told now, with how much to free, never after minutes of work.
        if let missing = StorageSpace.shortfall(forExportOf: estimatedMegabytes(of: take), available: freeSpace()) {
            throw ExportPreflightError.notEnoughSpace(megabytes: missing)
        }
        let result = try await exporter.export(videoAt: source, options: options, progress: progress)
        // Named after the script and the take, for Files, AirDrop and a computer.
        let url = ExportFileName.rename(result.url, title: take.scriptTitle, takeNumber: take.number)
        ExportedFileRecord(renderStamp: ExportRenderStamp.drawn(edit: options.edit, result: result), fontFallback: result.fontFallback).write(to: url)
        if let continued {
            // The same export, its file made again (the system cleared the first, or it was drawn differently): not a second export. An
            // old file still there goes, unless the share sheet shows it.
            if ledger.fileExists(for: continued), activity?.operationID != continued.id { ledger.releaseFile(of: continued.id) }
            ledger.replaceFile(of: continued.id, with: url)
            return ledger.operation(id: continued.id)
        }
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
            announce(ExportMessages.savedForPosting(on: destination.platform.label, left: exportsLeft, limit: freeExportLimit))
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
            announce(ExportMessages.shared(with: label, left: exportsLeft, limit: freeExportLimit))
        case .pending:
            showsShareSheet = false
        case .opened:
            showsShareSheet = false
            if route.needsPhotosCopy {
                // Saved, and the app is open for the creator to pick it.
                celebration = .readyToTravel(exported(take, operation: operation))
                announce(ExportMessages.ready(on: destination.platform.label, left: exportsLeft, limit: freeExportLimit))
            } else {
                // Instagram: the video left Cue (on the pasteboard, with the composer open), which counts. Whether it read it, or
                // the creator posts it, Instagram doesn't say.
                recordDelivery(.pasteboardHandoff, operation: operation, take: take)
                phase = .delivering(destination)
                toast.show(ExportMessages.opened(label, left: exportsLeft, limit: freeExportLimit))
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
                announce(ExportMessages.shared(with: destination.platform.label, left: exportsLeft, limit: freeExportLimit))
            } else {
                announce(ExportMessages.shared(with: nil, left: exportsLeft, limit: freeExportLimit))
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
        let url = ledger.fileURL(of: operation)
        let fontFallback = ExportedFileRecord.read(at: url)?.fontFallback
        return ExportedVideo(
            operationID: operation.id, take: take, url: url,
            formatLabel: "\(outputSizeLabel(for: take.edit).uppercased()) · \(take.outputAspect.label)",
            hasCaptions: burnsInCaptions && captionNotice == nil, missingCaptions: burnsInCaptions ? captionNotice : nil,
            exportsLeft: quota.exportsLeft(for: currentTier), platform: take.platform, fontFallback: fontFallback
        )
    }

    /// "Ready to travel" → "Share to TikTok": the same exported file, so a video that was saved is not counted again.
    func send(_ video: ExportedVideo, to destination: ShareDestination) async {
        await export(.share(destination), continuing: video.operationID)
    }

    /// Captions to burn in come from the edit; a take never captioned gets them now from its voice
    /// (cached as source data). When none can be made, the video exports without them and `captionNotice` says
    /// why: nothing is ever spread over the take in their place.
    private func editForExport(_ take: Take) async -> TakeEdit? {
        captionNotice = nil
        let (base, needsCaptions) = baseEditForExport(take, edit: take.edit, burnsInCaptions: burnsInCaptions)
        guard needsCaptions, var edit = base else { return base }
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
        return edit
    }

    /// The edit as this export burns it, before any captions are made; `needsCaptions` when they are asked for and the take has none yet (then
    /// they come from its voice, `editForExport`).
    private func baseEditForExport(_ take: Take, edit source: TakeEdit?, burnsInCaptions: Bool) -> (edit: TakeEdit?, needsCaptions: Bool) {
        guard burnsInCaptions else { return (source, false) }
        var edit = source ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        if source == nil {
            edit.captionCollection?.safeMargins = CaptionSafeArea.margins(for: take, aspect: edit.aspect)
            // Captions on a never-edited take don't opt it into the editor's default voice effect.
            edit.voiceEnhancement = .off
            edit.enhancesVoice = false
        }
        CaptionSafeArea.repairMargins(of: &edit, for: take)
        edit.showsCaptions = true
        edit.captionDisplay = edit.captionTranslations.contains { $0.language == exportCaptionDisplay.language } ? exportCaptionDisplay : .original
        return (edit, edit.captions.isEmpty)
    }

    /// A finished export's message, with why captions are missing when they were asked for. Read after the celebration took what the
    /// video holds (`exported`): before, "Ready to travel" said CAPTIONS ON for a video without them.
    private func announce(_ message: String) {
        toast.show(([message] + [captionNotice, fontNotice].compactMap { $0 }).joined(separator: " · "))
        captionNotice = nil
        fontNotice = nil
    }
}
