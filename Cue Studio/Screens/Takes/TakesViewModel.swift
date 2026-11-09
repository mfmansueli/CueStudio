//
//  TakesViewModel.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// The Takes library: videos (takes grouped by script, each at the stage its takes put it in)
/// filtered by platform and by the stage picked in the pipeline, by day.
@MainActor
@Observable
final class TakesViewModel {
    var filter = TakeLibraryFilter()
    /// Video whose takes are about to be deleted, for the confirmation.
    var videoToDelete: TakeVideo?
    /// Bumped when the tab shows again: an edit left open in the editor changes a stage without
    /// touching the takes.
    private(set) var editRevision = 0
    /// "{YEAR} · SHARED ✕": Takes opened from "Your universe" (a planet's "See in Takes ›", a theme): only the videos shared in that year, of that
    /// platform or theme.
    private(set) var scope: TakesRequest?
    @ObservationIgnored private var scopeTakeIDs: Set<UUID> = []
    @ObservationIgnored private var scopeSetPlatform = false

    private let takes: TakeLibraryService
    private let library: ScriptLibraryService
    private let drafts: QuickEditDraftStoring
    private let presentation: PresentationService
    private let toast: ToastService
    private let now: () -> Date
    private let importer: TakeVideoImporting
    /// A video from Photos is being copied in to edit.
    private(set) var isImporting = false
    /// The video whose card carries the first star, once Takes lit it (D4): it stays there until Cue closes.
    private(set) var firstStarVideoID: String?
    private let onboarding: OnboardingService?
    private let guidance: GuidanceGate?

    init(
        takes: TakeLibraryService, library: ScriptLibraryService, drafts: QuickEditDraftStoring,
        presentation: PresentationService, toast: ToastService, importer: TakeVideoImporting? = nil,
        onboarding: OnboardingService? = nil, guidance: GuidanceGate? = nil, now: @escaping () -> Date = Date.init
    ) {
        self.takes = takes
        self.library = library
        self.drafts = drafts
        self.presentation = presentation
        self.toast = toast
        self.importer = importer ?? TakeVideoImporter()
        self.onboarding = onboarding
        self.guidance = guidance
        self.now = now
    }

    // MARK: - Importing

    /// "Import video": a video from Photos becomes a video of its own here, marked imported (never a take of the teleprompter),
    /// and opens straight in the editor. One that can't come in leaves nothing of its copy behind, and says the iPhone is full only when that
    /// is what stopped it.
    func importVideo(_ item: PhotosPickerItem) async {
        guard !isImporting else { return }
        isImporting = true
        // The ring turns while the video comes in; the review it opens in (or why it couldn't) ends it.
        let work = toast.showWorking(String(localized: "Importing…"))
        defer {
            isImporting = false
            toast.endWorking(work)
        }
        do {
            let video = try await importer.importVideo(item) { _ in }
            let take: Take
            do {
                take = try takes.importVideo(
                    fileAt: video.url, duration: video.duration, uprightSize: video.uprightSize, frameRate: video.frameRate
                )
            } catch {
                // The library couldn't take it in (given back where it was copied): this attempt's copy goes.
                EditMediaFiles.discardPartial(video.url)
                throw error
            }
            refresh()
            presentation.openReview(of: take, then: .edit)
        } catch is CancellationError {
            // Stopped: nothing to say.
        } catch {
            let message = EditorErrorMessage.isOutOfSpace(error) ? EditorErrorMessage.outOfSpace : String(localized: "Can't import this video")
            toast.showResult(message, kind: .problem, ending: work)
        }
    }

    // MARK: - Reading

    /// Every video, newest first, with its stage.
    var allVideos: [TakeVideo] {
        _ = editRevision
        return TakeLibraryFilter.videos(
            from: takes.takes,
            scriptPlatform: { [library] in library.script(id: $0)?.platform },
            hasDraft: { [drafts] in drafts.hasDraft(for: $0) }
        )
    }

    /// The header: how many at each stage, and the next step, for the platform picked.
    var pipeline: TakePipeline {
        TakePipeline(videos: filter.onPlatform(allVideos))
    }

    var sections: [TakeLibraryFilter.Section] {
        filter.sections(of: scopedVideos, now: now())
    }

    /// The videos with a take that was shared inside the scope (all of them without one).
    private var scopedVideos: [TakeVideo] {
        guard scope != nil else { return allVideos }
        return allVideos.filter { video in video.takes.contains { scopeTakeIDs.contains($0.id) } }
    }

