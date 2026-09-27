//
//  TakeLibraryFilter.swift
//  Cue Studio
//

import Foundation

/// Builds the Takes library: takes grouped into videos, filtered by platform and view, in Today /
/// Yesterday / Earlier sections. Pure, so it is tested without files or the clock.
nonisolated struct TakeLibraryFilter: Hashable, Sendable {
    struct Section: Hashable, Identifiable, Sendable {
        let day: TakeDay
        let videos: [TakeVideo]

        var id: TakeDay { day }
    }

    /// Nil shows every platform.
    var platform: Platform?
    var view: TakeLibraryView = .all

    /// One video per script, and one per freestyle recording. `scriptPlatform` gives the script's
    /// current platform (it can change after recording); takes fall back to their own.
    static func videos(from takes: [Take], scriptPlatform: (UUID) -> Platform? = { _ in nil }) -> [TakeVideo] {
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
            return TakeVideo(takes: group, title: title, platform: platform)
        }
    }

    func apply(to videos: [TakeVideo]) -> [TakeVideo] {
        videos.filter { video in
            (platform == nil || video.platform == platform) && view.matches(video)
        }
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
