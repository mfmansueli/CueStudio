//
//  TakeLibraryFilter.swift
//  Cue Studio
//

import Foundation

/// Builds the Takes library: takes grouped into videos (`TakeVideoKey`, each with its stage), filtered by the network they were recorded for
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

    /// One video per script and network (`TakeVideoKey`), and one per freestyle recording, filed under the network its takes were recorded
    /// for. `hasDraft` says whether an edit is open on a take (it decides "In edit").
    static func videos(from takes: [Take], hasDraft: (UUID) -> Bool = { _ in false }) -> [TakeVideo] {
        var order: [TakeVideoKey] = []
        var grouped: [TakeVideoKey: [Take]] = [:]
        for take in takes.sorted(by: { $0.recordedAt > $1.recordedAt }) {
            let key = take.videoKey
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(take)
        }
        return order.compactMap { key in
            guard let group = grouped[key]?.sorted(by: { $0.number > $1.number }), let first = group.first else { return nil }
            let title = first.isImported ? String(localized: "Imported video")
                : first.isFreestyle ? String(localized: "Freestyle recording") : first.scriptTitle
            return TakeVideo(takes: group, title: title, platform: first.platform, stage: TakeStage(takes: group, hasDraft: hasDraft))
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
