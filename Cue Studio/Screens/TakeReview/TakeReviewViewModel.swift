//
//  TakeReviewViewModel.swift
//  Cue Studio
//

import Foundation

/// Save a take, or share it to a platform ("Share to"). The free plan exports clean up to its limit,
/// then offers Pro or a watermarked copy.
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
    var cleanExportsLeft: Int? { quota.cleanExportsLeft(for: tier()) }

    /// Free plan only: how many clean exports are left, or that the next one gets a watermark.
    var exportNotice: String? {
        guard let left = cleanExportsLeft else { return nil }
        return left > 0
            ? String(localized: "\(left) of \(UsagePolicy.freeCleanExports) clean exports left")
            : String(localized: "Free exports used — saves with a watermark")
    }

    var exportsExhausted: Bool { cleanExportsLeft == 0 }

    var isPro: Bool { tier().isPro }

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

    /// 4K is part of Pro; on the free plan it opens the paywall.
    func setQuality(_ quality: ExportQuality) {
        if quality.isPro && !isPro {
            paywall = .export
            return
        }
        self.quality = quality
    }

    // MARK: - Actions

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
        await export(.save, allowWatermark: false)
    }

    /// A platform: export, save to Photos and open its app to post (the share sheet when the app
    /// isn't there). Nil is "More": the system share sheet.
    func share(to destination: ShareDestination?) async {
        await export(.share(destination), allowWatermark: false)
    }

    /// "Save with watermark instead" on the paywall.
    func exportWithWatermark() async {
        guard let action = pendingAction else { return }
        pendingAction = nil
        await export(action, allowWatermark: true)
    }

    /// Continues the export that opened the paywall, now clean.
    func continueAfterPurchase() async {
        guard let action = pendingAction else { return }
        pendingAction = nil
        await export(action, allowWatermark: false)
    }

    private func export(_ action: ExportAction, allowWatermark: Bool) async {
        guard let take, runningAction == nil else { return }
        let currentTier = tier()
        let clean = quota.canExportClean(tier: currentTier)
        if !clean && !allowWatermark {
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
                    aspect: take.outputAspect, watermark: !clean, edit: await editForExport(take),
                    burnsInCaptions: burnsInCaptions, shortSide: outputShortSide(for: take)
                )
            )
            if clean {
                quota.recordCleanExport(tier: currentTier)
            }
            takes.markExported(take.id)
            switch action {
            case .save:
                try await photos.saveVideo(at: url)
                showsShareSheet = false
                toast.show(savedMessage(clean: clean, tier: currentTier))
            case .share(nil):
                shareURL = url
            case .share(let destination?):
                // The platform's app picks the video from Photos.
                try await photos.saveVideo(at: url)
                if await apps.open(destination) {
                    showsShareSheet = false
                    toast.show(readyMessage(for: destination, clean: clean, tier: currentTier))
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

    private func readyMessage(for destination: ShareDestination, clean: Bool, tier: MembershipTier) -> String {
        let ready = String(localized: "Ready to post on \(destination.platform.label)")
        guard clean, let left = quota.cleanExportsLeft(for: tier) else { return ready }
        return ready + " · " + String(localized: "\(left) of \(UsagePolicy.freeCleanExports) clean left")
    }

    private func savedMessage(clean: Bool, tier: MembershipTier) -> String {
        guard clean else { return String(localized: "Saved with watermark") }
        if let left = quota.cleanExportsLeft(for: tier) {
            return String(localized: "Saved to Photos · \(left) of \(UsagePolicy.freeCleanExports) clean exports left")
        }
        return String(localized: "Saved to Photos")
    }
}