    var isEmpty: Bool { takes.takes.isEmpty }

    /// The platform chips: All, then each platform a video was made for, none for a network with no videos (the owner, 30/10/2026); the
    /// chosen one keeps its chip while it is chosen.
    var platformOptions: [Platform?] {
        let used = Set(allVideos.compactMap(\.platform))
        return [nil] + Platform.allCases.filter { used.contains($0) || filter.platform == $0 }
    }

    /// "Today · 9:12 AM", "Sep 18 · 4:10 PM"
    func whenLabel(for take: Take) -> String {
        let time = take.recordedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .interface))
        switch TakeDay(date: take.recordedAt, now: now(), calendar: .current) {
        case .today: return String(localized: "Today · \(time)")
        case .yesterday: return String(localized: "Yesterday · \(time)")
        case .earlier: return take.recordedAt.formatted(.dateTime.month(.abbreviated).day().locale(.interface)) + " · " + time
        }
    }

    // MARK: - The first star

    /// The first star waiting for Takes (its review was left without a confirmed post) lights on that video's card, when the card is in the
    /// list on screen: it counts as told then, and as a celebration for the gate (`GuidanceGate`). Returns whether it lit now. A take deleted
    /// since lets the star wait, untold, for the next review left.
    @discardableResult
    func lightFirstStar() -> Bool {
        guard firstStarVideoID == nil, let onboarding, let takeID = onboarding.firstStarWaitingTake else { return false }
        guard takes.takes.contains(where: { $0.id == takeID }) else {
            onboarding.dropWaitingFirstStar()
            return false
        }
        guard let video = sections.flatMap(\.videos).first(where: { video in video.takes.contains { $0.id == takeID } }) else { return false }
        firstStarVideoID = video.id
        onboarding.markFirstStarShown()
        guidance?.celebrated()
        return true
    }

    // MARK: - Actions

    func refresh() {
        editRevision += 1
    }

    /// A request from "Your universe" or a script's "×3 ›": the chip goes first, the platform it names is picked, and the stage filter is cleared.
    func apply(_ request: TakesRequest, sharedVideos: [UniverseVideo]) {
        scope = request
        if let script = request.script {
            scopeTakeIDs = Set(takes.takes.filter { $0.scriptID == script.id }.map(\.id))
        } else {
            scopeTakeIDs = request.matching(sharedVideos)
        }
        scopeSetPlatform = request.platform != nil
        if let platform = request.platform { filter.platform = platform }
        filter.stage = nil
    }

    /// ✕ on the chip: every video again (and every platform, when the scope had picked one).
    func clearScope() {
        scope = nil
        scopeTakeIDs = []
        if scopeSetPlatform { filter.platform = nil }
        scopeSetPlatform = false
    }

    /// Whether a stage, a platform or a year is narrowing the list: when it comes up empty, that is why.
    var isNarrowed: Bool { filter.stage != nil || filter.platform != nil || scope != nil }

    /// The way out of an empty list: every video again.
    func showEverything() {
        clearScope()
        filter = TakeLibraryFilter()
    }

    /// Tapping the stage that is picked clears it.
    func toggle(_ stage: TakeStage) {
        filter.stage = filter.stage == stage ? nil : stage
    }

    /// A video "In edit" (and its Edit) opens on the take whose edit is open, not on the best one, where a new edit would start.
    func open(_ video: TakeVideo, then action: ReviewLaunchAction? = nil) {
        let inEdit = action == .edit || video.stage == .edit ? drafts.takeInEdit(among: video.takes) : nil
        guard let take = inEdit ?? video.best else { return }
        presentation.openReview(of: take, then: action)
    }

    func retake(_ video: TakeVideo) {
        presentation.openPrompter(scriptID: video.best?.scriptID, mode: .selfie)
    }

    func markBest(_ video: TakeVideo) {
        guard let best = video.best, !best.isBest else { return }
        takes.setBest(best.id, isBest: true)
        toast.show(String(localized: "\(best.label) marked as best"))
    }

    func deleteConfirmed() {
        guard let video = videoToDelete else { return }
        videoToDelete = nil
        for take in video.takes { takes.delete(take.id) }
        toast.show(video.takes.count == 1
            ? String(localized: "Take deleted")
            : String(localized: "\(video.takes.count) takes deleted"))
    }
}
