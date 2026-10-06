//
//  TakesRequest.swift
//  Cue Studio
//

import Foundation

/// A way of opening Takes that another screen asks for (9.2 "See in Takes ›", a theme in the legend): the videos shared, of a platform or a theme, in
/// a year. Takes shows it as a filter with a chip "{YEAR} · SHARED ✕" and drops it once the creator clears the chip.
nonisolated struct TakesRequest: Equatable, Sendable {
    var platform: Platform?
    /// A topic id (`OnboardingTopic.id`).
    var topic: String?
    var year: Int

    /// The shared videos that fit this request: the year, and the platform and the topic when they were asked for.
    func matching(_ videos: [UniverseVideo], calendar: Calendar = .current) -> Set<UUID> {
        Set(videos.filter { video in
            video.isIn(year: year, calendar: calendar) && (platform == nil || video.platforms.contains(platform!)) && (topic == nil || video.topic == topic)
        }.map(\.id))
    }
}
