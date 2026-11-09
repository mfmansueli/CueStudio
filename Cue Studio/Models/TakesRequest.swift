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
    /// "×3 ›" on a script: every take of it, shared or not (`TakesViewModel.apply`). Platform, topic and year don't apply then.
    var script: ScriptScope?

    /// One script's takes and its title, for the chip.
    nonisolated struct ScriptScope: Equatable, Sendable {
        var id: UUID
        var title: String
    }

    init(platform: Platform?, topic: String?, year: Int) {
        self.platform = platform
        self.topic = topic
        self.year = year
    }

    /// The takes of one script.
    init(script id: UUID, title: String, year: Int = Calendar.current.component(.year, from: .now)) {
        self.init(platform: nil, topic: nil, year: year)
        script = ScriptScope(id: id, title: title)
    }

    /// The shared videos that fit this request: the year, and the platform and the topic when they were asked for.
    func matching(_ videos: [UniverseVideo], calendar: Calendar = .current) -> Set<UUID> {
        Set(videos.filter { video in
            video.isIn(year: year, calendar: calendar) && (platform == nil || video.platforms.contains(platform!)) && (topic == nil || video.topic == topic)
        }.map(\.id))
    }
}
