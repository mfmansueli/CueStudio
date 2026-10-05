//
//  QuickEditExportModel.swift
//  Cue Studio
//

import Foundation
import UIKit

/// Export from the editor: the edit as it is now, at 720p, 1080p or 4K and 30 or 60 fps (never
/// more than the recording has), with its captions and texts burned in, saved to Photos with its
/// cover. The free plan's exports count here like everywhere (5, then the paywall, no watermark): once, when the video is
/// saved to Photos (`ExportLedgerService`), so sharing the finished file afterwards never counts again.
/// Progress is the export's own; leaving Cue while it runs asks the system for time to finish.
@MainActor
@Observable
final class QuickEditExportModel {
    enum Phase: Equatable {
        case setup
        /// 0 to 1.
        case exporting(Double)
        case done(URL)
        case failed(String)
    }

    private(set) var phase: Phase = .setup
    var resolution: VideoResolution
    var frameRate: Int
    var paywall: PaywallContext?
    /// The finished video, for the share sheet.
    var activity: ActivityShare?

    private let take: Take
    private let edit: () -> TakeEdit
    private let videoURL: URL
    private let takes: TakeLibraryService
    private let quota: UsageQuotaService
    private let tier: () -> MembershipTier
    private let exporter: VideoExporting
    private let photos: PhotoSaving
    private let editing: TakeEditing
    private let ledger: ExportLedgerService
    private var pendsAfterPurchase = false
    private var operationID: UUID?
    private var handledActivities: Set<UUID> = []

    init(
        take: Take, videoURL: URL, edit: @escaping () -> TakeEdit, takes: TakeLibraryService, quota: UsageQuotaService,
        tier: @escaping () -> MembershipTier, exporter: VideoExporting, photos: PhotoSaving, editing: TakeEditing,
        ledger: ExportLedgerService
    ) {
        self.take = take
        self.videoURL = videoURL
        self.edit = edit
        self.takes = takes
        self.quota = quota
        self.tier = tier
        self.exporter = exporter
        self.photos = photos
        self.editing = editing
        self.ledger = ledger
        resolution = take.resolution == .hd720 ? .hd720 : .hd1080
        frameRate = Self.baseFrameRate(of: take)
    }

    // MARK: - Choices

    /// 4K only from a 4K recording, 1080p not from a 720p one: nothing is upscaled.
    func canExport(_ resolution: VideoResolution) -> Bool {
        Self.rank(resolution) <= Self.rank(take.resolution)
    }

    /// 30 (or 24, as recorded) and 60, which needs a recording at 50 fps or more.
    var frameRates: [Int] { [Self.baseFrameRate(of: take), 60] }

    func canExport(frameRate: Int) -> Bool {
        frameRate <= max(Self.baseFrameRate(of: take), take.frameRate.rawValue)
    }

