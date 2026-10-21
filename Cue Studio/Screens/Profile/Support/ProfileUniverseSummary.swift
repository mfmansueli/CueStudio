//
//  ProfileUniverseSummary.swift
//  Cue Studio
//

import Foundation

/// The "Your universe" card of the Profile (9.1; owner's redesign, 21/10/2026, kept short): its title, its line ("2026 · 1 video") and the
/// planets its mini universe draws (the networks shared to this year, most first), in its three states: a universe with videos, a new
/// account ("Your universe is waiting") and a new year, whose universe starts with its first share. Pure, so tested.
nonisolated struct ProfileUniverseSummary: Equatable, Sendable {
    /// Videos shared, ever, and in the year that is live; and how many the latest earlier year has.
    let total: Int
    let sharedThisYear: Int
    let year: Int
    let lastYear: Int
    let lastYearCount: Int
    /// The networks this year's videos went to, the most shared first: one planet each.
    var networks: [Platform] = []

    /// The year has begun and nothing has been shared in it yet, though earlier years have videos.
    var isNewYear: Bool { total > 0 && sharedThisYear == 0 }
    var isNewAccount: Bool { total == 0 }

    var title: String {
        isNewAccount ? String(localized: "Your universe is waiting") : String(localized: "Your universe")
    }

    /// The card's line.
    var detail: String {
        if isNewAccount { return String(localized: "Share your first video and its planet appears here.") }
        if isNewYear { return String(localized: "Your \(String(year)) universe starts with your first share.") }
        return String(year) + " · " + Self.videos(sharedThisYear)
    }

    /// "1 video", "23 videos" (plural forms in the String Catalog).
    static func videos(_ count: Int) -> String { String(localized: "\(count) videos") }

    /// The networks of `videos` in the year, the most shared first (a video sent to two counts for both).
    static func networks(of platforms: [[Platform]]) -> [Platform] {
        var counts: [Platform: Int] = [:]
        for list in platforms {
            for platform in list { counts[platform, default: 0] += 1 }
        }
        return counts.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.map(\.key)
    }
}
