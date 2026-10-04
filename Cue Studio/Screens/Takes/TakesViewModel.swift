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
        filter.sections(of: allVideos, now: now())
    }

    var isEmpty: Bool { takes.takes.isEmpty }

    /// "12 TAKES / 05 VIDEOS" as two zero-padded counts, like the pipeline's.
    var summaryValues: [String] {
        let all = allVideos
        return [
            String(localized: "\(takes.takes.count.formatted(.number.precision(.integerLength(2...)))) takes"),
            String(localized: "\(all.count.formatted(.number.precision(.integerLength(2...)))) videos"),
        ]
    }

    /// Platform menu: All, then the primary platforms (Stories only once a take uses it).
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
