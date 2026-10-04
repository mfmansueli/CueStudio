//
//  UniverseSnapshot.swift
//  Cue Studio
//

import Foundation

/// What "Your universe" draws: the videos the creator shared, counted by platform (the galaxies they travelled to)
/// and by topic (the worlds they come from). Built from what is on this iPhone; nothing is sent anywhere.
nonisolated struct UniverseSnapshot: Equatable, Sendable {
    struct TopicCount: Equatable, Sendable {
        let topic: OnboardingTopic
        let count: Int
    }

    /// Videos shared (each counted once).
    let total: Int
    let firstShare: Date?
    /// Per platform, the most shared first.
    let platforms: [(platform: Platform, count: Int)]
    /// Per topic of the creator, in the order their colors are given.
    let topics: [TopicCount]
    /// The video shared last: it shows as the new star.
    let newest: Take?
    /// How many were shared in `year` (for the year in review).
    let sharedThisYear: Int

    init(
        sharedIDs: Set<UUID>, takes: [Take], scripts: [Script], topics creatorTopics: [OnboardingTopic],
        firstShare: Date?, now: Date = .now, calendar: Calendar = .current
    ) {
        let shared = takes.filter { sharedIDs.contains($0.id) }
        total = sharedIDs.count
        self.firstShare = firstShare
        var byPlatform: [Platform: Int] = [:]
        for take in shared { if let platform = take.platform { byPlatform[platform, default: 0] += 1 } }
        platforms = byPlatform.map { (platform: $0.key, count: $0.value) }.sorted { ($0.count, $1.platform.rawValue) > ($1.count, $0.platform.rawValue) }
        let scriptByID = Dictionary(uniqueKeysWithValues: scripts.map { ($0.id, $0) })
        topics = creatorTopics.map { topic in
            TopicCount(topic: topic, count: shared.filter { scriptByID[$0.scriptID ?? UUID()]?.topic == topic.id }.count)
        }
        newest = shared.max { $0.recordedAt < $1.recordedAt }
        sharedThisYear = shared.filter { calendar.isDate($0.recordedAt, equalTo: now, toGranularity: .year) }.count
    }

    static func == (lhs: UniverseSnapshot, rhs: UniverseSnapshot) -> Bool {
        lhs.total == rhs.total && lhs.firstShare == rhs.firstShare && lhs.topics == rhs.topics && lhs.newest?.id == rhs.newest?.id
            && lhs.platforms.map(\.platform) == rhs.platforms.map(\.platform) && lhs.platforms.map(\.count) == rhs.platforms.map(\.count)
            && lhs.sharedThisYear == rhs.sharedThisYear
    }

    func count(for platform: Platform) -> Int { platforms.first { $0.platform == platform }?.count ?? 0 }
}
