//
//  TakeReviewViewModel.swift
//  Cue Studio
//

import Foundation

/// Save a take, or share it to a platform ("Share to"). Every feature is free; the free plan
/// includes five exports, then exporting asks for Cue Pro (7 days free). Takes are never locked.
@MainActor
@Observable
final class TakeReviewViewModel {
    enum ExportAction: Equatable {
        case save
        /// A platform, or nil for "More" (the system share sheet).
        case share(ShareDestination?)
    }

    let takeID: UUID
    private(set) var runningAction: ExportAction?
    /// Set when an export is ready for the system share sheet.
    var shareURL: URL?
    var paywall: PaywallContext?
    /// "Ready to travel" after a save, "On its way" once a platform's app is open.
    var celebration: ExportCelebration?
    /// "Share to".
    var showsShareSheet = false
    var burnsInCaptions = false
    /// Which captions this export burns in: the original, a translation or both (one export per
    /// language).
    var exportCaptionDisplay: CaptionDisplay = .original
    /// Why the video being exported has no captions although they were asked for.
    @ObservationIgnored private var captionNotice: String?
    private(set) var quality: ExportQuality = .hd1080

    private var pendingAction: ExportAction?

    private let takes: TakeLibraryService
    private let quota: UsageQuotaService
    private let tier: () -> MembershipTier
    private let exporter: VideoExporting
    private let photos: PhotoSaving
    private let apps: ExternalAppOpening
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
        apps: ExternalAppOpening,
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
        self.apps = apps
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

    /// Free plan only: "3 of 5 free exports", or that the next export starts the trial.
    var exportNotice: String? {
        guard let left = exportsLeft else { return nil }
        return left > 0
            ? String(localized: "\(left) of \(UsagePolicy.freeExports) free exports")
            : String(localized: "Free exports used — 7 days free to keep exporting")
    }

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

    /// A cover was chosen in Quick edit: it's saved to Photos with every export.
    var hasCover: Bool { take?.edit?.cover != nil }

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
        takes.delete(take.id)
        toast.show(String(localized: "\(take.label) deleted"))
        return rest.last
    }

    func save() async {
        await export(.save)
    }

    /// Saves the cover to Photos on its own. A picture, not a video: it never counts as an export.
    func saveCover() async {
        guard runningAction == nil else { return }
        do {
            if try await saveCoverIfChosen() {
                toast.show(String(localized: "Cover saved to Photos"))
            }
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    /// A platform: export, save to Photos and open its app to post (the share sheet when the app
    /// isn't there). Nil is "More": the system share sheet.
    func share(to destination: ShareDestination?) async {
        await export(.share(destination))
    }

    /// Continues the export that opened the paywall, now that Pro (or its trial) is on.
    func continueAfterPurchase() async {
        guard let action = pendingAction else { return }
        pendingAction = nil
        await export(action)
    }

    private func export(_ action: ExportAction) async {
        guard let take, runningAction == nil else { return }
        let currentTier = tier()
        guard quota.canExport(tier: currentTier) else {
            pendingAction = action
            paywall = .export
            return
        }
        runningAction = action
        defer { runningAction = nil }
        do {
            let url = try await exporter.export(
                videoAt: takes.videoURL(for: take),
                options: ExportOptions(
                    aspect: take.outputAspect, edit: await editForExport(take),
                    burnsInCaptions: burnsInCaptions, shortSide: outputShortSide(for: take)
                )
            )
            quota.recordExport(tier: currentTier)
            takes.markExported(take.id)
            switch action {
            case .save:
                try await photos.saveVideo(at: url)
                let withCover = (try? await saveCoverIfChosen()) ?? false
                showsShareSheet = false
                let video = exported(take, url: url, tier: currentTier)
                announce(savedMessage(tier: currentTier, withCover: withCover))
                celebration = .readyToTravel(video)
            case .share(nil):
                shareURL = url
            case .share(let destination?):
                // The platform's app picks the video (and the cover) from Photos.
                try await photos.saveVideo(at: url)
                _ = try? await saveCoverIfChosen()
                if await apps.open(destination) {
                    showsShareSheet = false
                    let video = exported(take, url: url, tier: currentTier)
                    announce(readyMessage(for: destination, tier: currentTier))
                    celebration = .sentOff(video, destination)
                } else {
                    shareURL = url
                }
            }
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    private func exported(_ take: Take, url: URL, tier: MembershipTier) -> ExportedVideo {
        ExportedVideo(
            take: take, url: url, formatLabel: "\(outputResolutionLabel(for: take).uppercased()) · \(take.outputAspect.label)",
            hasCaptions: burnsInCaptions && captionNotice == nil, exportsLeft: quota.exportsLeft(for: tier), platform: take.platform
        )
    }

    /// "Ready to travel" → "Share to TikTok": the video is already in Photos, so its app opens without exporting
    /// again (the system share sheet when the app isn't there).
    func send(_ video: ExportedVideo, to destination: ShareDestination) async {
        if await apps.open(destination) {
            celebration = .sentOff(video, destination)
        } else {
            shareURL = video.url
        }
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
