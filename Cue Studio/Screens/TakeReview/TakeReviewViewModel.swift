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
    /// "Share to".
    var showsShareSheet = false
    var burnsInCaptions = false
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
    private let toast: ToastService

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
        toast: ToastService
    ) {
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
        self.toast = toast
    }

    // MARK: - Reading

    var take: Take? { takes.take(id: takeID) }

    /// This take and the others of the same script, by number ("Your takes · 3").
    var siblings: [Take] { take.map(takes.siblings(of:)) ?? [] }

    /// "Today · 9:25 AM · TikTok · 9:16 · 1080p"
    var metaLine: String {
        guard let take else { return "" }
        let when = take.recordedAt.formatted(.relative(presentation: .named))
        let platform = take.platform?.label ?? String(localized: "Freestyle")
        return "\(when) · \(platform) · \(take.aspect.label) · \(take.resolution.label)"
    }

    var videoURL: URL? { take.map(takes.videoURL(for:)) }

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

    /// The complete take closest to the script's timing, preferring the platform's ideal range. The
    /// review switches to it; the creator still keeps it with ☆.
    func suggestBest() -> Take? {
        guard let take, let script = library.script(id: take.scriptID) else { return nil }
        let preset = rules.preset(for: take.platform ?? script.platform, monetizationGoals: profile.profile.monetizationGoals)
        let expected = ReadTime.seconds(for: script.text, speed: preferences.prompter.speed)
        guard let best = BestTakeSuggester.suggestion(among: siblings, expectedDuration: expected, idealRange: preset.idealRange) else {
            return nil
        }
        toast.show(String(localized: "\(best.label) looks best — tap ☆ to keep it"))
        return best
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
                toast.show(savedMessage(tier: currentTier, withCover: withCover))
            case .share(nil):
                shareURL = url
            case .share(let destination?):
                // The platform's app picks the video (and the cover) from Photos.
                try await photos.saveVideo(at: url)
                _ = try? await saveCoverIfChosen()
                if await apps.open(destination) {
                    showsShareSheet = false
                    toast.show(readyMessage(for: destination, tier: currentTier))
                } else {
                    shareURL = url
                }
            }
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    /// Captions to burn in come from the edit; a take never captioned gets them now (not saved).
    private func editForExport(_ take: Take) async -> TakeEdit? {
        guard burnsInCaptions else { return take.edit }
        var edit = take.edit ?? TakeEdit(sourceDuration: take.duration, aspect: take.aspect)
        edit.showsCaptions = true
        if edit.captions.isEmpty {
            let script = library.script(id: take.scriptID)?.text ?? ""
            edit.captions = await editing.captions(forVideoAt: takes.videoURL(for: take), script: script, duration: edit.sourceDuration)
        }
        return edit
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
