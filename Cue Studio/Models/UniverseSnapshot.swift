//
//  UniverseSnapshot.swift
//  Cue Studio
//

import Foundation

/// What one year of "Your universe" draws: the videos the creator shared in it, counted by platform (the planets they travelled to) and by topic
/// (the worlds they come from). Built from what is on this iPhone; nothing is sent anywhere.
nonisolated struct UniverseSnapshot: Equatable, Sendable {
    struct TopicCount: Equatable, Sendable {
        let topic: OnboardingTopic
        let count: Int
    }

    /// A video's still dot on the map: which topic gives it its colour, and which slot of the 40 it takes (the same spot every time).
    struct Dot: Equatable, Sendable {
        let videoID: UUID
        let topicIndex: Int
        let slot: Int
        let hasTake: Bool
    }

    /// The most dots drawn; the count above them is still the real one.
    static let dotLimit = 40

    let year: Int
    /// Videos shared in `year` (each counted once).
    let total: Int
    /// The day of the first share ever, whichever year it was.
    let firstShare: Date?
    /// Per platform, the most shared first.
    let platforms: [(platform: Platform, count: Int)]
    /// Per topic of the creator, in the order their colors are given.
    let topics: [TopicCount]
    let dots: [Dot]
    /// The video shared last in the year: it shows as the new star.
    let newest: UniverseVideo?

    /// `videos` is everything ever shared; the snapshot keeps the ones of `year`.
    init(videos: [UniverseVideo], year: Int, topics creatorTopics: [OnboardingTopic], calendar: Calendar = .current) {
        let shared = videos.filter { $0.isIn(year: year, calendar: calendar) }.sorted { $0.date < $1.date }
        self.year = year
        total = shared.count
        firstShare = videos.map(\.date).min()
        var byPlatform: [Platform: Int] = [:]
        for video in shared { for platform in video.platforms { byPlatform[platform, default: 0] += 1 } }
        platforms = byPlatform.map { (platform: $0.key, count: $0.value) }.sorted { ($0.count, $1.platform.rawValue) > ($1.count, $0.platform.rawValue) }
        topics = creatorTopics.map { topic in TopicCount(topic: topic, count: shared.filter { $0.topic == topic.id }.count) }
        var dots: [Dot] = []
        for (index, topic) in creatorTopics.enumerated() {
            for video in shared where video.topic == topic.id && dots.count < Self.dotLimit {
                dots.append(Dot(videoID: video.id, topicIndex: index, slot: dots.count, hasTake: video.hasTake))
            }
        }
        self.dots = dots
        newest = shared.last
    }

    static func == (lhs: UniverseSnapshot, rhs: UniverseSnapshot) -> Bool {
        lhs.year == rhs.year && lhs.total == rhs.total && lhs.firstShare == rhs.firstShare && lhs.topics == rhs.topics && lhs.dots == rhs.dots
            && lhs.newest?.id == rhs.newest?.id
            && lhs.platforms.map(\.platform) == rhs.platforms.map(\.platform) && lhs.platforms.map(\.count) == rhs.platforms.map(\.count)
    }

    func count(for platform: Platform) -> Int { platforms.first { $0.platform == platform }?.count ?? 0 }
}