    /// Why a choice is off: "4K needs a take recorded in 4K."
    var limitNote: String? {
        var notes: [String] = []
        if !canExport(.uhd4K) { notes.append(String(localized: "4K needs a take recorded in 4K.")) }
        if !canExport(frameRate: 60) { notes.append(String(localized: "60 fps needs a take recorded at 60 fps.")) }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    /// "Take 3 · 00:21.6"
    var title: String {
        "\(take.label) · \(DurationText.editor(edit().editedDuration))"
    }

    /// "9:16 · captions and text burned in"
    var summary: String {
        let current = edit()
        let burned = (current.showsCaptions && !current.editedCaptions.isEmpty) || !current.texts.isEmpty
        let aspect = current.aspect.label
        return burned ? String(localized: "\(aspect) · captions and text burned in") : aspect
    }

    /// "≈ 48 MB": about 1.1 MB a second at 720p, 2.2 at 1080p and 6.5 at 4K, half again at 60 fps.
    var estimatedSize: String {
        let perSecond = switch resolution {
        case .hd720: 1.1
        case .hd1080: 2.2
        case .uhd4K: 6.5
        }
        let megabytes = max(1, (edit().editedDuration * perSecond * (frameRate >= 50 ? 1.5 : 1)).rounded())
        return String(localized: "≈ \(Int(megabytes)) MB")
    }

    /// "4 of 5 free exports left"; nil on Pro.
    var exportsLeftLabel: String? {
        guard let left = quota.exportsLeft(for: tier()) else { return nil }
        return String(localized: "\(left) of \(UsagePolicy.freeExports) free exports left")
    }

    var isExporting: Bool {
        if case .exporting = phase { return true }
        return false
    }

    // MARK: - Exporting

    /// Exports, or opens the paywall when the free exports are used up (and goes on after). The video is saved to Photos and
    /// counted there; a retry after a failure reuses the file already rendered for the same edit and settings.
    func start() async {
        guard !isExporting else { return }
        let currentTier = tier()
        guard quota.canExport(tier: currentTier) || ledger.hasCountedOperation(forTake: take.id) else {
            pendsAfterPurchase = true
            paywall = .export
            return
        }
        phase = .exporting(0)
        let background = UIApplication.shared.beginBackgroundTask(withName: "Cue export")
        defer { UIApplication.shared.endBackgroundTask(background) }
        let current = edit()
        let options = ExportOptions(
            aspect: current.aspect, edit: current, burnsInCaptions: false,
            shortSide: CGFloat(resolution.landscapeHeight), frameRate: Double(frameRate)
        )
        let fingerprint = ExportFingerprint.make(takeID: take.id, source: videoURL, options: options)
        do {
            let operation: ExportOperation
            if let reusable = ledger.reusableOperation(fingerprint: fingerprint) {
                guard reusable.isCounted || quota.canExport(tier: currentTier) else {
                    phase = .setup
                    pendsAfterPurchase = true
                    paywall = .export
                    return
                }
                operation = reusable
            } else {
                guard quota.canExport(tier: currentTier) else {
                    phase = .setup
                    pendsAfterPurchase = true
                    paywall = .export
                    return
                }
                let url = try await exporter.export(videoAt: videoURL, options: options) { [weak self] fraction in
                    guard let self, self.isExporting else { return }
                    self.phase = .exporting(min(max(fraction, 0), 1))
                }
                operation = ledger.begin(takeID: take.id, fingerprint: fingerprint, file: url)
            }
            operationID = operation.id
            let file = ledger.fileURL(of: operation)
            let assetID = try await photos.saveVideo(at: file)
            ledger.recordDelivery(.photoLibrary(assetID: assetID), for: operation.id, tier: currentTier)
            takes.markExported(take.id)
            await saveCover(of: current)
            phase = .done(file)
        } catch {
            phase = .failed(UIApplication.shared.applicationState == .active
                ? error.localizedDescription
                : String(localized: "The export stopped when Cue left the screen. Keep Cue open and try again."))
        }
    }

    /// Opens the system share sheet for the finished video.
    func share(_ url: URL) {
        guard let operationID else { return }
        activity = ActivityShare(operationID: operationID, url: url, destination: nil)
    }

    /// How the share sheet ended. The video was counted when it was saved, so this only keeps the record: the same operation,
    /// delivered again, is never a second export.
    func activityFinished(_ result: ActivityResult, for share: ActivityShare) {
        activity = nil
        guard handledActivities.insert(share.id).inserted, case .completed(let type) = result else { return }
        ledger.recordDelivery(.activity(type: type), for: share.operationID, tier: tier())
    }

    /// The editor's export closed with nothing in flight: the rendered file goes.
    func leave() {
        guard !isExporting, activity == nil, let operationID else { return }
        ledger.releaseFile(of: operationID)
    }

    /// Pro (or its trial) is on: the export that opened the paywall goes on.
    func continueAfterPurchase() async {
        guard pendsAfterPurchase else { return }
        pendsAfterPurchase = false
        await start()
    }

    /// Back to the choices after a failure.
    func retry() {
        phase = .setup
    }

    /// The cover goes to Photos with the video; a cover that can't be drawn doesn't stop it.
    private func saveCover(of edit: TakeEdit) async {
        guard let cover = edit.cover, let data = await editing.coverImage(cover, forVideoAt: videoURL, edit: edit) else { return }
        let url = URL.temporaryDirectory.appending(path: "Cue-cover-\(UUID().uuidString.prefix(8)).jpg")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return }
        try? await photos.saveImage(at: url)
    }

    // MARK: - Private

    private static func rank(_ resolution: VideoResolution) -> Int {
        VideoResolution.allCases.firstIndex(of: resolution) ?? 0
    }

    /// The lower frame rate offered: 24 when recorded at 24, else 30.
    private static func baseFrameRate(of take: Take) -> Int {
        take.frameRate == .fps24 ? 24 : 30
    }
}
