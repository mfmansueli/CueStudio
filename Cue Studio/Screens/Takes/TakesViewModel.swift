//
//  TakesViewModel.swift
//  Cue Studio
//

import Foundation

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

    init(
        takes: TakeLibraryService, library: ScriptLibraryService, drafts: QuickEditDraftStoring,
        presentation: PresentationService, toast: ToastService, now: @escaping () -> Date = Date.init
    ) {
        self.takes = takes
        self.library = library
        self.drafts = drafts
        self.presentation = presentation
        self.toast = toast
        self.now = now
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

    /// "12 TAKES · 5 VIDEOS" (the separator is the view's).
    var summaryValues: [String] {
        [String(localized: "\(takes.takes.count.formatted()) takes"), String(localized: "\(allVideos.count.formatted()) videos")]
    }

    /// The platform chips: All, then the primary platforms (Stories only once a take uses it).
    var platformOptions: [Platform?] {
        let used = Set(allVideos.compactMap(\.platform))
        return [nil] + Platform.allCases.filter { Platform.primary.contains($0) || used.contains($0) }
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

    // MARK: - Actions

    func refresh() {
        editRevision += 1
    }

    /// A request from "Your universe": the chip goes first, the platform it names is picked, and the stage filter is cleared.
    func apply(_ request: TakesRequest, sharedVideos: [UniverseVideo]) {
        scope = request
        scopeTakeIDs = request.matching(sharedVideos)
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

    func open(_ video: TakeVideo, then action: ReviewLaunchAction? = nil) {
        guard let best = video.best else { return }
        presentation.openReview(of: best, then: action)
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
