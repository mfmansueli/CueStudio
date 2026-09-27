//
//  TakeReviewViewModel.swift
//  Cue Studio
//

import Foundation

/// Save and share a take. The free plan exports clean up to its limit, then offers Pro or a
/// watermarked copy.
@MainActor
@Observable
final class TakeReviewViewModel {
    enum ExportAction { case save, share }

    let takeID: UUID
    private(set) var runningAction: ExportAction?
    /// Set when an export is ready for the share sheet.
    var shareURL: URL?
    var paywall: PaywallContext?

    private var pendingAction: ExportAction?

    private let takes: TakeLibraryService
    private let quota: UsageQuotaService
    private let tier: () -> MembershipTier
    private let exporter: VideoExporting
    private let photos: PhotoSaving
    private let toast: ToastService

    init(
        takeID: UUID,
        takes: TakeLibraryService,
        quota: UsageQuotaService,
        tier: @escaping () -> MembershipTier,
        exporter: VideoExporting,
        photos: PhotoSaving,
        toast: ToastService
    ) {
        self.takeID = takeID
        self.takes = takes
        self.quota = quota
        self.tier = tier
        self.exporter = exporter
        self.photos = photos
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

    func share() async {
        await export(.share, allowWatermark: false)
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
                options: ExportOptions(aspect: take.outputAspect, watermark: !clean, edit: take.edit)
            )
            if clean {
                quota.recordCleanExport(tier: currentTier)
            }
            takes.markExported(take.id)
            switch action {
            case .save:
                try await photos.saveVideo(at: url)
                toast.show(savedMessage(clean: clean, tier: currentTier))
            case .share:
                shareURL = url
                if clean, let left = quota.cleanExportsLeft(for: currentTier) {
                    toast.show(String(localized: "Ready to post · \(left) of \(UsagePolicy.freeCleanExports) clean exports left"))
                }
            }
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    private func savedMessage(clean: Bool, tier: MembershipTier) -> String {
        guard clean else { return String(localized: "Saved with watermark") }
        if let left = quota.cleanExportsLeft(for: tier) {
            return String(localized: "Saved to Photos · \(left) of \(UsagePolicy.freeCleanExports) clean exports left")
        }
        return String(localized: "Saved to Photos")
    }
}
