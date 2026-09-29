//
//  TakesViewModel.swift
//  Cue Studio
//

import Foundation

/// The Takes library: videos (takes grouped by script) filtered by platform and view, by day.
@MainActor
@Observable
final class TakesViewModel {
    var filter = TakeLibraryFilter()
    /// Video whose takes are about to be deleted, for the confirmation.
    var videoToDelete: TakeVideo?

    private let takes: TakeLibraryService
    private let library: ScriptLibraryService
    private let toast: ToastService
    private let now: () -> Date

    init(takes: TakeLibraryService, library: ScriptLibraryService, toast: ToastService, now: @escaping () -> Date = Date.init) {
        self.takes = takes
        self.library = library
        self.toast = toast
        self.now = now
    }

    // MARK: - Reading

    var videos: [TakeVideo] {
        TakeLibraryFilter.videos(from: takes.takes) { [library] in library.script(id: $0)?.platform }
    }

    var sections: [TakeLibraryFilter.Section] {
        filter.sections(of: videos, now: now())
    }

    var isEmpty: Bool { takes.takes.isEmpty }

    /// "11 takes · 5 videos"
    var summary: String {
        guard !isEmpty else { return "" }
        return String(localized: "\(takes.takes.count) takes · \(videos.count) videos")
    }

    /// Platform chips: All, then the primary platforms (Stories only once a take uses it).
    var platformOptions: [Platform?] {
        let used = Set(videos.compactMap(\.platform))
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

    func deleteConfirmed() {
        guard let video = videoToDelete else { return }
        videoToDelete = nil
        for take in video.takes { takes.delete(take.id) }
        toast.show(video.takes.count == 1
            ? String(localized: "Take deleted")
            : String(localized: "\(video.takes.count) takes deleted"))
    }
}
