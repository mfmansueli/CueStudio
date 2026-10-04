//
//  TakeLibraryFilter.swift
//  Cue Studio
//

import Foundation

/// Builds the Takes library: takes grouped into videos (each with its stage), filtered by platform
/// and by the stage picked in the pipeline, in Today / Yesterday / Earlier sections. Pure, so it is
/// tested without files or the clock.
nonisolated struct TakeLibraryFilter: Hashable, Sendable {
    struct Section: Hashable, Identifiable, Sendable {
        let day: TakeDay
        let videos: [TakeVideo]

        var id: TakeDay { day }
    }

    /// Nil shows every platform.
    var platform: Platform?
    /// Nil shows every stage; tapping a stage in the pipeline filters to it, and again clears it.
    var stage: TakeStage?

    /// One video per script, and one per freestyle recording. `scriptPlatform` gives the script's
    /// current platform (it can change after recording); takes fall back to their own. `hasDraft`
    /// says whether an edit is open on a take (it decides "In edit").
    static func videos(
        from takes: [Take],
        scriptPlatform: (UUID) -> Platform? = { _ in nil },
        hasDraft: (UUID) -> Bool = { _ in false }
    ) -> [TakeVideo] {
        var order: [String] = []
        var grouped: [String: [Take]] = [:]
        for take in takes.sorted(by: { $0.recordedAt > $1.recordedAt }) {
            let key = take.scriptID?.uuidString ?? take.id.uuidString
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(take)
        }
        return order.compactMap { key in
            guard let group = grouped[key]?.sorted(by: { $0.number > $1.number }), let first = group.first else { return nil }
            let title = first.isFreestyle ? String(localized: "Freestyle recording") : first.scriptTitle
            let platform = first.scriptID.flatMap(scriptPlatform) ?? first.platform
            return TakeVideo(takes: group, title: title, platform: platform, stage: TakeStage(takes: group, hasDraft: hasDraft))
        }
    }

    /// The platform filter alone: what the pipeline counts, so its numbers don't change when a
    /// stage is picked.
    func onPlatform(_ videos: [TakeVideo]) -> [TakeVideo] {
        videos.filter { platform == nil || $0.platform == platform }
    }

    func apply(to videos: [TakeVideo]) -> [TakeVideo] {
        onPlatform(videos).filter { stage == nil || $0.stage == stage }
    }

    func sections(of videos: [TakeVideo], now: Date, calendar: Calendar = .current) -> [Section] {
        let filtered = apply(to: videos)
        return TakeDay.allCases.compactMap { day in
            let inDay = filtered.filter { video in
                guard let latest = video.latest else { return false }
                return TakeDay(date: latest.recordedAt, now: now, calendar: calendar) == day
            }
            return inDay.isEmpty ? nil : Section(day: day, videos: inDay)
        }
    }
}
